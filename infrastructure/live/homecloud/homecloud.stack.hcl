# homecloud.stack.hcl — Explicit Terragrunt stack definition
# Declares the full homecloud stack: all units and their dependency graph.
# Run with: terragrunt stack run apply --working-dir infrastructure/live/homecloud

stack {
  # ── 1. CloudStack Admin ──────────────────────────────────────────────────
  # Admin-scope only: global config, zone, domain, account, offerings (as maps),
  # templates/images (as maps, lifecycle prevent_destroy).
  unit "cloudstack-admin" {
    source = "./cloudstack-admin"
  }

  # ── 2. CloudStack Homecloud ──────────────────────────────────────────────
  # homecloud-admin scope: VPC, networks, iso-net-shared, SSH keypair,
  # userdata scripts, NFS shared filesystems.
  unit "cloudstack-homecloud" {
    source = "./cloudstack-homecloud"
    depends_on = [unit.cloudstack-admin]
  }

  # ── 3. Tailscale VPN ────────────────────────────────────────────────────
  # Creates: homecloud-vpn-router Ubuntu VM connected to all CloudStack networks.
  # Advertises 10.0.0.0/15 into tailnet for operator access.
  unit "tailscale-vpn" {
    source = "./tailscale-vpn"
    depends_on = [unit.cloudstack-homecloud]
  }

  # ── 4. Ops Cluster (Talos + Cilium + ArgoCD) ────────────────────────────
  # Talos VMs in iso-net-shared (10.1.1.0/24).
  # kube-apiserver: CloudStack public IP + LB rule (port 6443).
  # ArgoCD manages both ops and workload clusters.
  unit "ops-cluster" {
    source = "./ops-cluster"
    depends_on = [unit.cloudstack-homecloud, unit.tailscale-vpn]
  }

  # ── 5. Workload Cluster (Talos + Cilium + CCM + CSI + cert-manager) ──────
  # Talos VMs in pub-net-1 (VPC, 10.0.0.0/26).
  # kube-apiserver: CloudStack public IP + LB rule (port 6443).
  # Registered with ops-cluster ArgoCD as managed cluster.
  # cert-manager installed for TLS certificate management.
  unit "workload-cluster" {
    source = "./workload-cluster"
    depends_on = [unit.cloudstack-homecloud, unit.tailscale-vpn, unit.ops-cluster]
  }

  # ── Note: Media Server ───────────────────────────────────────────────────
  # ArgoCD Helm chart (charts/media-server/). No Terragrunt unit needed.
  # NFS volumes (media-server-fs-config, media-server-fs-data) are optional
  # resources inside cloudstack-homecloud (enable_shared_storage = true).
}
