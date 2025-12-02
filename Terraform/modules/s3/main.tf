# -----------------------------------------------------------------------------
# Module: S3 (Simple Storage Service)
# -----------------------------------------------------------------------------
# Provisions an S3 bucket for storing application assets (product images).
# - Configures public access settings (currently public-read).
# - Creates a dedicated IAM user for programmatic access to the bucket.
# -----------------------------------------------------------------------------

# Create the S3 Bucket
resource "aws_s3_bucket" "amazona_bucket" {
  bucket = var.products_bucket_name
  tags = {
      Name = "products-s3-bucket"
      Environment = "Production"
  }
}

# Configure Object Ownership
# 'BucketOwnerPreferred' ensures the bucket owner owns uploaded objects,
# which is important for ACLs to work correctly.
resource "aws_s3_bucket_ownership_controls" "amazona_bucket" {
  bucket = aws_s3_bucket.amazona_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Public Access Block Configuration
# WARNING: All blocks are set to 'false', meaning the bucket is PUBLIC.
# This is intended for serving product images directly to users.
resource "aws_s3_bucket_public_access_block" "amazona_bucket" {
  bucket = aws_s3_bucket.amazona_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket ACL (Access Control List)
# Sets the bucket to 'public-read' so anyone can view the images.
resource "aws_s3_bucket_acl" "amazona_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.amazona_bucket,
    aws_s3_bucket_public_access_block.amazona_bucket,
  ]

  bucket = aws_s3_bucket.amazona_bucket.id
  acl    = "public-read"
}

# -----------------------------------------------------------------------------
# IAM User for S3 Access
# -----------------------------------------------------------------------------
# Creates a dedicated user for the application to upload images.

resource "aws_iam_user" "s3_user" {
  name = "s3_user"
  
  tags = {
    Name = "s3-bucket-user"
    Description = "iam user for s3 products bucket"
  }
}

# Generate Access Keys for the IAM User
resource "aws_iam_access_key" "s3_user" {
  user = aws_iam_user.s3_user.name
}

# Attach S3 Full Access Policy to the User
resource "aws_iam_user_policy_attachment" "s3-user-attach" {
  user       = aws_iam_user.s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

