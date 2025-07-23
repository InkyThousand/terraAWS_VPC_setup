# DynamoDB table for storing image analysis results
resource "aws_dynamodb_table" "image_analysis" {
  name           = "${var.environment}-image-analysis"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "image_id"
  
  attribute {
    name = "image_id"
    type = "S"
  }
  
  tags = {
    Name        = "${var.environment}-image-analysis"
    Environment = var.environment
  }
}
