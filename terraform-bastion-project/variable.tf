
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used to name resources"
  type        = string
  default     = "terraform-bastion"
}

variable "public_key_path" {
  description = "Local path to the public SSH key"
  type        = string
  default     = "~/.ssh/terraform-vpc-key.pub"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}