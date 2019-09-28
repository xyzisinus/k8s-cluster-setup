#!/bin/bash

# invoke nodeSetup.sh to create a k8s cluster.
# how to use: ./setup.sh sshKey sshUser "node1 node2 ...".  node1 is master

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
