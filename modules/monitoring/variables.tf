variable "env_prefix"{
  type = string
  description = "ENVIRONMENT PREFIX"
}

variable "asg_name" {
  type        = string
  description = "The name of the ASG to monitor"
}