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
    var.ec2_instances.gitlab.count == "0" ? [] : [{ name = "gitlab", cname = module.gitlab-server.ansible[0].vars.ansible_host }], [{ name = "name-dev", cname = module.balancer-dev.dns_name }],
    []
  ) : []
  tags = {
    Application = "infra"
    Component   = "dns"
  }
  depends_on = [module.network]
}

module "vpn" {
  source            = "../../modules/vpn"
  count             = var.vpn_enabled ? 1 : 0
  region            = var.region
  environment       = local.environment
  prefix            = var.prefix
  suffix            = "-vpn${local.suffix}"
  vpc_id            = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids        = var.network_enabled ? slice(module.network.public_subnet_ids, 0, var.az_count) : null
  client_cidr_block = var.vpn_client_cidr
  clients           = var.vpn_clients
  tags = {
    Application = "infra"
    Component   = "vpn"
  }
  depends_on = [module.network]
}

# bastion

module "bastion" {
  count                = try(var.ec2_instances.bastion, null) != null ? 1 : 0
  source               = "../../modules/instances"
  instance_count       = lookup(var.ec2_instances.bastion, "count", 0)
  instance_type        = lookup(var.ec2_instances.bastion, "type", null)
  instance_disk_size   = lookup(var.ec2_instances.bastion, "disk_size", null)
  instance_ami_pattern = var.instance_ami_pattern
  instance_ami_owner   = var.instance_ami_owner
  key_name             = aws_key_pair.key.key_name
  key_path             = var.key_path_private
  username             = var.username
  environment          = local.environment
  prefix               = var.prefix
  suffix               = "-bastion${local.suffix}"
  ansible_groups       = ["all", "bastion"]
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  external_ip_list     = var.external_ip_list
  external_port_list   = [22]
  external_sg_list     = []
  vpc_id               = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids           = var.network_enabled ? module.network.public_subnet_ids : null
  elastic_ip_enable    = false
  tags = {
    Application = "infra"
    Component   = "bastion"
  }
  # spot
  spot_price = lookup(var.ec2_instances.bastion, "spot_price", null)
  region     = var.region
  depends_on = [module.network]
}

# gitlab

module "gitlab-server" {
  source               = "../../modules/instances"
  instance_count       = lookup(var.ec2_instances.gitlab, "count", 0)
  instance_type        = lookup(var.ec2_instances.gitlab, "type", null)
  instance_disk_size   = lookup(var.ec2_instances.gitlab, "disk_size", null)
  instance_ami_pattern = var.instance_ami_pattern
  instance_ami_owner   = var.instance_ami_owner
  key_name             = aws_key_pair.key.key_name
  key_path             = var.key_path_private
  username             = var.username
  environment          = local.environment
  prefix               = var.prefix
  suffix               = "-gitlab-server${local.suffix}"
  ansible_groups       = ["all", "gitlab", "gitlab-server"]
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  external_ip_list     = var.external_ip_list
  external_sg_list     = var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : []
  vpc_id               = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids           = var.network_enabled ? module.network.public_subnet_ids : null
  elastic_ip_enable    = false
  iam_role_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
  iam_role_inline_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole",
                "iam:ListRoles"
            ],
            "Resource": "*"
        }
    ]
}
EOF
  tags = {
    Application = "gitlab"
    Component   = "gitlab-server"
    Snapshot    = "true"
  }
  # spot
  spot_price = lookup(var.ec2_instances.gitlab, "spot_price", null)
  region     = var.region
  depends_on = [module.network]
}

module "gitlab-cache" {
  count       = var.gitlab_cache_bucket_enabled ? 1 : 0
  source      = "../../modules/bucket"
  environment = terraform.workspace
  prefix      = var.prefix
  suffix      = "-gitlab-runner-cache"
}

module "backups" {
  source       = "../../modules/dlm"
  count        = var.backups_enabled ? 1 : 0
  environment  = terraform.workspace
  prefix       = var.prefix
  suffix       = "-backups${local.suffix}"
  schedule     = var.backups_schedule
  retain_count = var.backups_retain_count
  tags = {
    Application = "infra"
    Component   = "backups"
  }
}

module "iam" {
  source      = "../../modules/iam"
  environment = terraform.workspace
  prefix      = var.prefix
  suffix      = "-iam${local.suffix}"
  tags = {
    Application = "infra"
    Component   = "IAM"
  }
}


## Redis
module "redis" {
  source      = "../../modules/elasticache"
  environment = terraform.workspace
  prefix      = var.prefix
  suffix      = "-redis${local.suffix}"
  subnet_ids  = var.network_enabled ? module.network.private_subnet_ids : null
  allowed_security_groups = concat(
    var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : [],
    [module.balancer-dev.security_group_id]
  )

  tags = {
    Application = "name"
    Component   = "Redis"
  }
}

module "rds" {
  source            = "../../modules/rds"
  environment       = terraform.workspace
  prefix            = var.prefix
  allocated_storage = var.rds_db_allocated_storage
  postgres_username = var.rds_db_username
  postgres_password = var.rds_db_password
  subnet_ids        = var.network_enabled ? module.network.private_subnet_ids : null
  allowed_security_groups = concat(
    var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : [],
    [module.balancer-dev.security_group_id]
  )

  tags = {
    Application = "name"
    Component   = "RDS"
  }
}

module "ecr-repositories" {
  source      = "../../modules/ecr"
  for_each    = { for repo in var.ecr_repositories : repo.name => repo }
  environment = terraform.workspace
  name        = each.key
  principals_full_access = var.environment == "prod" ? ["account-id"] : [
    module.gitlab-server.role_arn,
    module.iam.iam_gitlab_runner_role_arn
  ]
  principals_readonly_access = []
  tags = {
    Application = "name"
    Component   = "ECR"
  }
}

module "ecs-cluster-dev" {
  source      = "../../modules/ecs-cluster"
  environment = local.environment
  prefix      = var.prefix
  suffix      = "-ecs-dev${local.suffix}"
  tags = {
    Application = "name"
    Component   = "ECS"
  }
  depends_on = [module.network]
}

module "ecs-service" {
  source                 = "../../modules/ecs-service"
  region                 = var.region
  environment            = local.environment
  prefix                 = var.prefix
  suffix                 = local.suffix
  name                   = "app"
  enable_execute_command = true
  vpc_id                 = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids             = var.network_enabled ? module.network.private_subnet_ids : null
  allowed_security_groups = concat(
    var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : [],
    [module.balancer-dev.security_group_id]
  )
  ecs_cluster_id           = module.ecs-cluster-dev.id
  alb_listener_arn         = module.balancer-dev.listener_arn
  alb_healthcheck_path     = "/healthcheck"
  alb_healthcheck_interval = 60
  alb_healthcheck_timeout  = 30
  service_fqdn             = "dev.${var.dns_zone}"
  container_image          = var.environment == "prod" ? "${var.prod_account_id}.dkr.ecr.us-east-2.amazonaws.com/name/service" : "${var.dev_account_id}.dkr.ecr.us-east-2.amazonaws.com/name/service"
  container_port           = 5005
  container_environment = [
    { name : "SERVER", value : "dev.${var.dns_zone}" }
  ]
  tags = {
    Application = "name"
    Component   = "app"
  }
  depends_on = [module.ecs-cluster-dev, module.balancer-dev]
}

module "balancer-dev" {
  source      = "../../modules/balancer"
  environment = var.environment
  prefix      = var.prefix
  suffix      = "-balancer-dev${local.suffix}"
  vpc_id      = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids  = var.network_enabled ? module.network.private_subnet_ids : null
  full_domain = "dev.${var.dns_zone}"
  tags = {
    Application = "name"
    Component   = "balancer"
  }
}

# mongodb

module "docdb" {
  source                  = "../../modules/docdb"
  for_each                = { for cluster in var.docdb_clusters : cluster.name => cluster }
  environment             = local.environment
  prefix                  = var.prefix
  suffix                  = "-docdb-${each.key}${local.suffix}"
  instance_class          = lookup(each.value, "instance_class", null)
  instance_count          = lookup(each.value, "instance_count", null)
  master_username         = lookup(each.value, "master_username", null)
  master_password         = lookup(each.value, "master_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  security_groups         = var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : []
  backup_retention        = lookup(each.value, "backup_retention", null)
  deletion_protection     = lookup(each.value, "deletion_protection", null)
  snapshot_identifier     = lookup(each.value, "db_snapshot", null)
  skip_final_snapshot     = lookup(each.value, "skip_final_snapshot", null)
  vpc_id                  = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids      = var.network_enabled ? module.network.private_subnet_ids : null
  # avail_zones             = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  tags = {
    Application = "name"
    Component   = "mongodb"
  }
  depends_on = [module.network]
}

module "cloudwatch" {
  source                                = "../../modules/cloudwatch"
  one_am_tue_sat                        = var.one_am_tue_sat
  five_am_tue_sat                       = var.five_am_tue_sat
  nine_am_mon_fri                       = var.nine_am_mon_fri
  cluster_arn                           = module.ecs-cluster-dev.arn
  ecs_derivitec_task_definition_arn     = module.ecs-service.derivitec_task_arn
  ecs_margin_report_task_definition_arn = module.ecs-service.margin_report_task_arn
  ecs_flex_option_task_definition_arn   = module.ecs-service.flex_option_task_arn
  ecs_subnets                           = module.network.private_subnet_ids
  allowed_security_groups = concat(
    var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : [],
    [module.balancer-dev.security_group_id]
  )
  task_execution_role_arn = module.ecs-service.task_execution_role_arn
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
