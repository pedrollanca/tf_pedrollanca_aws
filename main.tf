# Step 1: Lookup the Existing Route 53 Hosted Zone
data "aws_route53_zone" "existing_zone" {
  name         = var.domain
  private_zone = false
}

# Step 2: Generate a Random Suffix for Unique S3 Bucket Name
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Step 3: Create the S3 Bucket for Static Website Hosting
resource "aws_s3_bucket" "static_website" {
  bucket = "${var.project_name}-${random_id.bucket_suffix.hex}" # e.g., homesite-abc12345

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

# Enable versioning for safety
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.static_website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Define the destination bucket for logging
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "account-logging-${random_id.bucket_suffix.hex}"
}

# Step 4: Create an SSL Certificate (ACM) for Your Domain
resource "aws_acm_certificate" "ssl_certificate" {
  domain_name       = var.domain
  validation_method = "DNS"

  subject_alternative_names = var.acm_subject_alternative_names

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# Validate Domain Ownership for SSL Certificate
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_certificate.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "default" {
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

# Step 5: Create a CloudFront Distribution with HTTPS for Your S3 Bucket
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for CloudFront to restrict S3 access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "static_website" {
  enabled = true

  # Origin Configuration for CloudFront (Serving S3 bucket content)
  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.static_website.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Default Cache Behavior
  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.static_website.id
    viewer_protocol_policy = "redirect-to-https" # Enforce HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    default_ttl = var.cloudfront_default_ttl  # Fetch from variable
    max_ttl     = var.cloudfront_max_ttl      # Fetch from variable
    min_ttl     = var.cloudfront_min_ttl      # Fetch from variable
  }

  # Enable SSL using ACM Certificate
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.default.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_root_object = var.static_website_index_document

  # Logging Configuration for CloudFront
  logging_config {
    bucket = aws_s3_bucket.logging_bucket.bucket_regional_domain_name
    prefix = var.logging_bucket_prefix
    include_cookies = false # Optional: include cookies information in logs
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}

# Step 6: Update S3 Bucket Policy for CloudFront Only Access
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

# Step 7: Route 53 DNS Record for Your Domain and Subdomain
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
  bucket       = aws_s3_bucket.static_website.bucket
  key          = var.static_website_index_document
  source       = "resources/website/index.html" # Path to your local index.html file
  content_type = "text/html"
}

# Upload error.html to the S3 bucket
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.static_website.bucket
  key          = var.static_website_error_document
  source       = "resources/website/error.html" # Path to your local index.html file
  content_type = "text/html"
}