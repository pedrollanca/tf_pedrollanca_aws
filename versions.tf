terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "pedrollanca"
    workspaces {
      name = "tf_pedrollanca_aws"
    }
  }

}