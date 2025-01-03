# Data source to look up the existing Route 53 Hosted Zone
data "aws_route53_zone" "existing_zone" {
  name         = "pedrollanca.com." # Replace with your domain name
  private_zone = false          # Set to true if it's a private zone
}

# Example: Output the Hosted Zone ID for reference
output "hosted_zone_id" {
  value = data.aws_route53_zone.existing_zone.zone_id
}