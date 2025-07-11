# EFS for shared WordPress files
resource "aws_efs_file_system" "wordpress_efs" {
  creation_token = "wordpress-efs-${var.environment}"
  
  tags = {
    Name        = "WordPress-EFS-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "wordpress_efs_mt1" {
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_subnet.privateSubnet.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "wordpress_efs_mt2" {
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_subnet.privateSubnet2.id
  security_groups = [aws_security_group.efs_sg.id]
}