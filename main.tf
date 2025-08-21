# Lookup the existing Route 53 hosted zone
data "aws_route53_zone" "existing_zone" {
  name         = var.domain
  private_zone = false
}

# Generate a random suffix for unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Create the S3 bucket for static website hosting
resource "aws_s3_bucket" "static_website" {
  bucket = "${var.project_name}-${random_id.bucket_suffix.hex}" # e.g., homesite-abc12345

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.static_website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the static website bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create the S3 bucket for logging
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "account-logging-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-logging-bucket"
  }
}

# Define ownership controls for the logging bucket
resource "aws_s3_bucket_ownership_controls" "logging_bucket_controls" {
  bucket = aws_s3_bucket.logging_bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

# Enable server-side encryption for the logging bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logging_bucket" {
  bucket = aws_s3_bucket.logging_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for the logging bucket
resource "aws_s3_bucket_public_access_block" "logging_bucket" {
  bucket = aws_s3_bucket.logging_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create an SSL certificate (ACM) for your domain
resource "aws_acm_certificate" "ssl_certificate" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"

  subject_alternative_names = var.acm_subject_alternative_names

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# Validate domain ownership for the SSL certificate
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in toset(aws_acm_certificate.ssl_certificate.domain_validation_options) : dvo.resource_record_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

# Link the SSL certificate with domain validation
resource "aws_acm_certificate_validation" "default" {
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

# Create CloudFront response headers policy for security headers
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# Create WAF Web ACL for CloudFront protection
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name  = "${var.project_name}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = false
    }
  }

  tags = {
    Name = "${var.project_name}-waf"
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = false
  }
}

# Create a CloudFront distribution with HTTPS for the S3 bucket
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for CloudFront to restrict S3 access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "static_website" {
  enabled     = true
  price_class = "PriceClass_100"

  # Configure origin (S3 bucket) for CloudFront
  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.static_website.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Define default cache behavior
  default_cache_behavior {
    target_origin_id           = aws_s3_bucket.static_website.id
    viewer_protocol_policy     = "redirect-to-https" # Enforce HTTPS
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    default_ttl = var.cloudfront_default_ttl  # TTL fetched from variable
    max_ttl = var.cloudfront_max_ttl      # TTL fetched from variable
    min_ttl = var.cloudfront_min_ttl      # TTL fetched from variable
  }

  # Associate WAF Web ACL with CloudFront
  web_acl_id = aws_wafv2_web_acl.cloudfront_waf.arn

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403
    response_code         = 200
    response_page_path    = "/${var.static_website_error_document}"
  }

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 200
    response_page_path    = "/${var.static_website_error_document}"
  }

  # Enable SSL using ACM certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.default.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  default_root_object = var.static_website_index_document

  aliases = var.acm_subject_alternative_names

  # Logging configuration for CloudFront
  logging_config {
    bucket          = aws_s3_bucket.logging_bucket.bucket_regional_domain_name
    prefix          = var.logging_bucket_prefix
    include_cookies = false # Optional: include cookies information in logs
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}

# Block public access settings (allow bucket policies temporarily)
resource "aws_s3_bucket_public_access_block" "allow_bucket_policy" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = true
  block_public_policy     = false # Allow public policy for CloudFront integration
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Update S3 bucket policy to allow only access from CloudFront
resource "aws_s3_bucket_policy" "cloudfront_access_policy" {
  bucket = aws_s3_bucket.static_website.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "Service": "cloudfront.amazonaws.com"
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.static_website.arn}/*",
        Condition = {
          StringEquals: {
            "AWS:SourceArn": aws_cloudfront_distribution.static_website.arn
          }
        }
      }
    ]
  })
}

# Create Route 53 DNS record for the www subdomain
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = "www.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = var.domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Upload index.html to the S3 bucket
resource "aws_s3_object" "index" {
  bucket        = aws_s3_bucket.static_website.bucket
  key           = var.static_website_index_document
  source        = "resources/website/index.html" # Path to your local index.html file
  content_type  = "text/html"
  etag          = filemd5("resources/website/index.html")
  cache_control = "max-age=300"  # 5 minutes cache
}

# Upload error.html to the S3 bucket
resource "aws_s3_object" "error" {
  bucket        = aws_s3_bucket.static_website.bucket
  key           = var.static_website_error_document
  source        = "resources/website/error.html" # Path to your local error.html file
  content_type  = "text/html"
  etag          = filemd5("resources/website/error.html")
  cache_control = "max-age=300"  # 5 minutes cache
}