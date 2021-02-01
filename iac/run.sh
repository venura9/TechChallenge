#!/bin/bash
az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az account set --subscription $ARM_SUBSCRIPTION_ID
cicd=$(az webapp deployment container show-cd-url --name $WEB_APP_NAME --resource-group $RG_NAME --query "CI_CD_URL" -o json)
cicd=$(sed -e 's/^"//' -e 's/"$//' <<< $cicd)
echo $cicd |tr -d '\n'> cicd_url
echo $cicd
# az acr webhook create -n 'webhook' -r $acr --uri $ci_cd_url --actions push