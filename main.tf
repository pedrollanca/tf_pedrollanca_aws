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

# Link the SSL certificate with domain validation
resource "aws_acm_certificate_validation" "default" {
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
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
  enabled = true

  # Configure origin (S3 bucket) for CloudFront
  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.static_website.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Define default cache behavior
  default_cache_behavior {
    target_origin_id = aws_s3_bucket.static_website.id
    viewer_protocol_policy = "redirect-to-https" # Enforce HTTPS
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]

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

  # Enable SSL using ACM certificate
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

# Create Route 53 DNS record for the root domain
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
  source = "resources/website/index.html" # Path to your local index.html file
  content_type = "text/html"
}

# Upload error.html to the S3 bucket
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.static_website.bucket
  key          = var.static_website_error_document
  source = "resources/website/error.html" # Path to your local index.html file
  content_type = "text/html"
}