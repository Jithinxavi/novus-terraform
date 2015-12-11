variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_key_name" {}

variable "aws_region" {
  description = "The AWS region to create resources."
  default = "us-east-1"
}

# ubuntu-trusty-14.04 (x64)
variable "aws_web_ami" {
  default = {
    "us-east-1" = "ami-d05e75b8"
    "us-west-2" = "ami-5189a661"
  }
}

variable "aws_app_ami" {
  default = {
    "us-east-1" = "ami-d05e75b8"
    "us-west-2" = "ami-5189a661"
  }
}

variable "aws_nat_ami" {
  default = {
    "ami_image" = "ami-c02b04a8"
  }
}

variable "vpc_cidr" {
    description = "CIDR for VPC"
    default = "10.192.0.0/16"
}
variable "public_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.192.3.0/27"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.192.4.0/27"
}
