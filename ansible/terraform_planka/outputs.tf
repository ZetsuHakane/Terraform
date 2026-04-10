# Organiser les données

output "postgres_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
  description = "FQDN de la BDD PostgreSQL"
}

output "container_app_url" {
  value       = azurerm_container_app.app.latest_revision_fqdn
  description = "URL de l'application Container App"
}