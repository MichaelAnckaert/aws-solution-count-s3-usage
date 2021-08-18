terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "sinax-test-bucket1"
  acl    = "private"

  tags = {
    Environment = "Dev"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "bucket-usage-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_lambda_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "bucket-usage"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "python3.8"

  tags = {
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_dynamodb_table" "user_table" {
  name           = "Users"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_dynamodb_table" "file_table" {
  name           = "Files"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserId"
  range_key 	 = "FileName"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "FileName"
    type = "S"
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "dynamodb-bucket-usage-policy"
  description = "Allow read and write access to the dynamodb table containing bucket usage statistics"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:**"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

