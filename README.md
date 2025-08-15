
# AWS Static Website Hosting Infrastructure
This project provisions AWS infrastructure for hosting a **secure and scalable** static website with enterprise-grade security features. The setup includes comprehensive security controls, encryption, and threat protection.

## Overview

This infrastructure implements security best practices including:
- **End-to-end encryption** for data at rest and in transit
- **Web Application Firewall (WAF)** protection against common threats
- **Security headers** for enhanced browser security
- **Strict access controls** with Origin Access Control (OAC)
- **Comprehensive logging** for security monitoring

## Components

### Amazon S3 Buckets
- **Website Bucket**: Hosts static website files (`index.html`, `error.html`) with AES-256 server-side encryption
- **Logging Bucket**: Stores CloudFront access logs with encryption and strict public access blocking
- **Versioning**: Enabled on the website bucket for data protection and recovery
- **Random Suffix**: Appended to bucket names to ensure global uniqueness

### CloudFront Distribution
A Content Delivery Network (CDN) distribution serves the website through a global network of edge locations with enhanced security:
- **Origin Access Control (OAC)**: Restricts direct S3 access, ensuring all traffic flows through CloudFront
- **HTTPS Enforcement**: Redirects all HTTP traffic to HTTPS (TLS 1.2 minimum)
- **Security Headers**: Automatically applies security headers (HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
- **Custom Error Pages**: Handles 403/404 errors with custom error document

### AWS WAF (Web Application Firewall)
Provides protection against common web exploits and attacks:
- **AWS Managed Rule Sets**: 
  - Common Rule Set: Protection against OWASP Top 10 vulnerabilities
  - Known Bad Inputs Rule Set: Blocks requests with known malicious patterns
- **CloudWatch Integration**: Monitoring and metrics for security events

### Amazon Route 53
DNS configuration for custom domain management:
- **Wildcard SSL Certificate**: Supports multiple subdomains
- **Alias Records**: Efficient routing to CloudFront distribution
- **DNS Validation**: Automated certificate validation

### AWS Certificate Manager (ACM)
- **Wildcard TLS/SSL Certificate**: Secures multiple subdomains
- **Automatic Renewal**: AWS manages certificate lifecycle
- **DNS Validation**: Automated domain ownership verification

### Security Headers Policy
CloudFront response headers policy that adds security headers to all responses:
- **Strict-Transport-Security (HSTS)**: Forces HTTPS for 1 year, includes subdomains
- **X-Content-Type-Options**: Prevents MIME type sniffing
- **X-Frame-Options**: Prevents clickjacking attacks (DENY)
- **Referrer-Policy**: Controls referrer information sharing

### Access Controls & Encryption
- **S3 Server-Side Encryption**: AES-256 encryption for all objects at rest
- **Public Access Blocking**: Comprehensive blocking of public access to both buckets
- **CloudFront-Only Access**: S3 bucket policy restricts access to CloudFront service only
- **Signed Requests**: All CloudFront-to-S3 requests use SigV4 signing

### Monitoring & Logging
- **CloudFront Access Logs**: Detailed request logging stored in encrypted S3 bucket
- **WAF Metrics**: Security event monitoring through CloudWatch
- **Access Log Analysis**: Supports security monitoring and traffic analysis

## Security Features Summary
✅ **Data Encryption**: At rest (S3) and in transit (HTTPS/TLS 1.2+)  
✅ **Web Application Firewall**: Protection against common attacks  
✅ **Security Headers**: Browser-level security enhancements  
✅ **Access Controls**: Zero direct public access to S3 buckets  
✅ **HTTPS Enforcement**: All traffic encrypted with modern TLS  
✅ **Comprehensive Logging**: Full request logging for security monitoring  
✅ **Automated Security**: AWS managed rules and certificate management
