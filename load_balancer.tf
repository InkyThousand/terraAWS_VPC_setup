# Create Application Load Balancer
resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.publicSubnet.id, aws_subnet.publicSubnet2.id]

  tags = {
    Name        = "WordPress-ALB-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create target group
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health.html"
    matcher             = "200"
  }

  tags = {
    Name        = "WordPress-TG-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create ALB listener
resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}
