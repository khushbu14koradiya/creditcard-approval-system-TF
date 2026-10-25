
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "public_instance_public_ips" {
  description = "Public IPs of public EC2 instances"
  value       = aws_instance.public[*].public_ip
}

output "public_instance_private_ips" {
  description = "Private IPs of public EC2 instances"
  value       = aws_instance.public[*].private_ip
}

output "private_instance_private_ips" {
  description = "Private IPs of private EC2 instances"
  value       = aws_instance.private[*].private_ip
}

output "ssh_private_key_path" {
  description = "Local private SSH key path"
  value       = pathexpand("~/.ssh/terraform-vpc-key")
}