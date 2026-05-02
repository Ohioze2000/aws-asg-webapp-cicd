# 1. SNS Topic remains the same
resource "aws_sns_topic" "cloudwatch_alarms_topic" {
  name         = "${var.env_prefix}-cloudwatch-alarms"
  display_name = "${var.env_prefix} CloudWatch Alarms"

  tags = {
    Name = "${var.env_prefix}-cloudwatch-alarms"
  }
}

# 2. Refactored CloudWatch Alarm: Monitoring the ASG as a whole
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "${var.env_prefix}-ASG-High-CPU-Utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 
  statistic           = "Average"
  threshold           = 80 
  alarm_description   = "Alarm when average CPU utilization across the ASG exceeds 80%"
  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  actions_enabled = true
  alarm_actions   = [aws_sns_topic.cloudwatch_alarms_topic.arn]
  ok_actions      = [aws_sns_topic.cloudwatch_alarms_topic.arn]

  tags = {
    Name = "${var.env_prefix}-ASG-High-CPU-Alarm"
  }
}

# 3. Email subscription remains the same
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn
  protocol  = "email"
  endpoint  = "ohiozeberyl2000@gmail.com" 
}
