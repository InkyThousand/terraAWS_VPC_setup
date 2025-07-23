# S3 Bucket for Image Storage
resource "aws_s3_bucket" "image_storage" {
  bucket = "${var.environment}-${random_string.suffix.result}-images"
  
  tags = {
    Name        = "${var.environment}-image-storage"
    Environment = var.environment
  }
}

# S3 Bucket ACL
resource "aws_s3_bucket_ownership_controls" "image_storage" {
  bucket = aws_s3_bucket.image_storage.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "image_storage" {
  depends_on = [aws_s3_bucket_ownership_controls.image_storage]
  bucket     = aws_s3_bucket.image_storage.id
  acl        = "private"
}

# S3 Bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "image_storage" {
  bucket = aws_s3_bucket.image_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"] # In production, restrict this to your domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "image_storage" {
  bucket                  = aws_s3_bucket.image_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SNS Topic for S3 Event Notifications
resource "aws_sns_topic" "image_processing" {
  name = "${var.environment}-image-processing"
  
  tags = {
    Name        = "${var.environment}-image-processing"
    Environment = var.environment
  }
}

# SNS Topic Policy to allow S3 to publish messages
resource "aws_sns_topic_policy" "image_processing" {
  arn    = aws_sns_topic.image_processing.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.image_processing.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.image_storage.arn
          }
        }
      }
    ]
  })
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_image_processing" {
  name = "${var.environment}-lambda-image-processing"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to access S3, SNS, Rekognition, and DynamoDB
resource "aws_iam_policy" "lambda_image_processing" {
  name        = "${var.environment}-lambda-image-processing"
  description = "IAM policy for image processing Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObjectAttributes",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_storage.arn}/*"
      },
      {
        Action = [
          "sns:Publish",
          "sns:Subscribe"
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.image_processing.arn
      },
      {
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectModerationLabels",
          "rekognition:DetectFaces"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.image_analysis.arn
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_image_processing" {
  role       = aws_iam_role.lambda_image_processing.name
  policy_arn = aws_iam_policy.lambda_image_processing.arn
}

# Lambda Function for Image Processing
resource "aws_lambda_function" "image_processing" {
  function_name = "${var.environment}-image-processing"
  role          = aws_iam_role.lambda_image_processing.arn
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  timeout       = 30
  memory_size   = 256

  filename         = "${path.module}/lambda/media_processing.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/media_processing.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN  = aws_sns_topic.image_processing.arn
      S3_BUCKET      = aws_s3_bucket.image_storage.id
      DYNAMODB_TABLE = aws_dynamodb_table.image_analysis.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_image_processing
  ]

  tags = {
    Name        = "${var.environment}-image-processing"
    Environment = var.environment
  }
}

# S3 Event Notification to SNS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_storage.id

  topic {
    topic_arn     = aws_sns_topic.image_processing.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }

  topic {
    topic_arn     = aws_sns_topic.image_processing.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".png"
  }

  topic {
    topic_arn     = aws_sns_topic.image_processing.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpeg"
  }
  
  depends_on = [
    aws_sns_topic_policy.image_processing
  ]
}

# SNS Subscription for Lambda
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.image_processing.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.image_processing.arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "sns_trigger" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processing.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.image_processing.arn
}
