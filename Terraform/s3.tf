#
# --- s3.tf ---
# This file defines the S3 bucket for storing logs.

resource "aws_s3_bucket" "logs_bucket" {
  # The bucket name is provided by a variable.
  # This MUST be globally unique.
  bucket = var.logs_s3_bucket_name
}
