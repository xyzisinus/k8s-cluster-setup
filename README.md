The file is under construction.  Please check back later!

## Working scripts to build k8s cluster on bare metal machines or VMs

Tested on a set of ASW VMs using open-to-all security
rules.  Also tested in bare metal machines in an internal network at Carnegie Mellon University.

### Scripts

####```k8s-setup.sh```
Top level script, executed with root privilege.  It takes the following
arguments
* ssh private key to the nodes in the cluster
* user name of ssh login
* a list of node names/ips that forms the k8s cluster with the first one being the master
node

For example: ```./k8s-setup.sh <path to key> <user> ip1 ip2 ...```

The script runs the following script on each node, to configure the master node and then
the worker nodes sequentially.

####```k8s-node-setup.sh```
 
####```k8s-local-setup-template.sh```

### Ingress controller

Example applications.

### Load balancer

Example applications.

### Acknowledgement

Much of the credits belong to the Kubernetes official documents and the online
community's resources.  It's impossible to list all the web pages consulted.  
But in case of verbatim code-borrowing the source is acknowledged in the comments
 of the script.

### Caveat

For fast development the security rules on the AWS VMs are set to `open to all`. 

