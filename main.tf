terraform {
    required_version = ">= 1.10.0"
    required_providers {
        aws = {
            version = ">= 5.80.0"
            source = "hashicorp/aws"
        }
    }
}

provider "aws" {
  region  = var.aws_region
  access_key  = var.aws_access_key
  secret_key  = var.aws_secret_key
} 

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name  = "terraform-vpc"

  cidr  = "172.33.0.0/16"
  azs   = ["us-east-1a", "us-east-1b"]
  public_subnets = ["172.33.10.0/24", "172.33.11.0/24"]
  private_subnets = ["172.33.20.0/24", "172.33.21.0/24"]

  tags = {
    terraform = "true"
    enviroment = "dev"
  }
}

resource "aws_instance" "app_server" {
  count = 2

  # Canonical, Ubuntu, 24.04, amd64 noble image
  ami           = "ami-0e2c8caa4b6378d8c"
  
  # Private subnet of the created vpc
  subnet_id     = module.vpc.private_subnets[count.index]  
  instance_type = "t3a.nano"

  tags = {
    terraform = "true"
    enviroment = "dev"
  }
}

resource "aws_security_group" "sg_lb" {
  name = "sg_lb-terraform"
  description = "Security group for the load balancer"
  vpc_id  = module.vpc.vpc_id

  tags = {
    terraform = "true"
    enviroment = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.sg_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv6" {
  security_group_id = aws_security_group.sg_lb.id
  cidr_ipv6         = "::/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.sg_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.sg_lb.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}

resource "aws_elb" "elb" {
  name               = "clb-terraform"
  subnets = module.vpc.public_subnets
  security_groups    = [aws_security_group.sg_lb.id]

  instances = aws_instance.app_server[*].id

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    terraform = "true"
    enviroment = "dev"
  }
}
