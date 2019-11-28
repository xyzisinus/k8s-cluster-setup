#!/bin/bash

# Demonstrate how to create two applications and expose them
# as ingress for external access.
#
# The script should be run in the user's shell.
# Go to the end of this file to See how to verify the exposed services.
#
# Credits: examples are from
# https://matthewpalmer.net/kubernetes-app-developer/articles/kubernetes-ingress-guide-nginx-example.html

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

appleService=$tmpFileDir/apple.yaml
bananaService=$tmpFileDir/banana.yaml
exampleIngress=$tmpFileDir/ingress.yaml

cat > $appleService <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: apple-app
  labels:
    app: apple
spec:
  containers:
    - name: apple-app
      image: hashicorp/http-echo
      args:
        - "-text=apple"
---
kind: Service
apiVersion: v1
metadata:
  name: apple-service
spec:
  selector:
    app: apple
  ports:
    - port: 5678 # Default port for image

EOF
exec_cmd kubectl apply -f $appleService

cat > $bananaService <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: banana-app
  labels:
    app: banana
spec:
  containers:
    - name: banana-app
      image: hashicorp/http-echo
      args:
        - "-text=banana"
---
kind: Service
apiVersion: v1
metadata:
  name: banana-service
spec:
  selector:
    app: banana
  ports:
    - port: 5678 # Default port for image
EOF
exec_cmd kubectl apply -f $bananaService

cat > $exampleIngress <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
        - path: /apple
          backend:
            serviceName: apple-service
            servicePort: 5678
        - path: /banana
          backend:
            serviceName: banana-service
            servicePort: 5678
EOF
exec_cmd kubectl apply -f $exampleIngress

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
