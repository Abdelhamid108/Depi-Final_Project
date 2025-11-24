resource "aws_s3_bucket" "amazona_bucket" {
  bucket = var.products_bucket_name
  tags = {
      Name = "products-s3-bucket"
      Enivronemt = "Production"
  }
}

resource "aws_s3_bucket_ownership_controls" "amazona_bucket" {
  bucket = aws_s3_bucket.amazona_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "amazona_bucket" {
  bucket = aws_s3_bucket.amazona_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "amazona_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.amazona_bucket,
    aws_s3_bucket_public_access_block.amazona_bucket,
  ]

  bucket = aws_s3_bucket.amazona_bucket.id
  acl    = "public-read"
}
