# Proxmox Home Lab

This is a terraform module that creates a Kubernetes cluster on Proxmox. It is intended to be used for a home lab environment. It is not intended to be used in production.

## (example) variables.auto.tfvars
```
proxmox = {
  host = "192.168.0.10",
  username = "root@pam",
  password = "****"
}

network = {
  cidr = "192.168.0.0/24"
  gateway = "192.168.0.1"
  dns_servers = ["192.168.0.1"]
  domain = "lan"

  control_plane_vip = 100
  control_first_ip = 101
  worker_first_ip = 103
}

kubernetes = {
  version = "1.27.8"
  cluster_name = "lab"
  cluster_domain = "cluster.local"
  cluster_cidr = "192.168.192.0/22"

  max_nodes = 4
  controls = 1
  workers = 0

  node_cpus = 4
  node_ram = 4096
  node_disk = 32
}
```