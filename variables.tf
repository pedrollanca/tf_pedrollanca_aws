variable "AWS_ACCOUNT_ID" {
  description = "AWS account ID"
  type        = string
}

variable "AWS_ROLE_ARN" {
  description = "Execution role ARN for Terraform"
  type        = string
}

variable "domain" {
  description = "Domain name"
  type        = string
}

variable "project_name" {
  description = "Base name of the project (e.g., homesite)"
  type        = string
  default     = "homesite"
}

variable "cloudfront_default_ttl" {
  description = "Default Time-to-Live (TTL) for CloudFront cache (in seconds)"
  type        = number
  default     = 3600
}

variable "cloudfront_max_ttl" {
  description = "Maximum Time-to-Live (TTL) for CloudFront cache (in seconds)"
  type        = number
  default     = 86400
}

variable "cloudfront_min_ttl" {
  description = "Minimum Time-to-Live (TTL) for CloudFront cache (in seconds)"
  type        = number
  default     = 0
}

variable "logging_bucket_prefix" {
  description = "Prefix for logs stored in the logging bucket"
  type        = string
  default     = "cloudfront-logs/"
}

variable "acm_subject_alternative_names" {
  description = "Subject alternative names to use for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "static_website_index_document" {
  description = "The index document for the static website"
  type        = string
  default     = "index.html"
}

variable "static_website_error_document" {
  description = "The error document for the static website"
  type        = string
  default     = "error.html"
}