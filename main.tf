provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name       = var.vpc_name,
    Envronment = "Terraform"
    Terraform  = "true"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_vpc" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.vpc.id

  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value - 1]

  tags = {
    Name      = each.key
    Terraform = "true"
  }

}

resource "aws_subnet" "public_subnets" {
  for_each          = var.public_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value - 1]

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route = {
    cidr_block  = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name      = "terraform_public_route_table"
    Terraform = "true"
  }

}

resource "aws_route_table_association" "public_rt_associaton" {
    depends_on = [ aws_subnet.private_subnets ]

    route_table_id = aws_route_table.public_rt.id

    for_each = var.public_subnets
    subnet_id = each.value.id
}

resource "aws_internet_gateway" "internet_gateway" {
  
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name      = "terraform_internet_gateway"
    Terraform = "true"
  }
}


resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.internet_gateway ]

  tags = {
    Name      = "terraform_nat_gateway_eip"
    Terraform = "true"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  depends_on = [ aws_internet_gateway.internet_gateway ]

  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = aws_subnet.public_subnets[0].id

    tags = {
        Name      = "terraform_nat_gateway"
        Terraform = "true"
    }
}
