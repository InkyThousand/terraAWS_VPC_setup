# Create Application Load Balancer
resource "aws_lb" "web_app_alb" {
  name               = "web-app-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.publicSubnet.id, aws_subnet.publicSubnet2.id]

  tags = {
    Name        = "WebApp-ALB-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create ALB listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
}
