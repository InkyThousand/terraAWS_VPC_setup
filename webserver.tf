# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "wordpress_template" {
  name_prefix   = "wordpress-template-${var.environment}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion_key.key_name
  
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
  
  user_data = base64encode(templatefile(
    "user_data.sh", {
      DB_NAME = aws_db_instance.wordpress_db.db_name
      DB_USER = aws_db_instance.wordpress_db.username
      DB_PASSWORD = random_password.db_password.result
      DB_HOST = aws_db_instance.wordpress_db.endpoint
    }
  ))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "WordPress-ASG-${var.environment}"
      Environment = var.environment
      Terraform   = "true"
    }
  }
}