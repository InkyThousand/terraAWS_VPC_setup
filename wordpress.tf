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

# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create DB subnet group
resource "aws_db_subnet_group" "wordpress_db_subnet_group" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = [aws_subnet.privateSubnet.id, aws_subnet.privateSubnet2.id]

  tags = {
    Name        = "WordPress DB subnet group"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Create RDS MySQL instance
resource "aws_db_instance" "wordpress_db" {
  identifier             = "wordpress-db-${var.environment}"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  
  db_name  = "wordpress"
  username = "wpuser"
  password = random_password.db_password.result
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.wordpress_db_subnet_group.name
  
  skip_final_snapshot = true
  
  tags = {
    Name        = "WordPress-DB-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Launch WordPress server in private subnet
resource "aws_instance" "wordpress" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.privateSubnet.id
  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  key_name               = aws_key_pair.generated_key.key_name
  
  user_data = templatefile(
        "user_data.sh", {
            DB_NAME = aws_db_instance.wordpress_db.db_name
            DB_USER = aws_db_instance.wordpress_db.username
            DB_PASSWORD = random_password.db_password.result
            DB_HOST = aws_db_instance.wordpress_db.endpoint
        }
  )

  depends_on = [
    aws_db_instance.wordpress_db,
    time_sleep.wait_for_nat_gateway
  ]

  tags = {
    Name        = "WordPress-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
    OS = "Linux"
  }
}

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

# Attach WordPress instance to target group
resource "aws_lb_target_group_attachment" "wordpress_tg_attachment" {
  target_group_arn = aws_lb_target_group.wordpress_tg.arn
  target_id        = aws_instance.wordpress.id
  port             = 80
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