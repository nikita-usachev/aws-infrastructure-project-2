output "ssh_command" {
  value = "ssh -i ${var.key_path_public != null ? var.key_path_public : module.app-server.ansible.vars.ansible_ssh_private_key_file} ${var.username}@${var.dns_enabled ? "app-server.${var.dns_zone}" : element(module.app-server.instance_endpoint, 0)}"
}

output "rds_endpoints" {
  value = length(var.db_instances) < 1 ? null : var.dns_enabled ? {
    for i, db in var.db_instances : module.postgres[db.name].name => (db.dns_prefix != null ? "postgres://${db.dns_prefix}.${var.dns_zone}:5432" : "postgres://${module.postgres[db.name].name}-postgres.${var.dns_zone}:5432")
    } : {
    for i, db in var.db_instances : module.postgres[db.name].name => "postgres://${module.postgres[db.name].endpoint}"
  }
}

output "mongodb_endpoints" {
  value = length(var.docdb_clusters) < 1 ? null : var.dns_enabled ? {
    for i, db in var.docdb_clusters : module.docdb[db.name].id => (db.dns_prefix != null ? "mongodb://${db.dns_prefix}.${var.dns_zone}:27017" : "mongodb://${module.docdb[db.name].id}-mongodb.${var.dns_zone}:27017")
    } : {
    for i, db in var.docdb_clusters : module.docdb[db.name].id => "mongodb://${module.docdb[db.name].endpoint}:27017"
  }
}

output "elasticache_endpoints" {
  value = length(var.redis_clusters) < 1 ? null : var.dns_enabled ? {
    for i, db in var.redis_clusters : module.redis[db.name].primary_endpoint => (db.dns_prefix != null ? "redis://${db.dns_prefix}.${var.dns_zone}:6379" : "redis://${module.redis[db.name].id}-cache.${var.dns_zone}:6379")
    } : {
    for i, db in var.redis_clusters : module.redis[db.name].id => "redis://${module.redis[db.name].primary_endpoint}:6379"
  }
}

output "smb_share" {
  value = "net use Z: \\\\${var.dns_enabled ? "storage-gateway-server.${var.dns_zone}" : module.app-server.instance_endpoint[0]}\\${module.storage-gateway.share} /user:${module.storage-gateway.id}\\smbguest"
}
