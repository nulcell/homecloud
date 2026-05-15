# Store the CloudStack API credentials in a 1Password item under a section
# with fields labelled "api key" and "secret key".
locals {
  _cs_admin_fields = merge([
    for s in data.onepassword_item.cs_admin.section : {
      for f in s.field : f.label => f.value
    }
  ]...)
}

locals {
  _cs_homecloud_fields = merge(
    {
      username = try(data.onepassword_item.cs_homecloud_creds.username, "")
      password = try(data.onepassword_item.cs_homecloud_creds.password, "")
    },
    merge([
      for s in data.onepassword_item.cs_homecloud_creds.section : {
        for f in s.field : f.label => f.value
      }
    ]...)
  )
}

locals {
  resolved_domain_id = var.existing_domain_name != null ? data.cloudstack_domain.this[0].id : try(module.domain[0].domain_id, "")
}
