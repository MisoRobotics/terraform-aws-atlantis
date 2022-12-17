variable "redis_backend" {
  description = "If true, use a redis backend instad of BoltDB."
  type        = bool
  default     = false
}

variable "redis_port" {
  description = "Port number to use for Redis."
  type        = number
  default     = 6379
}

variable "redis_node_type" {
  description = "Node type to use for Redis."
  type        = string
  default     = "cache.t4g.micro"
}

module "elasticcache_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "v4.16.2"
  count   = var.redis_backend ? 1 : 0

  name        = "${var.name}-elasticcache"
  vpc_id      = local.vpc_id
  description = "Security group allowing access to ElasticCache."

  ingress_with_source_security_group_id = [{
    from_port                = var.redis_port
    to_port                  = var.redis_port
    rule                     = "redis-tcp",
    protocol                 = "tcp"
    source_security_group_id = module.atlantis_sg.security_group_id
  }]
  tags = local.tags
}

# Configure an ElasticCache replication group.
resource "aws_elasticache_replication_group" "redis" {
  count = var.redis_backend ? 1 : 0

  replication_group_id       = var.name
  description                = "Redis replication group for Atlantis DB backend."
  engine                     = "redis"
  node_type                  = var.redis_node_type
  port                       = var.redis_port
  subnet_group_name          = aws_elasticache_subnet_group.redis[count.index].name
  security_group_ids         = [module.elasticcache_sg[count.index].security_group_id]
  apply_immediately          = true
  auto_minor_version_upgrade = true
  auth_token                 = "c2#Zs9&qkeYSUskH9*WOyPh*f"
  transit_encryption_enabled = true
  maintenance_window         = "tue:03:30-tue:04:30"
  snapshot_window            = "01:00-02:00"
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.atlantis.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  count = var.redis_backend ? 1 : 0

  name       = "${var.name}-redis"
  subnet_ids = local.private_subnet_ids
}
