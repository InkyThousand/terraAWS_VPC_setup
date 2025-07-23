# IAM Role for Web App instances
resource "aws_iam_role" "web_app_role" {
  name = "${var.environment}-web-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-web-app-role"
    Environment = var.environment
  }
}

# IAM Policy for Web App instances to access S3
resource "aws_iam_policy" "web_app_s3_access" {
  name        = "${var.environment}-web-app-s3-access"
  description = "Allow Web App instances to access S3 image bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectAttributes",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.image_storage.arn,
          "${aws_s3_bucket.image_storage.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for Web App instances to access DynamoDB
resource "aws_iam_policy" "web_app_dynamodb_access" {
  name        = "${var.environment}-web-app-dynamodb-access"
  description = "Allow Web App instances to access DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:DescribeTable"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.image_analysis.arn
      }
    ]
  })
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "web_app_s3_access" {
  role       = aws_iam_role.web_app_role.name
  policy_arn = aws_iam_policy.web_app_s3_access.arn
}

# Attach DynamoDB policy to role
resource "aws_iam_role_policy_attachment" "web_app_dynamodb_access" {
  role       = aws_iam_role.web_app_role.name
  policy_arn = aws_iam_policy.web_app_dynamodb_access.arn
}

# Instance profile for Web App instances
resource "aws_iam_instance_profile" "web_app_profile" {
  name = "${var.environment}-web-app-profile"
  role = aws_iam_role.web_app_role.name
}
