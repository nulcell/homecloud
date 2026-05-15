locals {
  _ops_kube_fields = flatten([for s in data.onepassword_item.ops_kubeconfig.section : s.field])
  ops_kubeconfig   = one([for f in local._ops_kube_fields : f.value if f.label == "config"])
  _ops_kube_parsed = yamldecode(local.ops_kubeconfig)
}
