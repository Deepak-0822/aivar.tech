terraform {
  source = "./"
}

remote_state {
  backend = "s3"
  config  = {
    encrypt        = true
    bucket         = "aivolvex-s3-us-east-1-terraformstate"
    key            = "aws/infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aivolvex-s3-us-east-1-terraformstatelock-dynamodb"
  }
}
