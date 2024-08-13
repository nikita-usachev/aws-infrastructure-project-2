output "app-endpoint" {
  value = var.dns_enabled ? "http://dev.${var.dns_zone}" : "http://${module.balancer-dev.dns_name}"
}

output "gitlab-server" {
  value = try(var.ec2_instances.gitlab) == null ? null : var.ec2_instances.gitlab.count == 0 ? null : var.dns_enabled ? "https://gitlab.${var.dns_zone}" : "https://${module.gitlab-server.ansible.0.vars.ansible_host}"
}

output "mongodb_endpoints" {
  value = length(var.docdb_clusters) < 1 ? null : var.dns_enabled ? {
    for i, db in var.docdb_clusters : module.docdb[db.name].id => (db.dns_prefix != null ? "mongodb://${db.dns_prefix}.${var.dns_zone}:27017" : "mongodb://${module.docdb[db.name].id}-mongodb.${var.dns_zone}:27017")
    } : {
    for i, db in var.docdb_clusters : module.docdb[db.name].id => "mongodb://${module.docdb[db.name].endpoint}"
  }
}

output "name_servers" {
  value       = var.dns_enabled && !var.dns_internal_only ? module.dns.name_servers : null
  description = "DNS zone name servers"
}
