# EFS File System
resource "aws_efs_file_system" "wordpress_efs" {
  creation_token = "wordpress-efs-${var.environment}"
  
  tags = {
    Name        = "WordPress-EFS-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# EFS Mount Targets
# This resource creates EFS mount targets for the WordPress EFS file system
# It creates one mount target for each private subnet in the VPC
resource "aws_efs_mount_target" "wordpress_efs_mt" {
  count           = length(aws_subnet.private_subnet) # Determines number of mount targets based on number of private subnets
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_subnet.private_subnet[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# EFS Security Group
resource "aws_security_group" "efs_sg" {
  name_prefix = "efs-sg-${var.environment}-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "EFS-SG-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}