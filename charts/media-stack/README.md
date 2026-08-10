# Media Servarr Chart

This Helm chart deploys a media server stack including Jellyfin, Jellyseerr, Sonarr, Radarr, Bazarr, Prowlarr, and qbittorrent.

## Network policy

`networkPolicy` (enabled by default) renders one CiliumNetworkPolicy per app;
Prowlarr and qBittorrent share the servarr pod and are covered by its policy.
Ingress: anything in the namespace may reach any app (the *arr apps talk to
each other), the Gateway may reach each app's web port, plus optional
cloudflared and `allowedNamespaces` peers. Egress is per app under
`<app>.networkPolicy.egress` and is all-or-nothing — `allowAll`, which every
app in this stack sets (they reach arbitrary external metadata and subtitle
providers, and servarr's traffic is policed by the gluetun killswitch inside
its pod), or a full deny, with `extraRules` for anything in between.
CiliumNetworkPolicy rather than networking.k8s.io because Cilium's Gateway API
forwards traffic with the reserved `ingress` identity, which a plain
NetworkPolicy cannot select.
