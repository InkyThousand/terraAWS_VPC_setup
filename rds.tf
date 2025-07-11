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
