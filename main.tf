terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  bucket_name = "sienna-wong.boxofwhite.com"
}

# S3 Bucket
resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Make bucket publicly readable
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Allow time for public access block settings to propagate
resource "time_sleep" "wait_for_public_access" {
  depends_on      = [aws_s3_bucket_public_access_block.website]
  create_duration = "10s"
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  depends_on = [time_sleep.wait_for_public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# IAM policy scoped to this bucket and CloudFront distribution
resource "aws_iam_policy" "website_deploy" {
  name        = "sienna-wong-website-deploy"
  description = "Allows deploy access to the ${local.bucket_name} S3 bucket and CloudFront invalidation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy"
        ]
        Resource = aws_s3_bucket.website.arn
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.website.arn}/*"
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.website.arn
      }
    ]
  })
}

# CloudFront response headers policy (all 5 Lighthouse security headers)
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "sienna-wong-security-headers"

  security_headers_config {
    # 1. CSP - effective against XSS attacks
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' https://fonts.googleapis.com 'unsafe-inline'; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; require-trusted-types-for 'script'"
      override = true
    }

    # 2. HSTS - strong HTTPS policy
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # 3. COOP - proper origin isolation
    content_type_options {
      override = true
    }

    # 4. X-Frame-Options - mitigate clickjacking
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # 5. Referrer-Policy (bonus security)
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    # 3. COOP - proper origin isolation
    items {
      header   = "Cross-Origin-Opener-Policy"
      value    = "same-origin"
      override = true
    }
  }
}

# ACM certificate (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "website" {
  domain_name       = local.bucket_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [local.bucket_name]
  price_class         = "PriceClass_100"

  depends_on = [aws_acm_certificate_validation.website]

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-Website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-Website"
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 600
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.website.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_acm_certificate.website.domain_validation_options : record.resource_record_name]
}

# Outputs
output "website_endpoint" {
  description = "S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_url" {
  description = "Full website URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = aws_cloudfront_distribution.website.id
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website.id
}

output "deploy_policy_arn" {
  description = "ARN of the IAM deploy policy — attach this to your IAM user"
  value       = aws_iam_policy.website_deploy.arn
}

output "acm_validation_records" {
  description = "DNS CNAME records to add to validate the ACM certificate"
  value = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
