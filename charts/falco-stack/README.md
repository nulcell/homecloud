# falco-stack

Umbrella chart for the Falco runtime-security layer. Wraps the Falco Operator
CRs (`Falco`, `Component`, `Plugin`, `Rulesfile`, `Config`) plus the supporting
Redis + HTTPRoute + ServiceMonitors. The operator itself lives in
[`gitops/operators/falco/`](../../gitops/operators/falco/) and is a hard
prerequisite — without its CRDs this chart's templates won't apply.
