# Security Groups

# Create Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "BastionSecurityGroup"
  description = "Security group for Bastion host - Restrict SSH access to specified IP"
  vpc_id      = aws_vpc.myVPC.id  

  tags = {
    Name        = "BastionSecurityGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_specified_ip" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "SSH access from specified IP"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Get the latest Amazon Linux 2023 AMI ID with SSM Parameter 
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# Generate a new private key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-${var.environment}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key to a file (be careful with this in production)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh-key-${var.environment}.pem"
  file_permission = "0600"
}

# Launch a Bastion EC2 instance in the public subnet
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.publicSubnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y
        
    # 1. Disabling root login via SSH by setting PermitRootLogin to 'no'
    # 2. Disabling password authentication by setting PasswordAuthentication to 'no' (forcing key-based auth only)
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd # 3. Restarting the SSH daemon to apply these changes
  EOF

  tags = {
    Name        = "Bastion-${var.environment}"
    Environment = var.environment
    Terraform   = "true"
    OS = "Linux"
  }
}