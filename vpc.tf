terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "5.12.0"
      }
    }
  }
  
  provider "aws" {
    region = "us-east-1"
  }


resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"

  tags = {
    Name = "vpc-demo"
  }
}

resource "aws_subnet" "pub" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "public-sub"
  }
}

resource "aws_subnet" "priv" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.2.0/24"

  tags = {
    Name = "private-sub"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw1"
  }
}

-- resource "aws_internet_gateway_attachment" "main" {
--   internet_gateway_id = aws_internet_gateway.gw.id
--   vpc_id              = aws_vpc.main.id
-- }

resource "aws_route_table" "pubrt" {    
    vpc_id = aws_vpc.main.id
  
    

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }
  
  
    tags = {
      Name = "public-rt"
    }
  }

 
  resource "aws_route_table_association" "pubass" {
    subnet_id      = aws_subnet.pub.id
    route_table_id = aws_route_table.pubrt.id
  }


  
resource "aws_eip" "elastic" {
    vpc = true # If using a VPC
  }

  resource "aws_nat_gateway" "ng" {
    subnet_id     = aws_subnet.pub.id
  
    tags = {
      Name = "NAT1"
    }
  }





  resource "aws_route_table" "prirt" {
    vpc_id = aws_vpc.main.id
  
    
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.ng.id
    }
  
    tags = {
      Name = "private-rt"
    }
  }

  resource "aws_route_table_association" "priass" {
    subnet_id      = aws_subnet.priv.id
    route_table_id = aws_route_table.prirt.id
  }

