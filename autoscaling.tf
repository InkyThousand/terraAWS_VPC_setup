# Auto Scaling Group
resource "aws_autoscaling_group" "web_app_asg" {
  name                = "web-app-asg-${var.environment}"
  vpc_zone_identifier = [aws_subnet.privateSubnet.id, aws_subnet.privateSubnet2.id]
  target_group_arns   = [aws_lb_target_group.web_app_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.web_app_template.id
    version = "$Latest"
  }

  depends_on = [
    time_sleep.wait_for_nat_gateway
  ]

  tag {
    key                 = "Name"
    value               = "WebApp-ASG-${var.environment}"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "web-app-scale-up-${var.environment}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "web-app-scale-down-${var.environment}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.web_app_asg.name
}
