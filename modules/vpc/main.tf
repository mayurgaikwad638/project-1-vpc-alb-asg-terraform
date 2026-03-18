#vpc conf

# --------------vpc------------------ #
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }

}

# ------------internet gateway ------------- #
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-igw" }

}

# ------------ private subnets -------------- #
resource "aws_subnet" "private" {
    count = length(var.private_subnets_cidr)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnets_cidr[count.index]
    availability_zone = var.availability_zones[count.index]

    tags = { Name = "${var.project_name}-private-subnet-${count.index+1}"}
}

# ------------- public subnets --------------- #
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {Name = "${var.project_name}-public-subnet-${count.index+1}"}
}

# ------------Nat gateway ------------------ #
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {Name = "${var.project_name}-nat-eip"}
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id

  tags = {Name = "${var.project_name}-nat-gateway"}
  depends_on = [ aws_internet_gateway.igw ]

}

# -------------- route table public ---------------- #
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {Name = "${var.project_name}-public-rt"}

}

# ----------- Route table private ----------------- #
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {Name = "${var.project_name}-private-rt"}
}

# ------------- route table association -------------- #
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  subnet_id = aws_subnet.public[count.index].id 
  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  subnet_id = aws_subnet.private[count.index].id 
  route_table_id = aws_route_table.private.id

}



