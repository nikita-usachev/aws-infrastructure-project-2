# general

aws_profile          = "production"
prod_account_id      = "account-id"
dev_account_id       = "account-id"
region               = "us-east-2"
prefix               = "app"
environment          = "prod"
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

# dns

dns_enabled       = true
dns_internal_only = true
dns_zone          = "aws.internal"

# backups

backups_enabled = true
backups_schedule = {
  interval      = 24
  interval_unit = "HOURS"
  times         = ["23:45"]
}
backups_retain_count = 7

# rds
rds_db_username          = "postgres"
rds_db_password          = "postgres"
rds_db_allocated_storage = 10

# instances

ec2_instances = {
  bastion = {
    count     = 0
    type      = "t2.micro"
    disk_size = 20
  }
  gitlab = {
    count       = 0
    type        = "t3a.large"
    disk_size   = 100
    ami_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  }
}

gitlab_cache_bucket_enabled = false

# mongodb

docdb_clusters = [
  {
    name                = "prod"
    instance_class      = "db.t4g.medium"
    instance_count      = 0
    engine_version      = "5.0.0"
    dns_prefix          = "mongodb-prod"
    master_username     = "root"
    master_password     = "password"
    backup_retention    = 7
    skip_final_snapshot = true
    deletion_protection = false
    parameters          = []
  }
]

ecr_repositories = [
  { name = "app/base" },
  { name = "app/service" },
]

one_am_tue_sat  = "cron(0 5 ? * TUE-SAT *)"
five_am_tue_sat = "cron(0 9 ? * TUE-SAT *)"
nine_am_mon_fri = "cron(0 13 ? * MON-FRI *)"
