variable "AWS_ACCOUNT_ID" {
  description = "AWS account ID"
  type        = string
}

variable "AWS_ROLE_ARN" {
  default = "Execution role ARN for Terraform"
  type = string
}