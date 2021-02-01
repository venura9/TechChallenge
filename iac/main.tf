terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.12"
    }
  }
  backend "remote" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.app-name}-rg"
  location = var.app-location
}

resource "azurerm_container_registry" "acr" {
  name                = replace("${var.app-name}-acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.app-name}-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vnet-intgr-subnet" {
  name                 = "integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.app-name}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "${var.app-name}-webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
  https_only          = true

  site_config {
    linux_fx_version  = "DOCKER|nginx:latest"
    health_check_path = "/healthcheck/"
  }

  app_settings = {
    "WEBSITE_VNET_ROUTE_ALL"          = 1
    "DOCKER_REGISTRY_SERVER_URL"      = azurerm_container_registry.acr.login_server
    "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.acr.admin_password
    "DOCKER_ENABLE_CI"                = "true"
    "VTT_DBHOST" = "${azurerm_postgresql_server.pg_server.name}.postgres.database.azure.com"
    "VTT_DBUSER" = "${var.db_user}@\\${azurerm_postgresql_server.pg_server.name}"
    "VTT_DBPASSWORD" = var.db_password
    "VTT_DBNAME" = azurerm_postgresql_database.pg_db.name
  }

}

//scaling rule when processing hits 70%
//two instances for high avaialbility (Note: There's already 99.95% uptime SLA backing an App Service)
resource "azurerm_monitor_autoscale_setting" "cpuscale" {
  name                = "AutoscaleSetting"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_app_service_plan.asp.id

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.asp.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.asp.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 70
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

// vnet integration with the integration subnet
resource "azurerm_app_service_virtual_network_swift_connection" "vnet-intgr" {
  app_service_id = azurerm_app_service.webapp.id
  subnet_id      = azurerm_subnet.vnet-intgr-subnet.id
}


resource "azurerm_postgresql_server" "pg_server" {
  name                = "${var.app-name}-pgserver"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "B_Gen5_1"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = var.db_user
  administrator_login_password = var.db_password
  version                      = "9.6"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "pg_db" {
  name                = "${var.app-name}-pgdb"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.pg_server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}