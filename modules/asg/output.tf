output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.main.id
}

output "bastion_public_ip" {
  description = "Public IP of bastion host — use this to SSH in"
  value       = aws_instance.bastion.public_ip
}

output "ec2_instance_profile_arn" {
  description = "ARN of EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}
