data "helm_template" "cilium" {
  name       = "cilium"
  namespace  = "cilium"
  repository = "https://helm.cilium.io"

  chart   = "cilium"
  version = "1.14.1"

  include_crds = true

  values = [<<-EOF
    ipam:
      mode: kubernetes
    tunnel: disabled
    bpf:
      masquerade: true
    endpointRoutes:
      enabled: true
    kubeProxyReplacement: true
    autoDirectNodeRoutes: true
    localRedirectPolicy: true

    operator:
      replicas: 1
      rollOutPods: true
    rollOutCiliumPods: true

    routingMode: native
    ipv4NativeRoutingCIDR: "${var.kubernetes.cluster_cidr}"

    hubble:
      enabled: false

    cgroup:
      autoMount:
        enabled: true
      hostRoot: /sys/fs/cgroup

    k8sServiceHost: localhost
    k8sServicePort: "7445"

    debug:
      enabled: true
      # verbose: flow,kvstore,envoy,datapath,policy
  EOF
  ]

  set {
    name = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }

  set {
    name = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }
}

resource "null_resource" "proxmox-ccm" {
  provisioner "local-exec" {
    when = create
    command = <<-EOF
      git clone \
        --filter=tree:0 \
        --no-checkout \
        https://github.com/sergelogvinov/proxmox-cloud-controller-manager.git \
        proxmox-ccm
      cd proxmox-ccm
      git checkout HEAD charts
      rm -rf .git
    EOF
  }

  provisioner "local-exec" {
    when = destroy
    command = "rm -rf proxmox-ccm"
  }
}

data "helm_template" "proxmox-ccm" {
  name = "proxmox-ccm"
  namespace = "kube-system"

  chart = "${path.module}/proxmox-ccm/charts/proxmox-cloud-controller-manager"

  values = [<<-EOF
    fullnameOverride: proxmox-ccm

    nodeSelector:
      node-role.kubernetes.io/control-plane: ""

    extraArgs:
      - --use-service-account-credentials=false

    config:
      clusters:
        - url: "https://${var.proxmox.host}:8006/api2/json"
          insecure: true
          token_id: ${data.external.proxmox-ccm-token.result.full-tokenid}
          region: ${var.kubernetes.cluster_name}
  EOF
  ]

  set_sensitive {
    name = "config.clusters[0].token_secret"
    value = data.external.proxmox-ccm-token.result.value
  }

  depends_on = [null_resource.proxmox-ccm]
}

data "helm_template" "csr-approver" {
  name = "csr-approver"
  namespace = "kube-system"
  repository = "https://postfinance.github.io/kubelet-csr-approver"

  chart = "kubelet-csr-approver"
  version = "1.0.4"

  values = [<<-EOF
    providerRegex: '${var.kubernetes.cluster_name}-.'
    providerIpPrefixes:
      - ${var.kubernetes.cluster_cidr}
      - ${var.network.cidr}

    maxExpirationSeconds: 86400
    bypassDnsResolution: true

    replicas: 1
    tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Equal
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
        operator: Equal
      - key: node.cloudprovider.kubernetes.io/uninitialized
        operator: Equal
        value: "true"
        effect: NoSchedule
  EOF
  ]

  skip_tests = true
}