# general

aws_profile          = "dev"
region               = "us-east-2"
prefix               = "app"
prod_account_id      = "account_id"
dev_account_id       = "account_id"
environment          = "dev"
network_enabled      = true
vpc_cidr             = "172.31.0.0/16"
az_count             = 2
az_count_network     = 2
public_subnet_cidrs  = ["172.31.0.0/24", "172.31.1.0/24", "172.31.2.0/24"]
private_subnet_cidrs = ["172.31.3.0/24", "172.31.4.0/24", "172.31.5.0/24"]
private              = true
private_nat          = true
external_ip_list     = []
external_port_list   = []
key_path_public      = "./id_rsa.pub"
key_path_private     = "./id_rsa"

# backups

backups_enabled = true
backups_schedule = {
  interval      = 24
  interval_unit = "HOURS"
  times         = ["23:45"]
}
backups_retain_count = 7

# dns

dns_enabled       = true
dns_internal_only = true
dns_zone          = "aws.internal"

# instances

ec2_instances = {
  app = {
    count            = 1
    type             = "t2.medium" # "m5.4xlarge"
    disk_size        = 100
    external_ip_list = []
    external_sg_list = []
  }
  storage-gateway = {
    count            = 1
    type             = "m5.xlarge"
    disk_size        = 80
    external_ip_list = []
    external_sg_list = []
  }
}

# storage gateway

storage-gateway = {
  name         = "storage-gateway"
  type         = "FILE_S3"
  smb_password = "password"
}

# mongodb

docdb_clusters = [
  {
    name                = "docdb"
    instance_class      = "db.t3.medium" # "db.t4g.medium"
    instance_count      = 1
    engine_version      = "5.0.0"
    dns_prefix          = "docdb"
    master_username     = "root"
    master_password     = "password"
    backup_retention    = 7
    skip_final_snapshot = true
    deletion_protection = false
    parameters          = []
    security_groups     = []
  }
]

# rds

db_instances = [
  {
    name                  = "db"
    type                  = "postgres"
    engine_version        = 15.3
    dns_prefix            = "postgres"
    instance_class        = "db.t3.small" # "db.t3.xlarge"
    storage_type          = "gp3"
    allocated_storage     = 20
    max_allocated_storage = 1000
    db_name               = "name"
    db_password           = "password"
    db_username           = "postgres"
    parameters            = []
    security_groups       = []
    backup_retention      = 7
    skip_final_snapshot   = false
    ca_cert_identifier    = "rds-ca-rsa2048-g1"
  }
]

# elasticache

redis_clusters = [
  {
    name             = "redis"
    version          = "7.0"
    dns_prefix       = "redis"
    node_type        = "cache.t4g.small"
    security_groups  = []
    cluster_enabled  = false
    multi_az_enabled = false
    num_cache_nodes  = 1
    num_replicas     = 0
    num_shards       = 1
    auth_token       = "password"
    cache_parameters = [
      {
        name  = "tcp-keepalive"
        value = "0"
      },
      {
        name  = "maxmemory-policy"
        value = "volatile-lru"
      },
      {
        name  = "timeout"
        value = "300"
      }
    ]
  }
]

# ses

email_address = "example@gmail.com"
