# Media Servarr Chart

This Helm chart deploys a media server stack including Jellyfin, Jellyseerr, Sonarr, Radarr, Bazarr, Prowlarr, and qbittorrent.

## Network policy

`networkPolicy` (enabled by default) renders one policy per app; Prowlarr and
qBittorrent share the servarr pod and are covered by its policy. Ingress:
anything in the namespace may reach any app (the *arr apps talk to each
other), the Gateway may reach each app's web port, plus optional cloudflared
and `allowedNamespaces` peers. Egress is per app under
`<app>.networkPolicy.egress`: servarr defaults to open (the gluetun
killswitch inside the pod is the enforcement point); every other app defaults
to DNS + in-namespace only, with `fqdns` (Cilium L7 DNS/`toFQDNs`) and
`extraRules` as the escape hatches for metadata and subtitle providers.
`flavor: cilium` (default) renders CiliumNetworkPolicies, which is required
with Cilium's Gateway API: forwarded traffic carries the reserved `ingress`
identity that plain NetworkPolicies cannot select. `flavor: kubernetes`
renders portable NetworkPolicies for clusters whose gateway runs as pods.
