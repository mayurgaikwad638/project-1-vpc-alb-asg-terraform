output "alb_dns_name" {
  description = "Paste this in your browser to see the app"
  value       = module.alb.alb_dns_name
}

output "bastion_public_ip" {
  description = "SSH into this IP to access bastion"
  value       = module.asg.bastion_public_ip
}

output "app_s3_bucket" {
  description = "S3 bucket storing app files"
  value       = aws_s3_bucket.app.bucket
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.asg.asg_name
}

