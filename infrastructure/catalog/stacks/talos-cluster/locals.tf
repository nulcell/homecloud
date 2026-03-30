locals {
  _cs_fields    = merge([for s in data.onepassword_item.cs_homecloud.section : { for f in s.field : f.label => f.value }]...)
  cs_api_key    = local._cs_fields["api-key"]
  cs_secret_key = local._cs_fields["secret-key"]
}
