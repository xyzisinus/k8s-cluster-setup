#!/bin/bash

# invoke nodeSetup.sh to create a k8s cluster.
# how to use: ./setup.sh sshKey sshUser "node1 node2 ...".  node1 is master

if [[ $EUID -ne 0 ]]; then
  sudo $0 $@
  exit
fi

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

  # copy the scripts to node
  $scpCmd ./nodeSetup.sh ${sshUser}@${node}:/tmp
  $scpCmd ./localSetup.sh ${sshUser}@${node}:/tmp

  if [ $i -eq 0 ]; then
    # master node. nodeSetup.sh will dump the output of kubeadm init
    # into $nodeJoinFile (see nodeSetup.sh).  The file will be used by
    # the worker nodes to join the cluster.

    # setup master node, get nodeJoinFile location and scp it from master
    nodeJoinFileColon=$($sshCmd ${node} "/tmp/nodeSetup.sh \"$3\"" | grep "nodeJoinFile:") || exit 1
    read -r tag nodeJoinFile <<< "$nodeJoinFileColon"
    $scpCmd ${sshUser}@${node}:$nodeJoinFile /tmp || exit 1
  else
    nodeJoinFileDir=$(dirname $nodeJoinFile)
    $sshCmd ${node} "mkdir -p \"$nodeJoinFileDir\""
    $scpCmd /tmp/nodeJoinFile ${sshUser}@${node}:$nodeJoinFile || exit 1
    $sshCmd ${node} "/tmp/nodeSetup.sh" || exit 1
  fi
done

exit
