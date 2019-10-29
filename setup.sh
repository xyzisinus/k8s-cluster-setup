#!/bin/bash

# invoke nodeSetup.sh to create a k8s cluster.
# how to use: ./setup.sh sshKey sshUser "node1 node2 ...".  node1 is master

if [ "$#" -ne 3 ]; then
  echo "need 3 args: ssh key, ssh user and quoted list of nodes"
  exit -1
fi

sshKey=$1
sshUser=$2

sshCmd="ssh -o StrictHostKeyChecking=no -i $sshKey -l $sshUser"
scpCmd="scp -o StrictHostKeyChecking=no -i $sshKey"
setupScript="/h/czang/k8s/nodeSetup.sh"

read -ra nodes <<< "$3"
for i in "${!nodes[@]}"; do
  node="${nodes[$i]}"
  if [ $i -eq 0 ]; then
    # master node. nodeSetup.sh will dump the output of kubeadm init
    # into a file node_signin whose last two lines is the "kubadm join" cmd.
    eval sudo $sshCmd ${node} "'sudo bash -s' < $setupScript"
    sudo $scpCmd ${sshUser}@${node}:node_signin /tmp
    joinCmd=$(tail -2 /tmp/node_signin)
  else
    # --v=2 gives critical info which should be present without the flag
    eval sudo $sshCmd ${node} "'sudo bash -s' < $setupScript" \"$joinCmd --v=2\"
  fi
done

exit
