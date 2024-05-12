terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"      
    }
  }
}

provider "aws" {
  region = var.region
}

# LifeCycleHook for AutoScalingGroup (NodeGroup)
## Ec2Ins LcHook is for ENI Attach Lambda Call
resource "aws_autoscaling_lifecycle_hook" "LchookEc2InsNg1" {
  name                   = "${var.instance}-LchookEc2InsNg1"
  autoscaling_group_name = var.autoscaling_group_name
  default_result         = "ABANDON"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
}

resource "aws_autoscaling_lifecycle_hook" "LchookEc2TermNg1" {
  name                   = "${var.instance}-LchookEc2TermNg1"
  autoscaling_group_name = var.autoscaling_group_name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}

resource "aws_iam_role" "RoleLambdaAttach2ndEni" {
  name = "${var.instance}-RoleLambdaAttach2ndEni"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "PolicyLambdaAttach2ndEni" {
  name = "${var.instance}-PolicyLambdaAttach2ndEni"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeInstances",
                "ec2:DetachNetworkInterface",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:DescribeSubnets",
                "autoscaling:CompleteLifecycleAction",
                "ec2:DeleteTags",
                "ec2:DescribeNetworkInterfaces",
                "ec2:ModifyInstanceAttribute",
                "ec2:CreateTags",
                "ec2:DeleteNetworkInterface",
                "ec2:AttachNetworkInterface",
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:TerminateInstances"            
        ]
        Effect   = "Allow"
        Resource = "*"
      },{
        Action   = [
                "logs:CreateLogStream",
                "logs:PutLogEvents"          
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },{
        Action   = [
              "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "PolicyLambdaAttach2ndEni" {
  role       = aws_iam_role.RoleLambdaAttach2ndEni.name
  policy_arn = aws_iam_policy.PolicyLambdaAttach2ndEni.arn
}

resource "aws_lambda_function" "LambdaAttach2ndENI" {
  function_name = "${var.instance}-LambdaAttach2ndENI"
  role          = aws_iam_role.RoleLambdaAttach2ndEni.arn
  handler       = "lambda_function.lambda_handler"
  s3_bucket     = var.attach_2nd_eni_lambda_s3_bucket
  s3_key        = var.attach_2nd_eni_lambda_s3_key
  timeout       = 60

  runtime = "python3.8"

  environment {
    variables = {
      SubnetIds = var.multus_subnets
      SecGroupIds = var.multus_security_group_id
      useStaticIPs = var.use_ips_from_start_of_subnet
      ENITags = var.interface_tags
      SourceDestCheckEnable = var.source_dest_check_enable
    }
  }
}

resource "aws_cloudwatch_event_rule" "NewInstanceEventRule" {
  name        = "${var.instance}-NewInstanceEventRule"

  event_pattern = jsonencode({
    detail-type = [
      "EC2 Instance-launch Lifecycle Action",
      "EC2 Instance-terminate Lifecycle Action"
    ]
    detail = {
        AutoScalingGroupName: ["${var.autoscaling_group_name}"]
    }
    source = [
        "aws.autoscaling"
    ]
  })
}

resource "aws_cloudwatch_event_target" "NewInstanceEvent" {
  rule      = aws_cloudwatch_event_rule.NewInstanceEventRule.name
  arn       = aws_lambda_function.LambdaAttach2ndENI.arn
}


resource "aws_lambda_permission" "PermissionForEventsToInvokeLambda" {
  statement_id  = "${var.instance}-permission-to-invoke-lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.LambdaAttach2ndENI.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.NewInstanceEventRule.arn
}

data "archive_file" "lambda_function_file" {
  type = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "asg_instances_auto_restart" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = "${var.instance}-asg_instances_auto_restart"
  handler          = "lambda_function.handler"
  runtime          = "python3.8"
  role             = aws_iam_role.RoleLambdaAttach2ndEni.arn
  source_code_hash = data.archive_file.lambda_function_file.output_base64sha256
 
}

resource "aws_lambda_invocation" "restart_asg_instances" {
  function_name = aws_lambda_function.asg_instances_auto_restart.function_name

  input = jsonencode({
     "AsgName": "${var.autoscaling_group_name}"
  })

  depends_on = [
    aws_lambda_function.LambdaAttach2ndENI
  ]  
}