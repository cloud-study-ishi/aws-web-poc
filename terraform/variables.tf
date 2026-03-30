variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" {
  type    = string
  default = "aws-poc"
}

variable "build_type" {
  type    = string
  default = "terraform"
}

variable "name_prefix" {
  type    = string
  default = "tf-poc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "public_subnet_c_cidr" {
  type    = string
  default = "10.1.2.0/24"
}

variable "az_a" {
  type    = string
  default = "ap-northeast-1a"
}

variable "az_c" {
  type    = string
  default = "ap-northeast-1c"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}