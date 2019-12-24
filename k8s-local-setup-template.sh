#!/bin/sh

# This script is a template for your local specific setup.
# It should be copied to k8s-local-setup.sh
# and coded to do the following:
#
# It should set the variables, for example:
# the locations for kube/config file, nodeJoinFile, etc.
#
# It should also configure the network, figure out
# the hosts that will participate in the cluster
# (if the hosts were not supplied to k8s-node-setup.sh
# on the command line).  It may also need to
# setup a system service to clean up nodeJoinFile after
# the k8s cluster is formed.
#
# In summary, k8s-local-setup.sh is invoked by k8s-node-setup.sh to
# configure the k8s cluster fit for the local
# computing environment.

# If you do not need local setup:
echo "no-op in k8s-local-setup.sh"
exit

# Some considerations with regard to local environment:
localSetup() {
  # If your hosts run behind a firewall and use proxy to reach the open
  # internet, you should consider using other means, such as NAT here.

  # There will be ips in your k8s cluster that are
  # too numerous to be added into your no_proxy environment variable.
  # So after network configuraton above, remove the proxy
  # environment variables.
  unset http_proxy
  unset https_proxy
  unset no_proxy

  # Remove proxy settings for linux apt
  mv /etc/apt/apt.conf /etc/apt/apt.conf.not_necessary_with_NAT

  # Directories and file names if a shared file system is used among nodes.
  # Assume the top directory shared is $k8sShare
  KUBECONFIG_DIR=$k8sShare/k8s
  KUBECONFIG_FILE=$KUBECONFIG_DIR/config
  k8sTmpDir=$k8sShare/tmp
  nodeJoinFile=$k8sTmpDir/nodeJoinFile
  logFile=$k8sShare/logs/$host.k8s.setup.log

  # In your environment, the k8s-node-setup.sh may be fired on
  # each node parallelly. In such case, your environment should
  # provide a way to figure out the machines that will be in the
  # k8s cluster.  Then find the nodes and assign the array of machines
  # to the "nodes" variable.
  nodes=???

  # You may also figure out if the current machine is the master node,
  # the first machine in the nodes array.
  onMaster=???

  # If running on worker node, wipe out the nodes array and be done.
  if [ $onMaster -eq 1 ]; then
    nodes=()
    return
  fi

  # The following code is executed on the MASTER node ONLY.

  # You may want the "wall" message to inform the user that the k8s
  # setup is done on the master node.
  wallCommand="wall NOTE: KUBERNETES MASTER NODE IS READY"

  # Depending on local network, you might want to give non-default
  # routing masks to k8s.  The following is just examples.
  pod_network_cidr='--pod-network-cidr=192.168.10.0/24'
  service_cidr='--service-cidr=192.168.11.0/24'

  # ingress-nginx controller doesn't work on hardware that does not
  # support crypto instructions.  In such case do not use ingress controller.
  useIngressController=0

  # Create a service to clean up nodeJoinFile at shutdown
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

  # start the cleanup service on master
  sudo systemctl start k8s-cleanup
}

# execute the above function
localSetup
