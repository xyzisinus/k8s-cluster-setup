#!/bin/bash

# This script is invoked by the setup.sh script to set up k8s on
# an individual node, either the master node or a worker nodes.
# If used manually:
#
# On the master: "sudo nodeSetup.sh" or from another host do
# ssh sshUser@master 'sudo bash -s' < nodeSetup.sh
# Upon completion, the script will generate a file "node_signin"
# in its working directory on the master node.  At the end of
# the file, the "kubeadm join" command will be used by the
# worker nodes to join the cluster.
#
# On a worker: "sudo nodeSetup.sh 'kubeadm join ...'" or
# ssh sshUser@workder 'sudo bash -s' < nodeSetup.sh 'kubeadm join ...'

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
    cmd_output=$($@)
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

if [ $# -eq 0 ]; then
  onMaster=1
else
  joinCmd=$@
fi

############## install docker

exec_cmd apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common

exec_cmd curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

dep_path="deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs)  stable"
exec_cmd add-apt-repository ${dep_path@Q}

exec_cmd apt-get update && apt-get install -y docker-ce=18.06.2~ce~3-0~ubuntu

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"

}
EOF

exec_cmd mkdir -p /etc/systemd/system/docker.service.d

exec_cmd systemctl daemon-reload
exec_cmd systemctl restart docker

############## install k8s

exec_cmd "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add"

dep_path="deb http://apt.kubernetes.io/ kubernetes-xenial main"
exec_cmd add-apt-repository ${dep_path@Q}

exec_cmd apt install -y kubeadm

exec_cmd swapoff -a

if [ $onMaster ]; then
  # on master
  want_cmd_output=1
  exec_cmd kubeadm init --pod-network-cidr=10.244.0.0/16
  echo "$cmd_output" > node_signin

  sudo_user_uid=$(id $SUDO_USER -u)
  sudo_user_gid=$(id $SUDO_USER -g)
  exec_cmd mkdir -p $HOME/.kube
  exec_cmd cp /etc/kubernetes/admin.conf $HOME/.kube/config
  exec_cmd chown -R ${sudo_user_uid}:${sudo_user_gid} $HOME/.kube

  k8s_app="https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  exec_cmd kubectl apply -f $k8s_app

else
  # on worker
  eval $joinCmd
fi

exit
