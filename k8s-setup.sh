#!/bin/bash

# invoke k8s-node-setup.sh to create a k8s cluster.
# ./k8s-setup.sh sshKey sshUser "node1 node2 ...".  node1 is master

if [[ $EUID -ne 0 ]]; then
  sudo $0 $@
  exit
fi

if [ "$#" -ne 3 ]; then
  echo "need 3 args: ssh key, ssh user and quoted list of nodes"
  exit -1
fi

# figure out the directory of this script so that sub scripts can be found.
# copied directly from stackoverflow (many thanks).
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  # if $SOURCE was a relative symlink,
  # we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

sshKey=$1
sshUser=$2
sshCmd="ssh -o StrictHostKeyChecking=no -i $sshKey -l $sshUser"
scpCmd="scp -o StrictHostKeyChecking=no -i $sshKey"

read -ra nodes <<< "$3"
for i in "${!nodes[@]}"; do
  node="${nodes[$i]}"

  # copy scripts to node
  $scpCmd $DIR/k8s-node-setup.sh ${sshUser}@${node}:/tmp
  $scpCmd $DIR/k8s-local-setup.sh ${sshUser}@${node}:/tmp

  if [ $i -eq 0 ]; then
    # master node. The output of kubeadm init will be dumped into
    # nodeJoinFile (see k8s-node-setup.sh).  The file will be copied
    # the worker nodes for it to join the cluster.

    # run node setup script, get nodeJoinFile's location from output
    nodeJoinFileColon=$($sshCmd ${node} "/tmp/k8s-node-setup.sh \"$3\"" | grep "nodeJoinFile:") || exit 1
    read -r tag nodeJoinFile <<< "$nodeJoinFileColon"
    $scpCmd ${sshUser}@${node}:$nodeJoinFile /tmp || exit 1
  else
    # worker node. copy nodeJoinFile to node and run node setup script

    nodeJoinFileDir=$(dirname $nodeJoinFile)
    $sshCmd ${node} "mkdir -p \"$nodeJoinFileDir\""
    $scpCmd /tmp/nodeJoinFile ${sshUser}@${node}:$nodeJoinFile || exit 1
    $sshCmd ${node} "/tmp/k8s-node-setup.sh" || exit 1
  fi
done

exit
