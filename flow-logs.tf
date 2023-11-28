######################
#  vpc/flow-logs.tf  #
######################

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count             = var.enable_flow_log ? 1 : 0
  name              = "/vpc/${aws_vpc.vpc.tags.Name}/flow_log"
  retention_in_days = var.flow_log_retention_in_days
}

resource "aws_flow_log" "vpc" {
  count           = var.enable_flow_log ? 1 : 0
  iam_role_arn    = aws_iam_role.vpc_flow_log.0.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.0.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id
}

resource "aws_iam_role" "vpc_flow_log" {
  count              = var.enable_flow_log ? 1 : 0
  name               = "${aws_vpc.vpc.tags.Name}-vpc-flow-log"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_log_trust_policy.json
}

data "aws_iam_policy_document" "vpc_flow_log_trust_policy" {
  statement {

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  count  = var.enable_flow_log ? 1 : 0
  name   = aws_iam_role.vpc_flow_log.0.name
  role   = aws_iam_role.vpc_flow_log.0.name
  policy = data.aws_iam_policy_document.vpc_flow_log.json
}

data "aws_iam_policy_document" "vpc_flow_log" {
  statement {

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = ["*"]
  }
}