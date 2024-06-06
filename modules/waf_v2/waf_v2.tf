#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para el WAF v2 Web ACL
#--------------------------------------------------------------

variable "name"                 { }
variable "tags"                 { }
variable "enabled"              { default = true }
variable "scope"                { default = "REGIONAL" }
variable "allow_default_action" { default = true }
variable "visibility_config"    {
  type        = map(string)
  description = "Visibility config for WAFv2 web acl. https://www.terraform.io/docs/providers/aws/r/wafv2_web_acl.html#visibility-configuration"
  default     = {}
}
variable "rules_custom"         { default = []}
variable "rules"                { default = []   }
variable "rules_ip_set"         { default = []   }
variable "rules_geo"            { default = []   }
variable "rules_rate"           { default = null }
variable "resources_arn"        { default = []   }

resource "aws_wafv2_web_acl" "main" {
  count = var.enabled ? 1 : 0

  name  = var.name
  scope = var.scope

  default_action {
      dynamic "allow" {
      for_each = var.allow_default_action ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.allow_default_action ? [] : [1]
      content {}
    }
  }
  #CUSTOM RULES USAGE EXAMPLE IN TIENDA DIGITAL
dynamic "rule" {
    for_each = var.rules_custom
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        allow {}
      }

      dynamic "statement" {
        for_each = length(lookup(rule.value, "statement")) == 0 ? [] : [lookup(rule.value, "statement", {})]
        content {
          and_statement {
            statement {
              byte_match_statement {
                positional_constraint = rule.value.statement.positional_constraint
                search_string         = rule.value.statement.search_string

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }

            statement {
              byte_match_statement {
                positional_constraint = rule.value.statement.method_constraint
                search_string         = rule.value.statement.method

                field_to_match {
                  method {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-default-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }
  #MANAGED RULES
  dynamic "rule" {
    for_each = var.rules
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      override_action {
        dynamic "none" {
          for_each = length(lookup(rule.value, "override_action", {})) == 0 || lookup(rule.value, "override_action", {}) == "none" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = lookup(rule.value, "override_action", {}) == "count" ? [1] : []
          content {}
        }
      }

      statement {
        dynamic "managed_rule_group_statement" {
          for_each = length(lookup(rule.value, "managed_rule_group_statement", {})) == 0 ? [] : [lookup(rule.value, "managed_rule_group_statement", {})]
          content {
            name        = lookup(managed_rule_group_statement.value, "name")
            vendor_name = lookup(managed_rule_group_statement.value, "vendor_name", "AWS")

            # dynamic "excluded_rule" {
            #   for_each = length(lookup(managed_rule_group_statement.value, "excluded_rule", {})) == 0 ? [] : toset(lookup(managed_rule_group_statement.value, "excluded_rule"))
            #   content {
            #     name = excluded_rule.value
            #   }
            # }
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-default-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }
  #IP_SET RULES
  dynamic "rule" {
    for_each = var.rules_ip_set
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      action {
        dynamic "allow" {
          for_each = length(lookup(rule.value, "action", {})) == 0 || lookup(rule.value, "action", {}) == "allow" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = lookup(rule.value, "action", {}) == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = lookup(rule.value, "action", {}) == "block" ? [1] : []
          content {}
        }
      }

      statement {
        dynamic "ip_set_reference_statement" {
          for_each = length(lookup(rule.value, "ip_set_reference_statement", {})) == 0 ? [] : [lookup(rule.value, "ip_set_reference_statement", {})]
          content {
            arn = lookup(ip_set_reference_statement.value, "arn")
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-ip-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }
  #GEO RULES
  dynamic "rule" {
    for_each = var.rules_geo
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      action {
        dynamic "allow" {
          for_each = length(lookup(rule.value, "action", {})) == 0 || lookup(rule.value, "action", {}) == "allow" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = lookup(rule.value, "action", {}) == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = lookup(rule.value, "action", {}) == "block" ? [1] : []
          content {}
        }
      }

      statement {
        dynamic "geo_match_statement" {
          for_each = length(lookup(rule.value, "geo_match_statement", {})) == 0 ? [] : [lookup(rule.value, "geo_match_statement", {})]
          content {
            country_codes = lookup(geo_match_statement.value, "country_codes")
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-ip-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }
  #RATE RULES
  dynamic "rule" {
    for_each = var.rules_rate != null ? [var.rules_rate] : []
    content {
      name     = lookup(rule.value, "name")
      priority = lookup(rule.value, "priority")

      action {
        dynamic "count" {
          for_each = lookup(rule.value, "action", {}) == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = length(lookup(rule.value, "action", {})) == 0 || lookup(rule.value, "action", {}) == "block" ? [1] : []
          content {}
        }
      }

      statement {
        dynamic "rate_based_statement" {
          for_each = length(lookup(rule.value, "rate_based_statement", {})) == 0 ? [] : [lookup(rule.value, "rate_based_statement", {})]
          content {
            limit              = lookup(rate_based_statement.value, "limit")
            aggregate_key_type = lookup(rate_based_statement.value, "aggregate_key_type", "IP")
            
            dynamic "forwarded_ip_config" {
              for_each = length(lookup(rule.value, "forwarded_ip_config", {})) == 0 ? [] : [lookup(rule.value, "forwarded_ip_config", {})]
              content {
                fallback_behavior = lookup(forwarded_ip_config.value, "fallback_behavior")
                header_name       = lookup(forwarded_ip_config.value, "header_name")
              }
            }
          }
        }
      }

      dynamic "visibility_config" {
        for_each = length(lookup(rule.value, "visibility_config")) == 0 ? [] : [lookup(rule.value, "visibility_config", {})]
        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-ip-rate-based-rule-metric-name")
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }
    }
  }
  
  tags  = merge(
    var.tags,
    { Name = var.name },
  )
  
  dynamic "visibility_config" {
    for_each = length(var.visibility_config) == 0 ? [] : [var.visibility_config]
    content {
      cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
      metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-default-web-acl-metric-name")
      sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
    }
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  count = var.enabled && length(var.resources_arn) > 0 ? length(var.resources_arn) : 0
  
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
  resource_arn = var.resources_arn[count.index]

  depends_on = [aws_wafv2_web_acl.main]
}

output "web_acl_name" { value = join("", aws_wafv2_web_acl.main.*.name) }
output "web_acl_arn" { value = join("", aws_wafv2_web_acl.main.*.arn) }
output "web_acl_id" { value = join("", aws_wafv2_web_acl.main.*.id) }
output "web_acl_capacity" { value = join("", aws_wafv2_web_acl.main.*.capacity) }