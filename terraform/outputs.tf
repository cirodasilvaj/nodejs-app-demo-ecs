output "aws_region" {
  description = "AWS Region deployed to"
  value       = var.aws_region
}

output "ecr_repository_url" {
  description = "URL of the Amazon ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "dev_ecs_cluster_name" {
  description = "Name of the Dev ECS Cluster"
  value       = aws_ecs_cluster.dev.name
}

output "stage_ecs_cluster_name" {
  description = "Name of the Stage ECS Cluster"
  value       = aws_ecs_cluster.stage.name
}

output "dev_ecs_service_name" {
  description = "Name of the Dev ECS Service"
  value       = aws_ecs_service.dev.name
}

output "stage_ecs_service_name" {
  description = "Name of the Stage ECS Service"
  value       = aws_ecs_service.stage.name
}

output "dev_alb_dns_name" {
  description = "DNS endpoint for Dev Application Load Balancer"
  value       = aws_lb.dev.dns_name
}

output "dev_alb_url" {
  description = "HTTP URL to access Dev environment"
  value       = "http://${aws_lb.dev.dns_name}"
}

output "stage_alb_dns_name" {
  description = "DNS endpoint for Stage Application Load Balancer"
  value       = aws_lb.stage.dns_name
}

output "stage_alb_url" {
  description = "HTTP URL to access Stage environment"
  value       = "http://${aws_lb.stage.dns_name}"
}
