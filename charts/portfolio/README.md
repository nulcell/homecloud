# portfolio

nulcell.com — personal portfolio site (static Astro build served by nginx)

## Network policy

`networkPolicy` (enabled by default) locks the pod down to ingress from the
Gateway on the web port and denies all egress — a static site initiates
nothing. It renders a CiliumNetworkPolicy rather than a networking.k8s.io
NetworkPolicy because Cilium's Gateway API forwards traffic with the reserved
`ingress` identity, which a plain NetworkPolicy cannot select.
