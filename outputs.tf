# Output the S3 bucket name
output "bucket_name" {
  value       = aws_s3_bucket.static_website.bucket
  description = "The name of the S3 bucket hosting the static website"
}

# Output the Route 53 record name
output "route53_record_name" {
  value       = aws_route53_record.www.name
  description = "The Route 53 DNS record for the S3 website"
}

# Output the Hosted Zone ID for reference
output "hosted_zone_id" {
  value       = data.aws_route53_zone.existing_zone.zone_id
  description = "The ID of the Hosted Zone in Route 53"
}

# Output the logging bucket name
output "logging_bucket_name" {
  value       = aws_s3_bucket.logging_bucket.bucket
  description = "The name of the S3 bucket used for logging"
}

# Output the CloudFront distribution domain name
output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.static_website.domain_name
  description = "The domain name of the CloudFront distribution"
}

# Output the CloudFront distribution ARN
output "cloudfront_distribution_arn" {
  value       = aws_cloudfront_distribution.static_website.arn
  description = "The ARN of the CloudFront distribution"
}

# Output the CloudFront distribution ID
output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.static_website.id
  description = "The ID of the CloudFront distribution"
}