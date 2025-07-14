# Get the latest Amazon Linux 2023 AMI ID with SSM Parameter 
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# Create AWS key pair using the preinstalled public key
resource "aws_key_pair" "bastion_key" {
  key_name   = "terraform-${var.environment}-key"
  public_key = file("${path.module}/${var.bastion_key}")
}

# Launch a Bastion EC2 instance in the public subnet
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.publicSubnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.bastion_key.key_name

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