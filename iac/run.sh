#!/bin/bash

$webapp = 
$rg = 
$acr = 

cicd=$(az webapp deployment container show-cd-url --name $webapp --resource-group $rg --query "CI_CD_URL" -o json)
cicd=$(sed -e 's/^"//' -e 's/"$//' <<< $cicd)
az acr webhook create -n 'webhook' -r $acr --uri $cicd --actions push






# resource "null_resource" "azure-cli" {
  
#   provisioner "local-exec" {
#     # azure cli script
#     command = "run.sh"

#     # terraform derived values and varialbes as env variables
#     environment {
#       webappname = "${azurerm_app_service.demo.name}"
#       resourceGroup = ${azurerm_resource_group.demo.name}
#     }
#   }

#   depends_on = [ azurerm_app_service.webapp ]
# }

# resource "azurerm_container_registry_webhook" "webhook" {
#   name                = replace("${var.app-name}-webhook", "-", "")
#   resource_group_name = azurerm_resource_group.rg.name
#   registry_name       = azurerm_container_registry.acr.name
#   location            = azurerm_resource_group.rg.location

#   service_uri = "https://mywebhookreceiver.example/mytag"
#   status      = "enabled"
#   scope       = "${var.app-name}:latest"
#   actions     = ["push"]
#   custom_headers = {
#     "Content-Type" = "application/json"
#   }

#   depends_on = [ azurerm_app_service.webapp ]
# }