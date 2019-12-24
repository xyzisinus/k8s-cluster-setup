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
# Suppose there are nodes with public ip N0, N1, N2, ... in the
# cluster where N0 is the master node.  Then the apple and banana
# apps should be accessible from any worker node, N1, N2, ....
#
# On a host where the worker nodes are reachable,
# "curl N1/apple"
# should produce output
# "apple"
# While "curl N1/banana"
# should produce output
# "banana"
#
# Try those commands on another worker node ip, say,
# curl N2/apple
# curl N2/banana
# They should produce the same output.
