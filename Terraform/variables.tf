variable "dev-vpc-cidr" {
  description = "vpc cidr range"
  type        = string
}

variable "dev-1apub-subnet-cidr" {
  description = "1a public subunet cidr range"
  type        = string
}

variable "dev-1bpub-subnet-cidr" {
  description = "1b public subunet cidr range"
  type        = string
}

variable "dev-1apvt-subnet-cidr" {
  description = "1a private subunet cidr range"
  type        = string
}

variable "dev-1bpvt-subnet-cidr" {
  description = "1b private subunet cidr range"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks for security group"
  type        = list(string)
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "eks_addons" {
  default = ["kube-proxy", "coredns", "metrics-server", "eks-node-monitoring-agent", "amazon-cloudwatch-observability", "eks-pod-identity-agent"]
}
