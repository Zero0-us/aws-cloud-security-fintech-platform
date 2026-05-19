variable "enable_vpc_peering" {
  description = "Whether to request VPC peering from dev to the Security/Audit VPC."
  type        = bool
  default     = false
}

variable "peer_vpc_id" {
  description = "Security/Audit account VPC ID for optional peering."
  type        = string
  default     = ""
}

variable "peer_owner_id" {
  description = "Security/Audit AWS account ID for optional peering."
  type        = string
  default     = ""
}

variable "peer_vpc_cidr" {
  description = "Security/Audit VPC CIDR for optional peering routes."
  type        = string
  default     = "10.10.0.0/16"
}

locals {
  create_vpc_peering = var.enable_vpc_peering && var.peer_vpc_id != "" && var.peer_owner_id != ""
}

resource "aws_vpc_peering_connection" "dev_to_security" {
  count = local.create_vpc_peering ? 1 : 0

  vpc_id        = aws_vpc.dev.id
  peer_vpc_id   = var.peer_vpc_id
  peer_owner_id = var.peer_owner_id
  peer_region   = var.region

  tags = {
    Name = "fin-dev-to-audit-peering"
  }
}

resource "aws_route" "pri_to_security" {
  count = local.create_vpc_peering ? 1 : 0

  route_table_id            = aws_route_table.pri.id
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_security[0].id
}

resource "aws_route" "pub_to_security" {
  count = local.create_vpc_peering ? 1 : 0

  route_table_id            = aws_route_table.pub.id
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_security[0].id
}
