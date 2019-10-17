#!/bin/bash

# should be running in user's shell

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
# } &>> /var/log/k8s/setup.log
# replace the line above with a single "}" to observe command's output
}

exec_cmd rm -rf ~/.k8s
exec_cmd mkdir  ~/.k8s
fullPath=$(echo ~/.k8s)

metallbConfig=$fullPath/metallbConfig.yaml
helloDeploy=$fullPath/hello.yaml
nginxLB=$fullPath/nginxLB.yaml
helloLB=$fullPath/helloLB.yaml
randomKey=$(openssl rand -base64 14)


# deploy load balancer
exec_cmd kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml

# config file, incomplete
cat > $metallbConfig <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
EOF

# add host ips in the cluster as public ips
. /etc/emulab/paths.sh
while IFS= read -r line; do
  read type nickname hostname rest <<< "$line";
  if [ $type == H ]; then
    ip=$(getent hosts $hostname | awk '{ print $1 }')
    echo "      - ${ip}/32" >> $metallbConfig
  fi
done < $BOOTDIR/ltpmap

# config load balancer with config file
exec_cmd kubectl apply -f $metallbConfig

# deploy nginx
# NOTE: assuming that this deployment defines a label "app: ngnix"
exec_cmd kubectl create deployment nginx --image=nginx

cat > $nginxLB <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    metallb.universe.tf/allow-shared-ip: "$randomKey"
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF

exec_cmd kubectl apply -f $nginxLB

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

cat > $helloLB <<EOF
apiVersion: v1
kind: Service
metadata:
  name: hello
  annotations:
    metallb.universe.tf/allow-shared-ip: "$randomKey"
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
