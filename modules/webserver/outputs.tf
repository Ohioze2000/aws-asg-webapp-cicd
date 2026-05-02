output "asg_name" {
  description = "The name of the Auto Scaling Group managing the web servers."
  value       = aws_autoscaling_group.web_asg.name
}

output "asg_arn" {
  description = "The ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.web_asg.arn
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 security group."
  value       = aws_security_group.ec2-sg.id
}

output "ec2_security_group_name" {
  description = "The name of the EC2 security group."
  value       = aws_security_group.ec2-sg.name
}