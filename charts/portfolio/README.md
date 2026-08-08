# portfolio

nulcell.com — personal portfolio site (static Astro build served by nginx)

## Network policy

`networkPolicy` (enabled by default) locks the pod down to ingress from the
Gateway on the web port and denies all egress — a static site initiates
nothing. `flavor: cilium` (default) renders a CiliumNetworkPolicy, which is
required with Cilium's Gateway API: forwarded traffic carries the reserved
`ingress` identity that plain NetworkPolicies cannot select. `flavor:
kubernetes` renders a portable NetworkPolicy for clusters whose gateway runs
as pods.
