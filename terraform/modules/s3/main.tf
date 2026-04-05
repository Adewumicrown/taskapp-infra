# ─── Kops State Store Bucket ───────────────────────────────────────────────
# This is where Kops stores your cluster configuration and state
resource "aws_s3_bucket" "kops_state" {
  bucket = "${var.project_name}-kops-state-${var.aws_account_id}-${var.aws_region}"

  # Prevent accidental deletion of this bucket
  # Your cluster depends on it being available at all times
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-kops-state"
    Project = var.project_name
    Purpose = "kops-state-store"
  }
}

# Block all public access — cluster state must never be public
resource "aws_s3_bucket_public_access_block" "kops_state" {
  bucket                  = aws_s3_bucket.kops_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning — keeps history of every cluster state change
# Allows you to roll back to a previous cluster configuration
resource "aws_s3_bucket_versioning" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the bucket at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ─── etcd Backup Bucket ────────────────────────────────────────────────────
# Daily automated snapshots of your Kubernetes cluster database land here
resource "aws_s3_bucket" "etcd_backup" {
  bucket = "${var.project_name}-etcd-backup-${var.aws_account_id}-${var.aws_region}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-etcd-backup"
    Project = var.project_name
    Purpose = "etcd-backup"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "etcd_backup" {
  bucket                  = aws_s3_bucket.etcd_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on backup bucket too
resource "aws_s3_bucket_versioning" "etcd_backup" {
  bucket = aws_s3_bucket.etcd_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt backup bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "etcd_backup" {
  bucket = aws_s3_bucket.etcd_backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule — automatically delete backups older than 30 days
# Keeps storage costs low while retaining a month of recovery points
resource "aws_s3_bucket_lifecycle_configuration" "etcd_backup" {
  bucket = aws_s3_bucket.etcd_backup.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"
# Empty filter means the rule applies to ALL objects in the bucket
    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
