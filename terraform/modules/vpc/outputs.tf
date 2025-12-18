output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = [for subnet in aws_subnet.database : subnet.id]
}

output "public_subnets" {
  description = "Map of public subnet objects by AZ"
  value       = aws_subnet.public
}

output "private_subnets" {
  description = "Map of private subnet objects by AZ"
  value       = aws_subnet.private
}

output "database_subnets" {
  description = "Map of database subnet objects by AZ"
  value       = aws_subnet.database
}

output "nat_gateway_ids" {
  description = "Map of NAT Gateway IDs by AZ"
  value = {
    for az, nat_gw in aws_nat_gateway.main : az => nat_gw.id
  }
}

output "nat_gateway_public_ips" {
  description = "Map of NAT Gateway public IPs by AZ"
  value = {
    for az, eip in aws_eip.nat : az => eip.public_ip
  }
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}
