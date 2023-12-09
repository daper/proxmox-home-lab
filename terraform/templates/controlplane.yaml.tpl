machine:
  certSANs:
    - ${control_plane_vip}
    - ${hostname}
    - ${node_ip}

  kubelet:
    extraArgs:
      node-ip: ${node_ip}
      v: 5

    extraConfig:
      serverTLSBootstrap: true
      allowedUnsafeSysctls:
        - net.ipv6.conf.all.forwarding
        - net.ipv4.ip_forward
      maxPods: ${available_hosts_per_subnet}

    nodeIP:
      validSubnets:
          - ${node_ip}/32

  network:
    hostname: ${hostname}
    interfaces:
      - interface: eth0
        addresses:
          - ${node_ip}/${element(split("/", network_cidr), 1)}
        vip:
          ip: ${control_plane_vip}

    nameservers: ${jsonencode(network_dns_servers)}

  time:
    servers:
      - time.google.com

  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:reader
      allowedKubernetesNamespaces:
        - kube-system
        - default

    kubePrism:
      enabled: true
      port: 7445

cluster:
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: false
      service:
        disabled: true

  network:
    dnsDomain: ${kubernetes_cluster_domain}
    podSubnets: ${format("%#v",split(",",pod_cidr))}
    serviceSubnets: ${format("%#v",split(",",service_cidr))}
    cni:
      name: custom

  proxy:
    disabled: true

  externalCloudProvider:
    enabled: true

  allowSchedulingOnControlPlanes: true

  etcd:
    advertisedSubnets:
      - ${network_cidr}

  controllerManager:
    extraArgs:
      node-cidr-mask-size-ipv4: ${new_subnet_bits}

  extraManifests: []

  inlineManifests:
    - name: cilium
      contents: |-
        apiVersion: v1
        kind: Namespace
        metadata:
            name: cilium
            labels:
              pod-security.kubernetes.io/enforce: "privileged"
    - name: csr-approver
      contents: |-
        ${indent(8, manifests_csr_approver)}
    - name: proxmox-ccm
      contents: |-
        ${indent(8, manifests_promox_ccm)}
    - name: cilium-deploy
      contents: |-
        ${indent(8, manifests_cilium)}
