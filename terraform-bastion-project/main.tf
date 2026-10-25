
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Automatically detect the public IP of the computer
# running Terraform.
data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

# Find the latest official Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 1. VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "public"
  }
}

# 3. Private subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet"
    Tier = "private"
  }
}

# 4. Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 5. Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 6. Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 7. Private route table
# AWS automatically adds the local VPC route.
# No NAT Gateway and no internet default route.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# 8. Associate private subnet with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# 9. Register the public SSH key with AWS
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name = "${var.project_name}-key"
  }
}

# 10. Security group for public EC2 instances
resource "aws_security_group" "public" {
  name_prefix = "${var.project_name}-public-"
  description = "Allow SSH only from the detected public IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      "${chomp(data.http.my_public_ip.response_body)}/32"
    ]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-public-sg"
  }
}

# 11. Security group for private EC2 instances
resource "aws_security_group" "private" {
  name_prefix = "${var.project_name}-private-"
  description = "Allow SSH only from public EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from public EC2 security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    description = "Allow outbound traffic subject to routing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}

# 12. Two public EC2 instances
resource "aws_instance" "public" {
  count = 2

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public.id]
  key_name                    = aws_key_pair.main.key_name

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  }
}

# 13. Two private EC2 instances
resource "aws_instance" "private" {
  count = 2

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.private.id]
  key_name                    = aws_key_pair.main.key_name

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  }
}