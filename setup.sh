#!/bin/bash

# how to use:
# sudo bash
# bash setup.sh
# if you do exec_cmd cmd > file, do exec_cmd "cmd > file" to avoid exec_cmd()
# dumping stuff into your file

#  scp czang@everest.pdl.cmu.edu:/h/czang/k8s/setup.sh .
# ssh ubuntu@192.168.1.1 'sudo bash -s' < setup.sh

# sudo ssh -i deployment/config/746-autograde.pem ubuntu@18.218.12.108 'sudo bash -s' < ~/k8s/setup.sh

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
    masterNode=$node
    eval sudo $sshCmd ${node} "'sudo bash -s' < $setupScript"
    sudo $scpCmd ${sshUser}@${node}:node_signin /tmp
    joinCmd=$(tail -2 /tmp/node_signin)
  else
    # --v=2 gives critical info which should be present without the flag
    eval sudo $sshCmd ${node} "'sudo bash -s' < $setupScript" \"$joinCmd --v=2\"
  fi
done

exit
