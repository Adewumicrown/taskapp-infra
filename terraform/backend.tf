terraform {
  backend "s3" {
    bucket         = "taskapp-terraform-state-victor-311156639915-us-east-1-an"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "taskapp-terraform-locks"
    encrypt        = true
  }
}
