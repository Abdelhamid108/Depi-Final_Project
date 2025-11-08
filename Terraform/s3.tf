# s3.tf

resource "aws_s3_bucket" "logs_bucket" {
  bucket = var.logs_s3_bucket_name
}
