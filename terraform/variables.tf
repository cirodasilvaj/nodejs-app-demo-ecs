variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "us-east-1"
}

variable "app_name" {
  type        = string
  description = "Application and workload name"
  default     = "bkstg-made-nodejs-demo22"
}

variable "container_port" {
  type        = number
  description = "Port exposed by the Node.js application container"
  default     = 8080
}

variable "container_cpu" {
  type        = number
  description = "Fargate CPU units (256 = 0.25 vCPU)"
  default     = 256
}

variable "container_memory" {
  type        = number
  description = "Fargate memory in MiB"
  default     = 512
}

variable "dev_desired_count" {
  type        = number
  description = "Desired number of tasks in dev environment"
  default     = 1
}

variable "stage_desired_count" {
  type        = number
  description = "Desired number of tasks in stage environment"
  default     = 1
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the dedicated VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  type        = string
  description = "CIDR block for public subnet in AZ A"
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type        = string
  description = "CIDR block for public subnet in AZ B"
  default     = "10.0.2.0/24"
}

variable "initial_image" {
  type        = string
  description = "Initial container image placeholder used before CI/CD pushes project build"
  default     = "public.ecr.aws/docker/library/node:20-alpine"
}
