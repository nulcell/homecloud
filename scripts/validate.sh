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
  manifests=$(kustomize build --enable-helm "$d") || { rc=1; continue; }
  kubeconform -strict -ignore-missing-schemas -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' <<<"$manifests" || rc=1
  # Every container image names its registry (first path segment has a dot or colon, or is localhost).
  bad=$(yq -o=json '.' <<<"$manifests" | jq -r '.. | objects | (.containers?, .initContainers?) | arrays | .[] | .image? | strings
    | select(test("^([^/]*[.:][^/]*|localhost)/") | not)' | sort -u)
  [ -z "$bad" ] || { echo "images without a registry:"; sed 's/^/  /' <<<"$bad"; rc=1; }
  git clean -fdXq -- "$d/charts" # pulled charts only; tracked local charts stay
done
exit $rc
