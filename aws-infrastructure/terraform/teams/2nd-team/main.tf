# provider

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# data

data "aws_availability_zones" "selected" {}

# key

resource "aws_key_pair" "key" {
  key_name   = "${var.prefix}${local.suffix}"
  public_key = file(var.key_path_public)
  lifecycle {
    ignore_changes = [public_key]
  }
}

# network

module "network" {
  source               = "../../modules/network"
  enabled              = var.network_enabled
  region               = var.region
  prefix               = var.prefix
  suffix               = local.suffix
  environment          = local.environment
  vpc_cidr             = var.vpc_cidr
  private_enabled      = var.private
  nat_enabled          = var.private_nat
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count_network)
  tags = {
    Application = "infra"
    Component   = "vpc"
  }
}


# instance

module "app-server" {
  source               = "../../modules/instances"
  instance_count       = lookup(var.ec2_instances.app, "count", 0)
  instance_type        = lookup(var.ec2_instances.app, "type", null)
  instance_disk_size   = lookup(var.ec2_instances.app, "disk_size", null)
  instance_ami_pattern = var.instance_ami_pattern
  instance_ami_owner   = var.instance_ami_owner
  key_name             = aws_key_pair.key.key_name
  key_path             = var.key_path_private
  username             = var.username
  environment          = local.environment
  prefix               = "${var.prefix}-app"
  suffix               = "-server${local.suffix}"
  ansible_groups       = ["all", "app", "app-server"]
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  external_ip_list     = concat(var.external_ip_list, lookup(var.ec2_instances.app, "external_ip_list", []))
  external_sg_list     = lookup(var.ec2_instances.app, "external_sg_list", null)
  vpc_id               = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids           = var.network_enabled ? module.network.private_subnet_ids : null
  elastic_ip_enable    = false
  iam_role_policies    = []
  tags = {
    Application = "app"
    Component   = "app-server"
    Snapshot    = "true"
  }
  # spot
  spot_price = lookup(var.ec2_instances.app, "spot_price", null)
  region     = var.region
  depends_on = [module.network]
}

# storage gateway instance

module "storage-gateway-server" {
  source               = "../../modules/instances"
  instance_count       = lookup(var.ec2_instances.storage-gateway, "count", 0)
  instance_type        = lookup(var.ec2_instances.storage-gateway, "type", null)
  instance_disk_size   = lookup(var.ec2_instances.storage-gateway, "disk_size", null)
  instance_ami_pattern = "aws-storage-gateway-*"
  instance_ami_owner   = ""
  key_name             = aws_key_pair.key.key_name
  key_path             = var.key_path_private
  username             = "ec2-user"
  environment          = local.environment
  prefix               = "${var.prefix}-storage-gateway"
  suffix               = "-server${local.suffix}"
  ansible_groups       = ["all", "storage-gateway"]
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  external_ip_list     = concat(var.external_ip_list, lookup(var.ec2_instances.storage-gateway, "external_ip_list", []))
  external_sg_list     = lookup(var.ec2_instances.storage-gateway, "external_sg_list", null)
  vpc_id               = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids           = var.network_enabled ? module.network.private_subnet_ids : null
  elastic_ip_enable    = false
  iam_role_policies    = []
  data_disk_enable     = true
  data_disk_size       = 150
  tags = {
    Application = "infra"
    Component   = "storage-gateway"
  }
  # spot
  spot_price = lookup(var.ec2_instances.storage-gateway, "spot_price", null)
  region     = var.region
  depends_on = [module.network]
}

# s3

module "storage-gateway-bucket" {
  source      = "../../modules/bucket"
  environment = local.environment
  prefix      = "${var.prefix}-storage-gateway-bucket"
  suffix      = "-smb${local.suffix}"
}

# storage gateway

module "storage-gateway" {
  source             = "../../modules/storage-gateway"
  region             = var.region
  environment        = local.environment
  gateway_ip_address = module.storage-gateway-server.instance_private_ip[0]
  gateway_name       = "${var.prefix}-${var.storage-gateway.name}${local.suffix}"
  gateway_type       = var.storage-gateway.type
  smb_guest_password = var.storage-gateway.smb_password
  bucket_name        = module.storage-gateway-bucket.bucket_id
  bucket_arn         = module.storage-gateway-bucket.bucket_arn
  disk_node          = "/dev/sdh"
  disk_path          = "/dev/sdh"
  vpc_id             = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids         = var.network_enabled ? module.network.private_subnet_ids : null
  tags = {
    Application = "infra"
    Component   = "storage-gateway"
  }
}

# mongodb

module "docdb" {
  source                  = "../../modules/docdb"
  for_each                = { for cluster in var.docdb_clusters : cluster.name => cluster }
  environment             = local.environment
  prefix                  = "${var.prefix}-app"
  suffix                  = "-${each.key}${local.suffix}"
  instance_class          = lookup(each.value, "instance_class", null)
  instance_count          = lookup(each.value, "instance_count", null)
  master_username         = lookup(each.value, "master_username", null)
  master_password         = lookup(each.value, "master_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  security_groups = concat(
    [module.app-server.sg_id],
    lookup(each.value, "security_groups", [])
  )
  backup_retention    = lookup(each.value, "backup_retention", null)
  deletion_protection = lookup(each.value, "deletion_protection", null)
  snapshot_identifier = lookup(each.value, "db_snapshot", null)
  skip_final_snapshot = lookup(each.value, "skip_final_snapshot", null)
  vpc_id              = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids  = var.network_enabled ? module.network.private_subnet_ids : null
  # avail_zones         = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  tags = {
    Application = "app"
    Component   = "mongodb"
  }
  depends_on = [module.network]
}

# rds

module "postgres" {
  source                  = "../../modules/postgres"
  for_each                = { for index, key in var.db_instances : key.name => key if key.type == "postgres" }
  environment             = local.environment
  prefix                  = "${var.prefix}-app"
  suffix                  = "-${each.key}${local.suffix}"
  instance_class          = lookup(each.value, "instance_class", null)
  multi_az                = lookup(each.value, "multi_az", null)
  storage_type            = lookup(each.value, "storage_type", null)
  allocated_storage       = lookup(each.value, "allocated_storage", null)
  max_allocated_storage   = lookup(each.value, "max_allocated_storage", null)
  database_name           = lookup(each.value, "db_name", null)
  database_username       = lookup(each.value, "db_username", null)
  database_password       = lookup(each.value, "db_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  ca_cert_identifier      = lookup(each.value, "ca_cert_identifier", null)
  security_groups = concat(
    [module.app-server.sg_id],
    lookup(each.value, "security_groups", [])
  )
  backup_retention                    = lookup(each.value, "backup_retention", null)
  deletion_protection                 = lookup(each.value, "deletion_protection", null)
  snapshot_identifier                 = lookup(each.value, "db_snapshot", null)
  iam_database_authentication_enabled = lookup(each.value, "iam_database_authentication_enabled", false)
  vpc_id                              = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids                  = var.network_enabled ? module.network.private_subnet_ids : null
  avail_zone                          = data.aws_availability_zones.selected.names[0]
  tags = {
    Application = "app"
    Component   = "postgres"
  }
  depends_on = [module.network]
}

# elasticache

module "redis" {
  source           = "../../modules/redis"
  for_each         = { for cluster in var.redis_clusters : cluster.name => cluster }
  environment      = local.environment
  prefix           = "${var.prefix}-app"
  suffix           = "-${each.key}${local.suffix}"
  engine_version   = lookup(each.value, "version", null)         
  cache_parameters = lookup(each.value, "cache_parameters", null)
  node_type        = lookup(each.value, "node_type", null)       
  cluster_enabled  = lookup(each.value, "cluster_enabled", null) 
  multi_az_enabled = lookup(each.value, "multi_az_enabled", null)
  num_cache_nodes  = lookup(each.value, "num_cache_nodes", null)  
  num_replicas     = lookup(each.value, "num_replicas", null)    
  num_shards       = lookup(each.value, "num_shards", null)     
  auth_token       = lookup(each.value, "auth_token", null)  
  security_groups = concat(
    [module.app-server.sg_id],
    lookup(each.value, "security_groups", [])
  )
  vpc_id             = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids = var.network_enabled ? module.network.private_subnet_ids : null
  tags = {
    Application = "app"
    Component   = "redis"
  }
  depends_on = [module.network]
}

module "dns" {
  source             = "../../modules/dns"
  enabled            = var.dns_enabled
  environment        = local.environment
  dns_zone           = var.dns_zone
  private            = true
  public             = var.dns_internal_only ? false : true
  vpc_id             = var.network_enabled ? module.network.vpc_id : var.vpc_id
  force_destroy      = var.dns_force_destroy
  dns_records_public = []
  dns_records_private = var.dns_create_records_int ? concat(
    length(var.docdb_clusters) > 0 ? [
      for i, db in var.docdb_clusters : {
        name = (db.dns_prefix != null ? db.dns_prefix : "${module.docdb[db.name].id}-mongodb"), cname = module.docdb[db.name].endpoint
      }
    ] : [],
    length(var.db_instances) > 0 ? [
      for i, db in var.db_instances : {
        name = (db.dns_prefix != null ? db.dns_prefix : "${module.postgres[db.name].name}-rds"), cname = module.postgres[db.name].endpoint
      }
    ] : [],
    length(var.redis_clusters) > 0 ? [
      for i, db in var.redis_clusters : {
        name = (db.dns_prefix != null ? db.dns_prefix : "${module.redis[db.name].id}-cache"), cname = module.redis[db.name].primary_endpoint
      }
    ] : [],
    var.ec2_instances.app.count == "0" ? [] : [{ name = "app-server", cname = module.app-server.ansible[0].vars.ansible_host }],
    var.ec2_instances.storage-gateway.count == "0" ? [] : [{ name = "storage-gateway-server", cname = module.storage-gateway-server.ansible[0].vars.ansible_host }]
  ) : []
  tags = {
    Application = "infra"
    Component   = "dns"
  }
  depends_on = [module.network]
}

# simple email service

module "ses" {
  count           = var.email_address != null ? 1 : 0
  source          = "../../modules/ses"
  prefix          = var.prefix
  email_address   = var.email_address
}

# ansible inventory

resource "ansible_group" "all" {
  inventory_group_name = "all"
  vars = {
    cloud_inventory_cloud             = "aws"
    cloud_inventory_region            = var.region
    cloud_inventory_env               = terraform.workspace
    cloud_inventory_ip_whitelist      = join(",", var.external_ip_list)
    cloud_inventory_dns_zone          = !var.dns_enabled ? null : "${terraform.workspace}.${var.dns_zone}"
    cloud_inventory_dns_internal_only = var.dns_internal_only
  }
}

# provisioners

# resource "null_resource" "provision" {
#   triggers = {
#     random_uuid = uuid()
#   }
#   provisioner "local-exec" {
#     command = "wget -O ./terraform.py https://raw.githubusercontent.com/nbering/terraform-inventory/master/terraform.py && chmod +x ./terraform.py"
#   }
# }
