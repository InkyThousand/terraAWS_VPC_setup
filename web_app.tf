# Launch Template for Web App
resource "aws_launch_template" "web_app_template" {
  name_prefix   = "web-app-template-${var.environment}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion_key.key_name
  
  vpc_security_group_ids = [aws_security_group.web_app_sg.id]
  
  monitoring {
    enabled = true
  }
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
  
  iam_instance_profile {
    name = aws_iam_instance_profile.web_app_profile.name
  }
  
  user_data = base64encode(templatefile(
    "web_app_user_data.sh", {
      S3_BUCKET = aws_s3_bucket.image_storage.id,
      DYNAMODB_TABLE = aws_dynamodb_table.image_analysis.name,
      AWS_REGION = var.aws_region
    }
  ))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "WebApp-ASG-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    }
  }
}

# ALB Target Group for Web App
resource "aws_lb_target_group" "web_app_tg" {
  name     = "web-app-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id
  
  health_check {
    enabled             = true
    interval            = 30
    path                = "/health.html"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }
  
  tags = {
    Name        = "web-app-tg-${var.environment}"
    Environment = var.environment
  }
}

# ALB Listener Rule for Web App
resource "aws_lb_listener_rule" "web_app" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
