#!/bin/bash

# Demonstrate how to create two applications and expose them
# as load balancer services.
#
# Note: To allow these two services to SHARE the same external-ip,
# the developer MUST provide the SAME allow-shared-ip key for each
# service (read more on metallb).  Otherwise, only one application is
# exposed for each available external ip address known to metallb.
#
# The script should be run in the user's shell.
# Go to the end of this file to See how to verify the exposed services.

DEBUG=1  # show command output if not 0
want_cmd_output=0  # caller should set to non-zero if cmd output is wanted
cmd_fail_ok=0  # do not exit when cmd fails
cmd_output=warning_uninitialized
cmd_rc=-1
exec_cmd() {
  if (($DEBUG)); then
    echo "### $@"
  fi

  cmd_output=warning_uninitialized

  if (($want_cmd_output)); then
    cmd_output=$(eval $@)
    echo "$cmd_output"
  elif (($DEBUG)); then
    eval $@
  else
    eval $@ > /dev/null
  fi

  cmd_rc=$?
  if [[ $cmd_rc -ne 0 && $cmd_fail_ok -eq 0 ]]; then
    echo "### cmd failed. exit"
    exit -1
  fi

  want_cmd_output=0
  cmd_fail_ok=0
}

tmpFileDir=/tmp/k8s
exec_cmd rm -rf $tmpFileDir
exec_cmd mkdir $tmpFileDir

metallbConfig=$tmpFileDir/metallbConfig.yaml
helloDeploy=$tmpFileDir/hello.yaml
nginxLB=$tmpFileDir/nginxLB.yaml
helloLB=$tmpFileDir/helloLB.yaml

# deploy nginx using a canned k8s spec
# NOTE: assuming that this deployment defines a label "app: ngnix"
exec_cmd kubectl create deployment nginx --image=nginx

# expose the deployed nginx as a LB (load balancer) service
#
# NOTE: All load balancer services in this script use the same
# metallb.universe.tf/allow-shared-ip key.  It allows them to
# share the same external ip (with different ports) as their entry.
cat > $nginxLB <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    metallb.universe.tf/allow-shared-ip: "happily-sharing-h0-ip"
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF
exec_cmd kubectl apply -f $nginxLB

# deploy the second application
cat > $helloDeploy <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: load-balancer-example
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: load-balancer-example
  template:
    metadata:
      labels:
        app: hello
        app.kubernetes.io/name: load-balancer-example
    spec:
      containers:
      - image: gcr.io/google-samples/node-hello:1.0
        name: hello-world
        ports:
        - containerPort: 8080
EOF
exec_cmd kubectl apply -f $helloDeploy

# expose the second deployment as a LB service
cat > $helloLB <<EOF
apiVersion: v1
kind: Service
metadata:
  name: hello
  annotations:
    metallb.universe.tf/allow-shared-ip: "happily-sharing-h0-ip"
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: hello
  type: LoadBalancer
EOF
exec_cmd kubectl apply -f $helloLB

exit

# verificaton:
# "kubectl get svc" should produce something like
#
# NAME         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)
# hello        LoadBalancer   192.168.11.108   10.92.1.6     8080:32692/TCP
# kubernetes   ClusterIP      192.168.11.1     <none>        443/TCP
# nginx        LoadBalancer   192.168.11.44    10.92.1.6     80:30655/TCP
#
# On another host where 10.92.1.6 is reachable
# curl 10.92.1.6:8080
# should produce output "Hello Kubernetes!"
# while
# curl 10.92.1.6
# should produce the default nginx home page html
