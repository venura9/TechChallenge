output "docker_host" {
  value = azurerm_container_registry.acr.login_server
}

output "docker_user" {
  value = azurerm_container_registry.acr.admin_username
}

output "docker_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "docker_image_scope" {
  value = replace("${var.app-name}/${var.environment}:latest", "-", "")
}

output "db_host" {
  value = "${azurerm_postgresql_server.pg_server.name}.postgres.database.azure.com"
}

output "db_user" {
  value = "${var.db-user}@${azurerm_postgresql_server.pg_server.name}"
}

output "db_password" {
  value     = var.db-password
  sensitive = true
}

output "db_name" {
  value = azurerm_postgresql_database.pg_db.name
}