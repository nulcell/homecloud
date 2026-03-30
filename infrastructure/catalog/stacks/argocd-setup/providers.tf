provider "kubernetes" {
  host = local._ops_kube_parsed["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(
    local._ops_kube_parsed["clusters"][0]["cluster"]["certificate-authority-data"]
  )
  client_certificate = base64decode(
    local._ops_kube_parsed["users"][0]["user"]["client-certificate-data"]
  )
  client_key = base64decode(
    local._ops_kube_parsed["users"][0]["user"]["client-key-data"]
  )
}

provider "onepassword" {
  account = var.op_account
}
