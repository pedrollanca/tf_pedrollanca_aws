
# AWS Static Website Hosting Infrastructure
This project provisions AWS infrastructure for hosting a secure and scalable static website. The setup includes the following components:

## Overview


### Amazon S3 Bucket
A bucket is created for hosting the static website. It stores the website's `index.html` and `error.html` files. A random suffix is appended to the bucket name to ensure uniqueness.

### CloudFront Distribution
A Content Delivery Network (CDN) distribution is configured to serve the website through a global network of edge locations. Origin Access Control (OAC) is used to restrict direct access to the S3 bucket, ensuring all content is accessed via CloudFront.

### Amazon Route 53
A DNS configuration allows the usage of a custom domain for the website. This ensures user-friendly URLs.

### AWS Certificate Manager (ACM)
A TLS/SSL certificate is provisioned to enable secure HTTPS access for the static website via CloudFront.

### Logging Bucket
An additional S3 bucket is created for storing server access logs for both the website bucket and the CloudFront distribution.

### Bucket Policies and Permissions
Specific policies are implemented to secure the buckets and control access. The CloudFront distribution is set up with policies that only permit content delivery through the distribution.

### Static Document Upload
The `index.html` and `error.html` files are uploaded to the S3 bucket during provisioning to serve as the main and error pages of the static site.
