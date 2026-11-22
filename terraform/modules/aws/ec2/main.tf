# EC2 Instance
resource "aws_instance" "instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  private_ip                  = var.private_ip
  user_data                   = var.user_data
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_groups
  iam_instance_profile        = var.instance_profile
  monitoring                  = var.monitoring

  # Enforce IMDSv2 for enhanced security (mitigates SSRF credential theft)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Ensure root EBS volume is encrypted at rest
  root_block_device {
    encrypted             = true
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    tags = merge(
      {
        Name = "${var.name}-root"
      },
      var.tags
    )
  }

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
