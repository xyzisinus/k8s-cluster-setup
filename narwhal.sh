#!/bin/bash

startup() {
  # The ops randomly fail.
  # Wait for swap-in to complete
  sleep 5

  . /etc/profile

  ip route add default via 10.71.0.3 dev enp2s4 onlink
  ip route del default via 10.92.0.1 dev enp2s4
  unset http_proxy
  unset https_proxy
  unset no_proxy

  mv /etc/apt/apt.conf /etc/apt/apt.conf.not_necessary_with_NAT

  # hostname is like h0.<exp>.<proj>.<rest>
  # make directory and file names
  IFS=. read -r host exp proj rest <<< $(hostname)
  KUBECONFIG_DIR=/proj/$proj/exp/$exp/k8s
  KUBECONFIG_FILE=$KUBECONFIG_DIR/config
  nodeJoinFileDir=/proj/$proj/exp/$exp/tmp
  nodeJoinFile=$nodeJoinFileDir/nodeJoinFile
  k8sTmpDir=/proj/$proj/exp/$exp/tmp
  logFile=/proj/$proj/exp/$exp/logs/$host.k8s.setup.log

  # create a service to clean up the join file generated by master
  cat > /etc/systemd/system/k8s-cleanup.service <<EOF
[Unit]
Description=Delete-${nodeJoinFile}-at-shutdown
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/bin/rm -f $nodeJoinFile

[Install]
WantedBy=shutdown.target
EOF

  # find the nodes if executing on master
  if [ $(hostname -s) != "h0" ]; then
    return
  fi

  # find all nodes
  onMaster=1
  nodes=()

  . /etc/emulab/paths.sh
    while IFS= read -r line; do
    read type nickname hostname rest <<< "$line";
    if [ $type == H ]; then
      nodes+=($(getent hosts $hostname | awk '{ print $1 }'))
    fi
  done < $BOOTDIR/ltpmap

  # start the cleanup service on master
  sudo systemctl start k8s-cleanup
}

startup
