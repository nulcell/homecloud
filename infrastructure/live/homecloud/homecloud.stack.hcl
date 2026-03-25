# homecloud.stack.hcl — Explicit Terragrunt stack definition
# Declares the full homecloud stack: all units and their dependency graph.
# Run with: terragrunt stack run apply --working-dir infrastructure/live/homecloud

stack {
  # ── 1. CloudStack Platform ──────────────────────────────────────────────
  # Creates: domain, account, zone config, global settings, offerings,
  #          templates, VPC, networks, keypair, user-data scripts.
  unit "cloudstack-platform" {
    source = "./cloudstack-platform"
  }

  # ── 2. Tailscale VPN ────────────────────────────────────────────────────
  # Creates: Tailscale auth keys, ACL rules, DNS config.
  # Depends on cloudstack-platform for the tailnet subnet CIDR.
  unit "tailscale-vpn" {
    source = "./tailscale-vpn"
    depends_on = [unit.cloudstack-platform]
  }

  # ── 3. Ops Cluster (Talos + Cilium + ArgoCD) ────────────────────────────
  # Creates: Talos VMs in CloudStack, Talos config, cluster bootstrap,
  #          Cilium CNI, ArgoCD, core monitoring stack.
  unit "ops-cluster" {
    source = "./ops-cluster"
    depends_on = [unit.cloudstack-platform, unit.tailscale-vpn]
  }

  # ── 4. Workload Cluster (Talos + Cilium + CCM + CSI) ────────────────────
  # Creates: Talos VMs, cluster bootstrap, Cilium CNI,
  #          CloudStack CCM, CloudStack CSI, external-dns (Cloudflare).
  unit "workload-cluster" {
    source = "./workload-cluster"
    depends_on = [unit.cloudstack-platform, unit.tailscale-vpn, unit.ops-cluster]
  }

  # ── 5. Note: Media Server ────────────────────────────────────────────────
  # The media server is a Helm chart deployed by ArgoCD from charts/media-server/.
  # SharedFileSystem NFS volumes (media-server-fs-config, media-server-fs-data)
  # are optional resources managed inside cloudstack-platform (enable_shared_storage).
  # No separate Terragrunt unit is needed for the media server itself.
}
