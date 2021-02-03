output "docker_image_scope" {
  value = replace("${var.app-name}/${var.environment}:latest", "-", "")
}

output "docker_user" {
  value = azurerm_container_registry.acr.admin_username
}

output "docker_password" {
  value = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "docker_host" {
  value = azurerm_container_registry.acr.login_server
}