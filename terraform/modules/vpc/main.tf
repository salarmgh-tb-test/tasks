data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  # Use for_each friendly set of AZ names
  azs     = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  azs_set = toset(local.azs)

  # Create a map for subnet CIDR calculations
  az_index_map = { for idx, az in local.azs : az => idx }
}

#--------------------------------------------------------------
# VPC
#--------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })

  lifecycle {
    precondition {
      condition     = var.az_count >= 2
      error_message = "EKS requires at least 2 availability zones."
    }
  }
}

#--------------------------------------------------------------
# Internet Gateway
#--------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

#--------------------------------------------------------------
# Public Subnets (using for_each)
#--------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = local.azs_set

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, local.az_index_map[each.key])
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                        = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Tier                                        = "public"
  })
}

#--------------------------------------------------------------
# Private Subnets (Application) - using for_each
#--------------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = local.azs_set

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, local.az_index_map[each.key] + 10)
  availability_zone = each.key

  tags = merge(var.tags, {
    Name                                        = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Tier                                        = "private"
  })
}

#--------------------------------------------------------------
# Database Subnets (RDS) - using for_each
#--------------------------------------------------------------
resource "aws_subnet" "database" {
  for_each = local.azs_set

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, local.az_index_map[each.key] + 20)
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name}-database-${each.key}"
    Tier = "database"
  })
}

#--------------------------------------------------------------
# Elastic IPs for NAT Gateways
#--------------------------------------------------------------
locals {
  # Determine NAT Gateway AZs based on configuration
  nat_azs = var.enable_nat_gateway ? (
    var.single_nat_gateway ? [local.azs[0]] : local.azs
  ) : []
  nat_azs_set = toset(local.nat_azs)
}

resource "aws_eip" "nat" {
  for_each = local.nat_azs_set
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

#--------------------------------------------------------------
# NAT Gateways
#--------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  for_each = local.nat_azs_set

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    precondition {
      condition     = var.enable_nat_gateway
      error_message = "NAT Gateway must be enabled for private subnet internet access."
    }
  }
}

#--------------------------------------------------------------
# Route Tables
#--------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
    Tier = "public"
  })
}

# Private route tables - one per NAT Gateway (or one for single NAT)
resource "aws_route_table" "private" {
  for_each = local.nat_azs_set
  vpc_id   = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt-${each.key}"
    Tier = "private"
  })
}

# Fallback private route table when NAT is disabled
resource "aws_route_table" "private_no_nat" {
  count  = var.enable_nat_gateway ? 0 : 1
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt"
    Tier = "private"
  })
}

resource "aws_route_table" "database" {
  for_each = local.azs_set
  vpc_id   = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-database-rt-${each.key}"
    Tier = "database"
  })
}

# NAT Gateway routes for private subnets
resource "aws_route" "private_nat_gateway" {
  for_each = local.nat_azs_set

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? local.azs[0] : each.key].id
}

#--------------------------------------------------------------
# Route Table Associations
#--------------------------------------------------------------
resource "aws_route_table_association" "public" {
  for_each = local.azs_set

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = local.azs_set

  subnet_id = aws_subnet.private[each.key].id
  route_table_id = var.enable_nat_gateway ? (
    aws_route_table.private[var.single_nat_gateway ? local.azs[0] : each.key].id
  ) : aws_route_table.private_no_nat[0].id
}

resource "aws_route_table_association" "database" {
  for_each = local.azs_set

  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database[each.key].id
}

#--------------------------------------------------------------
# VPC Flow Logs
#--------------------------------------------------------------
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = aws_cloudwatch_log_group.flow_logs[0].arn
      }
    ]
  })
}
