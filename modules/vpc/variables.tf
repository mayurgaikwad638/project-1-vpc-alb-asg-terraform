variable "project_name" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "private_subnets_cidr" {
  type = list(string)
}

variable "public_subnet_cidr" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}
