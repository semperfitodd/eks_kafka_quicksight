terraform {
  backend "s3" {
    bucket = "bsc.sandbox.terraform.state"
    key    = "eks-kafka-quicksight/terraform.tfstate"
    region = "us-east-2"
  }
}
