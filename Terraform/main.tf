### vpc creation 

resource "aws_vpc" "dev_vpc" {
  cidr_block       =  var.dev-vpc-cidr ## Hosts/Net total ip's: 65534
  instance_tenancy = "default"

  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "dev_1apub_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = var.dev-1apub-subnet-cidr  ## total ip's 254 
  availability_zone = "ap-south-1a"

  tags = {
    Name = "dev-1apub-subnet"
  }
}

resource "aws_subnet" "dev_1bpub_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = var.dev-1bpub-subnet-cidr   
  availability_zone = "ap-south-1b"

  tags = {
    Name = "dev-1bpub-subnet"
  }
}

resource "aws_subnet" "dev_1apvt_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = var.dev-1apvt-subnet-cidr   ## total ip's 254 
  availability_zone = "ap-south-1a"

  tags = {
    Name = "dev-1apvt-subnet"
  }
}

resource "aws_subnet" "dev_1bpvt_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = var.dev-1bpvt-subnet-cidr   ## total ip's 254 
  availability_zone = "ap-south-1b"

  tags = {
    Name = "dev-1bpvt-subnet"
  }
}

resource "aws_internet_gateway" "igw_public_subnet" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "igw_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_public_subnet.id
  }

  tags = {
    Name = "igw_route_table"
  }
}

resource "aws_route_table_association" "pub_subnet_association_1" {
  subnet_id      = aws_subnet.dev_1apub_subnet.id
  route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_route_table_association" "pub_subnet_association_2" {
  subnet_id      = aws_subnet.dev_1bpub_subnet.id
  route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_nat_gateway" "nat_pvt_subnet" {
  connectivity_type                  = "public"
  subnet_id                          = aws_subnet.dev_1apub_subnet.id
    tags = {
    Name = "nat"
  }
}

resource "aws_route_table" "nat_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_pvt_subnet.id
  }

  tags = {
    Name = "nat_route_table"
  }
}

resource "aws_route_table_association" "pvt_subnet_association_1" {
  subnet_id      = aws_subnet.dev_1apvt_subnet.id
  route_table_id = aws_route_table.nat_route_table.id
}

resource "aws_route_table_association" "pvt_subnet_association_2" {
  subnet_id      = aws_subnet.dev_1bpvt_subnet.id
  route_table_id = aws_route_table.nat_route_table.id
}


### eks role creation 

# Create the IAM Role for EKS
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach Policies to IAM Role
resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Security Group for EKS
resource "aws_security_group" "eks_sg" {
  name_prefix = "${var.cluster_name}-eks-sg"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EKS Cluster
resource "aws_eks_cluster" "eks" { 
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    security_group_ids = [aws_security_group.eks_sg.id]
    subnet_ids        = [
      aws_subnet.dev_1apvt_subnet.id,
      aws_subnet.dev_1bpvt_subnet.id
    ]
  }
}

data "aws_eks_addon" "eks_addons" {
  for_each     = toset(var.eks_addons)
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = each.value
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach Policies to Node IAM Role
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "container_registry_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Node Group
resource "aws_eks_node_group" "node_group" {
  cluster_name  = aws_eks_cluster.eks.name
  node_group_name = "eks-node-group"
  node_role_arn = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.dev_1apvt_subnet.id,
    aws_subnet.dev_1bpvt_subnet.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }
}

terraform {
  backend "s3" {}
}