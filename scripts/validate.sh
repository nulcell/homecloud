#!/usr/bin/env bash
# Render each gitops dir and schema-check the output. No args = every live dir.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

dirs=("$@")
[ ${#dirs[@]} -eq 0 ] && dirs=(gitops/{infrastructure,operators,security,services,apps}/*/)

rc=0
for d in "${dirs[@]}"; do
  d=${d%/}
  echo "==> $d"
  kustomize build --enable-helm "$d" | kubeconform -strict -ignore-missing-schemas -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' || rc=1
  git clean -fdXq -- "$d/charts" # pulled charts only; tracked local charts stay
done
exit $rc
