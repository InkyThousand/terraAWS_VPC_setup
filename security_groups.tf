# Security Group for Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "ALB-SecurityGroup"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.myVPC.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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
    Name        = "ALB-SecurityGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Security Group for WordPress Server
resource "aws_security_group" "wordpress_sg" {
  name        = "WordPress-SecurityGroup"
  description = "Security group for WordPress server in private subnet"
  vpc_id      = aws_vpc.myVPC.id

  # SSH access from Bastion only
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # HTTP access from ALB only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "WordPress-SecurityGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Security Group for RDS Database
resource "aws_security_group" "rds_sg" {
  name        = "RDS-SecurityGroup"
  description = "Security group for RDS MySQL database"
  vpc_id      = aws_vpc.myVPC.id

  # MySQL access from WordPress only
  ingress {
    description     = "MySQL from WordPress"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }

  tags = {
    Name        = "RDS-SecurityGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}
