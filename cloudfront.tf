
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id        = data.aws_caller_identity.current.account_id
  aws_region            = data.aws_region.current.name
  aws_account_principal = "arn:aws:iam::${local.aws_account_id}:root"
}
# Create an S3 bucket to store static content
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "my-frontend-static-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name        = "FrontendStaticContent"
    Environment = "Production"
  }
}

# resource "aws_s3_bucket_policy" "oai" {
#   bucket = aws_s3_bucket.frontend_bucket.id

#   policy = jsonencode({
#     "Version" : "2008-10-17",
#     "Id" : "PolicyForCloudFrontPrivateContent",
#     "Statement" : [
#       {
#         "Sid" : "OAIPermissions"
#         "Effect" : "Allow",
#         "Principal" : {
#           "AWS" : "${var.cloudfront_oai_iam_arn}"
#         },
#         "Action" : "s3:GetObject",
#         "Resource" : "${var.oai_bucket_arn}/*"
#       }
#     ]
#   })
# }

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.cloudfront.json
}

data "aws_iam_policy_document" "cloudfront" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      aws_s3_bucket.frontend_bucket.arn,
      "${aws_s3_bucket.frontend_bucket.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.frontend_distribution.arn
      ]
    }
  }
}

# # Placeholder for S3 bucket policy
# resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
#   bucket = aws_s3_bucket.frontend_bucket.id

#   policy = <<POLICY
#   {
#     // Hint: Create a policy that allows only the CloudFront Origin Access Control (OAC) to access the bucket
#   }
#   POLICY
# }

# Create an Origin Access Control (OAC) for CloudFront
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name            = "frontend-oac"
  description     = "OAC for Frontend Application"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.frontend_bucket.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_control.frontend_oac.id
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  web_acl_id                         = aws_wafv2_web_acl.geo_restriction_acl.id
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.frontend_bucket.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["CO"]
    }
  }
  tags = {
    Name        = "FrontendDistribution"
    Environment = "Production"
  }
}

# Create a WAFv2 Web ACL with geographic control
resource "aws_wafv2_web_acl" "geo_restriction_acl" {
  name        = "geo-restriction-acl"
  description = "Web ACL with geographic restrictions"

  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "GeoRestrictionRule"
    priority = 1

    statement {
      geo_match_statement {
        country_codes = ["CO"]
      }
    }

    action {
      allow {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoRestrictionRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "GeoRestrictionACL"
    sampled_requests_enabled   = true
  }
}


module "waf_web_acl_cloudfront" {
    source               = "./modules/waf_v2"
    name                 = "waf-develop-banco-bogota"
    tags                 = { "stack_id"= "dev", "layer"= "cloudfront_banco_bogota" }
    scope                = "CLOUDFRONT"
    allow_default_action = true
    visibility_config    = {
      cloudwatch_metrics_enabled = false
      sampled_requests_enabled   = false
    }
    rules = [
        {
            name     = "AWS-AWSManagedRulesAmazonIpReputationList"
            priority = 200

            override_action = "none"

            visibility_config = {
                cloudwatch_metrics_enabled = true
                metric_name                = "managedrules-amazonipreputationlist"
                sampled_requests_enabled   = true
            }

            managed_rule_group_statement = {
                name        = "AWSManagedRulesAmazonIpReputationList"
                vendor_name = "AWS"
            }
        },
        {
            name     = "AWS-AWSManagedRulesAnonymousIpList"
            priority = 300

            override_action = "none"

            visibility_config = {
                cloudwatch_metrics_enabled = true
                metric_name                = "managedrules-anonymousiplist"
                sampled_requests_enabled   = true
            }

            managed_rule_group_statement = {
                name        = "AWSManagedRulesAnonymousIpList"
                vendor_name = "AWS"
            }
        },
        {
            name     = "AWS-AWSManagedRulesCommonRuleSet"
            priority = 400

            override_action = "none"

            visibility_config = {
                cloudwatch_metrics_enabled = true
                metric_name                = "managedrules-commonruleset"
                sampled_requests_enabled   = true
            }

            managed_rule_group_statement = {
                name        = "AWSManagedRulesCommonRuleSet"
                vendor_name = "AWS"

                excluded_rule = [
                    "SizeRestrictions_BODY"
                ]
            }
        },
        {
            name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
            priority = 500

            override_action = "none"

            visibility_config = {
                cloudwatch_metrics_enabled = true
                metric_name                = "managedRules-knownbadinputsruleset"
                sampled_requests_enabled   = true
            }

            managed_rule_group_statement = {
                name        = "AWSManagedRulesKnownBadInputsRuleSet"
                vendor_name = "AWS"
            }
        }
    ]

    rules_rate = {
        name     = "IpRateBasedRule-7"
        priority = 50

        action = "count"

        visibility_config = {
            cloudwatch_metrics_enabled = true
            metric_name                = "IpRateBasedRule-metric"
            sampled_requests_enabled   = true
        }

        rate_based_statement = {
            limit              = 1000
            aggregate_key_type = "IP"
        }
    }
}

# Placeholder for associating WAFv2 with CloudFront distribution
# Hint: Use aws_cloudfront_distribution.frontend_distribution.arn for the association