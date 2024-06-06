#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para el WAF v2 Web ACL
#--------------------------------------------------------------

variable "name"        { }
variable "tags"        { }
variable "addresses"   { }
variable "scope_wafv2_ip_set" { default = "REGIONAL" }
variable "ip_address_version" { default = "IPV4" }
resource "aws_wafv2_ip_set" "ip_set_ipv4" {
  name               = var.name
  scope              = var.scope_wafv2_ip_set
  ip_address_version = var.ip_address_version
  addresses          = var.addresses
  tags               = var.tags
}

output "ip_set_arn" { value = aws_wafv2_ip_set.ip_set_ipv4.arn }