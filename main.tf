terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

    backend "s3" {
    bucket         = "mayur-ha-infra-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mayur-ha-infra-tfstate-lock"
    encrypt        = true
  }

}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "app" {
  bucket = "${var.project_name}-app-files"
  tags = {Name = "${var.project_name}-app-files"}
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = enable
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.app.id
  key          = "index.html"
  source       = "${path.module}/app/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/app/index.html")
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr_block = var.vpc_cidr
  private_subnets_cidr = var.private_subnet_cidrs
  public_subnet_cidr = var.public_subnet_cidrs
  availability_zones = var.availability_zones
}

module "sg" {
  source = "./modules/sg"

  project_name = var.project_name
  my_ip = var.my_ip
  vpc_id = module.vpc.vpc_id
}

module "alb" {
  source = "./modules/alb"

  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id = module.sg.alb_sg_id
  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
}

module "asg" {
  source = "./modules/asg"

  project_name = var.project_name
  s3_bucket_name = aws_s3_bucket.app.bucket
  ec2_sg_id = module.sg.ec2_sg_id
  key_name = var.key_name
  private_subnet_ids = module.vpc.private_subnets_ids
  target_group_arn = module.alb.tg_arn
  bastion_sg_id = module.sg.bastion_sg_id
  ami_id = var.ami_id
  bastion_subnet_id = module.vpc.public_subnet_ids[0]
}

