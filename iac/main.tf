terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.00"
    }
  }
  backend "remote" {}
}

#all the varialbles and the environment varialbles are defined in the `remote` backend
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.environment}-${var.app-name}-rg"
  location = var.app-location
}

# Container registry 
resource "azurerm_container_registry" "acr" {
  name                = replace("${var.environment}-${var.app-name}-acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true

}

# application VNET with the integration subbet
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment}-${var.app-name}-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vnet-intgr-subnet" {
  name                 = "integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}


#app service with linux/docker and vnet integration
resource "azurerm_app_service_plan" "asp" {
  name                = "${var.environment}-${var.app-name}-asp"
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
  name                = "${var.environment}-${var.app-name}-webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
  https_only          = true

  site_config {
    app_command_line  = "serve"
    always_on         = true
    linux_fx_version  = replace("DOCKER|${azurerm_container_registry.acr.login_server}/${var.app-name}/${var.environment}:latest", "-", "")
    # linux_fx_version  = replace("DOCKER|servian/techchallengeapp:latest", "-", "")
    health_check_path = "/healthcheck/"
  }

  app_settings = {
    #all traffic goes though the VNET, allows application of NSGs
    "WEBSITE_VNET_ROUTE_ALL" = 1
    #acr
    "DOCKER_REGISTRY_SERVER_URL"      = "https://${azurerm_container_registry.acr.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.acr.admin_password
    #webhook enable
    "DOCKER_ENABLE_CI" = "true"
    #container env variables
    "VTT_DBHOST"     = "${azurerm_postgresql_server.pg_server.name}.postgres.database.azure.com"
    "VTT_DBUSER"     = "${var.db-user}@${azurerm_postgresql_server.pg_server.name}"
    "VTT_DBPASSWORD" = var.db-password
    "VTT_DBNAME"     = azurerm_postgresql_database.pg_db.name
    "VTT_LISTENPORT" = "80"
    "VTT_LISTENHOST" = "0.0.0.0"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "vnet-intgr" {
  app_service_id = azurerm_app_service.webapp.id
  subnet_id      = azurerm_subnet.vnet-intgr-subnet.id
}

# scaling rule when processing hits 70%
# two instances for high avaialbility (Note: There's already 99.95% uptime SLA backing an App Service)
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

# pgsql db server and the database, service endpoint created with the integration subnet 
resource "azurerm_postgresql_server" "pg_server" {
  name                = replace("${var.environment}-${var.app-name}-pgserver", "-", "") # `updatedb` didn't like the dashes in the name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "GP_Gen5_2"
  ssl_minimal_tls_version_enforced  = "TLS1_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = var.db-user
  administrator_login_password = var.db-password
  version                      = "9.6"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "pg_db" {
  name                = replace("${var.app-name}-pgdb", "-", "") # `updatedb` didn't like the dashes in the name
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.pg_server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_virtual_network_rule" "example" {
  name                                 = "postgresql-vnet-rule"
  resource_group_name                  = azurerm_resource_group.rg.name
  server_name                          = azurerm_postgresql_server.pg_server.name
  subnet_id                            = azurerm_subnet.vnet-intgr-subnet.id
  ignore_missing_vnet_service_endpoint = true
}


#get and save the webhook to a file
resource "null_resource" "azure-cli" {

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    #always run this to ensure the url is avaialble when a change happens
    command = "./run.sh"

    environment = {
      WEB_APP_NAME = azurerm_app_service.webapp.name
      RG_NAME      = azurerm_resource_group.rg.name
    }
  }

  depends_on = [azurerm_app_service.webapp]
}

resource "azurerm_container_registry_webhook" "webhook" {
  name                = replace("${var.environment}-${var.app-name}-webhook", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  registry_name       = azurerm_container_registry.acr.name
  location            = azurerm_resource_group.rg.location

  service_uri = data.local_file.cicd_url.content
  status      = "enabled"
  scope       = replace("${var.app-name}/${var.environment}:latest", "-", "")
  actions     = ["push"]

  depends_on = [null_resource.azure-cli]
}

data "local_file" "cicd_url" {
  filename   = "./cicd_url"
  depends_on = [null_resource.azure-cli]
}