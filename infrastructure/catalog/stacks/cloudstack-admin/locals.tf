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
    # Standard Login fields (username / password)
    {
      username = try(data.onepassword_item.cs_homecloud_creds.username, "")
      password = try(data.onepassword_item.cs_homecloud_creds.password, "")
    },
    # Any section fields (email, First name, Last name, etc.)
    merge([
      for s in data.onepassword_item.cs_homecloud_creds.section : {
        for f in s.field : f.label => f.value
      }
    ]...)
  )
}
