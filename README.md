## Working scripts to build k8s cluster on bare metal machines or VMs

This repository is a set of scripts that configure bare metal machines or VMs into a Kubernetes cluster.  The scripts have been tested on AWS VMs and on the bare metal machines in an internal network at Carnegie Mellon University.  They are meant to provide turn-key solution in a simple configuration, meanwhile serving as a code base for adaptation into real world deployment.

### The scripts

### Acknowledgement

Much of the credits belong to the Kubernetes official documents and online community's resources.  It's impossible to list all the webpages being consulted.  But for verbatim code borrowing the source is acknowledged in the comments of the script.

### Caveat

For fast development the security rules on the AWS VMs are set to `open to all`.  That must be tightened in a real deployment.
