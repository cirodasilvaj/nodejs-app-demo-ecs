data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # AWS ALB & Target Group names have a strict 32 character limit
  resource_prefix = substr(var.app_name, 0, 18)
}

# ==============================================================================
# Networking: Dedicated VPC, Internet Gateway, Subnets, and Routing
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# Container Registry (Amazon ECR)
# ==============================================================================
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.app_name
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 15 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 15
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==============================================================================
# IAM Roles & Execution Permissions
# ==============================================================================
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.app_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ==============================================================================
# CloudWatch Logs
# ==============================================================================
resource "aws_cloudwatch_log_group" "dev" {
  name              = "/ecs/${var.app_name}-dev"
  retention_in_days = 7

  tags = {
    Environment = "dev"
  }
}

resource "aws_cloudwatch_log_group" "stage" {
  name              = "/ecs/${var.app_name}-stage"
  retention_in_days = 7

  tags = {
    Environment = "stage"
  }
}

# ==============================================================================
# ECS Clusters (Dev & Stage)
# ==============================================================================
resource "aws_ecs_cluster" "dev" {
  name = "${var.app_name}-dev"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_ecs_cluster" "stage" {
  name = "${var.app_name}-stage"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = "stage"
  }
}

# ==============================================================================
# Security Groups
# ==============================================================================
# Dev Security Groups
resource "aws_security_group" "dev_alb" {
  name        = "${var.app_name}-dev-alb-sg"
  description = "Allow inbound HTTP to Dev ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_security_group" "dev_ecs" {
  name        = "${var.app_name}-dev-ecs-sg"
  description = "Allow inbound traffic from Dev ALB to Dev ECS Tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from Dev ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.dev_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "dev"
  }
}

# Stage Security Groups
resource "aws_security_group" "stage_alb" {
  name        = "${var.app_name}-stage-alb-sg"
  description = "Allow inbound HTTP to Stage ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "stage"
  }
}

resource "aws_security_group" "stage_ecs" {
  name        = "${var.app_name}-stage-ecs-sg"
  description = "Allow inbound traffic from Stage ALB to Stage ECS Tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from Stage ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.stage_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "stage"
  }
}

# ==============================================================================
# Application Load Balancers, Target Groups & Listeners
# ==============================================================================
# Dev ALB
resource "aws_lb" "dev" {
  name               = "${local.resource_prefix}-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dev_alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "dev" {
  name        = "${local.resource_prefix}-dev-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_listener" "dev" {
  load_balancer_arn = aws_lb.dev.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev.arn
  }
}

# Stage ALB
resource "aws_lb" "stage" {
  name               = "${local.resource_prefix}-stage-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.stage_alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Environment = "stage"
  }
}

resource "aws_lb_target_group" "stage" {
  name        = "${local.resource_prefix}-stage-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Environment = "stage"
  }
}

resource "aws_lb_listener" "stage" {
  load_balancer_arn = aws_lb.stage.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage.arn
  }
}

# ==============================================================================
# ECS Task Definitions
# ==============================================================================
# Dev Task Definition
resource "aws_ecs_task_definition" "dev" {
  family                   = "${var.app_name}-dev"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "NODE_ENV"
          value = "development"
        },
        {
          name  = "APP_NAME"
          value = "${var.app_name}-dev"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dev.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = "dev"
  }
}

# Stage Task Definition
resource "aws_ecs_task_definition" "stage" {
  family                   = "${var.app_name}-stage"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "NODE_ENV"
          value = "staging"
        },
        {
          name  = "APP_NAME"
          value = "${var.app_name}-stage"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.stage.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = "stage"
  }
}

# ==============================================================================
# ECS Services
# ==============================================================================
# Dev ECS Service
resource "aws_ecs_service" "dev" {
  name            = "${var.app_name}-dev-svc"
  cluster         = aws_ecs_cluster.dev.id
  task_definition = aws_ecs_task_definition.dev.arn
  launch_type     = "FARGATE"
  desired_count   = var.dev_desired_count

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.dev_ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dev.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.dev]

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Environment = "dev"
  }
}

# Stage ECS Service
resource "aws_ecs_service" "stage" {
  name            = "${var.app_name}-stage-svc"
  cluster         = aws_ecs_cluster.stage.id
  task_definition = aws_ecs_task_definition.stage.arn
  launch_type     = "FARGATE"
  desired_count   = var.stage_desired_count

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.stage_ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stage.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.stage]

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Environment = "stage"
  }
}
