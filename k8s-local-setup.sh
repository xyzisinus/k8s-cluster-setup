#!/bin/sh

# This script is a space-holder.
# I's meant to be invoked by k8s-node-setup.sh to
# configure the k8s cluster fit for the local
# computing environment.
# It should set the variables, for example:
# the locations for kube/config file, nodeJoinFile, etc.
# It should also configure the network, figure out
# the hosts that will participate in the cluster
# (if the hosts were not supplied to k8s-node-setup.sh
# on the command line).  It may also need to
# setup a system service to clean up nodeJoinFile after
# the k8s cluster is formed.

echo "no-op in k8s-local-setup.sh"
