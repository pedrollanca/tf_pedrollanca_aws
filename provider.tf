provider "aws" {
  region     = "us-east-1"
  assume_role {
    role_arn = var.AWS_ROLE_ARN
  }
}