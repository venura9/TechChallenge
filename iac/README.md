## Prerequisites

- Terraform
- Azure (App Services)
- Docker
- GitHub/GitHub Actions

> Note: Remote/Terraform Cloud was used as the backend for testing

## Architecture Overview

- The application is run on Azure App Service Web App for Containers. 
- The image for the deployment is pulled from an Azure Container Registry upon triggering the CI/CD webhook. 
- ACR calls the webhook when there’s a new push on the configured scope.
- Container connects to the pgsql database via Azure Service Endpoints. 

> ### Possible Next Steps:
> -	Implement a Web Application Firewall (Native or 3rd party as required). 
> -- AppGW + WAF + WAF Rules
> -	Add Network Security Groups and if required UDRs (Azure Route Tables)
> -	Private Endpoints (If it’s a requirement)
> -	Azure monitor setup.
> -	Blue/Green deployment with app service slots + auto swap.
> - Terraform improvements 
> -- Modularise for reusability
> -- Remove hardcoded values from the source code and bloat the variables section.
> - Use https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret for secrets

```
                                    +-------------------------------------------------------------------------------------+
                                    |                                                                                     |
                                    |                                                                                     |
                                    |                                                                                     |
                                    |                                                                                     |
                                    |                                                                                     |
                                    |                                   +-------------+                                   |
                                    |                                   |             |                                   |
                                    |                                   |     User    |                                   |
                                    |                                   |             |                                   |
                                    |                                   +------+------+                                   |
                                    |                                          |                                          |
                                    |                                          |                                          |
                                    |                                          |  HTTPS                                   |
                                    |                                          |                                          |
                                    |                                          |                                          |
                                    |                                          v                                          |
                                    |                                                                                     |
                                    |    +-------------+         +----------------------------+                           |
+---------------+                   |    |             |         | +----------+ +-----------+ |                           |
|               |                   |    |             | Webhook | |          | |           | |                           |
|               |    DOCKER PUSH    |    |             |         | | Instance | | Instance  | |                           |
|  Git-Flow     +----------------------->+     ACR     +-------->+ |          | |           | | Web App For Containers    |
|               |                   |    |             |         | |          | |           | |                           |
|               +<--+               |    |             +<--------+ |          | |           | |                           |
+-----+----+----+   |               |    |             |  DOCKER | +----------+ +-----------+ |                           |
      |    |        | Pull Request  |    +-------------+  PULL   +-------------+--------------+                           |
      |    |        |               |                                          |                                          |
      |    +--------+               |                                          | VNET Integration                         |
      |                             |                                          |                                          |
      |                             |                                          v                                          |
      |                             |                            +----------------------------+                           |
      |                             |                            | +------------------+   VNET|                           |
      |                             |                            | |                  |       |                           |
      |                             |                            | |                  |       |                           |
      |                             |                            | |                  |       |                           |
      |    Terraform/GitHub Actions |                            | |   Integration    |       |                           |
      +---------------------------->+                            | |   Subnet         |       |                           |
                                    |                            | |                  |       |                           |
                                    |                            | +------------------+       |                           |
                                    |                            +----------------------------+                           |
                                    |                                           |                                         |
                                    |                                           | Service Endpoint                        |
                                    |                                           |                                         |
                                    |                                           v                                         |
                                    |                            +--------------+-------------+                           |
                                    |                            |                            |                           |
                                    |                            |                            |                           |
                                    |                            |     Azure DB for PgSQL     |                           |
                                    |                            |                            |                           |
                                    |                            |                            |                           |
                                    |                            |                            |                           |
                                    |                            +----------------------------+                           |
                                    |                                                                                     |
                                    |                                                                                     |
                                    +-------------------------------------------------------------------------------------+
```

## HA & Autoscale

-	Web App for Containers with auto-scaling configured up to 10 instances. 2 instances by default for HA
-	99.95% Uptime SLA (https://azure.microsoft.com/en-us/support/legal/sla/app-service/v1_4/)
-	Azure Database for PgSQL has built-in HA - https://docs.microsoft.com/en-us/azure/postgresql/concepts-high-availability and 99.99% uptime SLA https://azure.microsoft.com/en-us/support/legal/sla/postgresql/v1_1/

## Security

-	SSL/TLS Enforced for transit.
-	Azure DB for PgSQL automatically encrypts data at rest. 
-	db/db.go code was changed to require `sslmode`. 
-	DB communication via Service Endpoints, public access removed.
-	GitHub branch protection rules configured to master.
--	Status check
--	PR approvals
--	Signed commits
-	GitHub actions `environments` used with approver as an additional governance gate for not-technical users.

## Process instructions for provisioning the solution.
- Everything is contained in the `iac` folder
And the github actions workflow does the provisioning for the environment. Workflow is at `.github/workflows/prod_pipeline.yml`
- As long as the environment variables are configured along with the varibles the deployment should be straight forward using terraform. 

> ** Environment variables required for the backend as per: https://www.terraform.io/docs/language/settings/backends/azurerm.html
> - ARM_CLIENT_ID
> - ARM_TENANT_ID
> - ARM_SUBSCRIPTION_ID
> - ARM_CLIENT_SECRET(Sensitive)

> ** Variables required
> - db-user - user for the db connection strings
> - app-name - name for the app
> - app-location - primary azure location
> - environment - prd, dev, etc.
> - db-password (Sensitive) - ****

- `<env>.backend.hcl` needs to be passed at the point of `terraform init` (current source uses `prd` for `<env>`) E.g. `terraform init -backend-config=prd.backend.hcl`

- Using terraform cloud as the secret storage for this instance. 

- For this scenario the github actions workflow `apply` to `prd` from master for ‘push’ and only plans for ‘pull_request’ to `master`
- One time setup needs to be completed by running `./docker.sh` from the `iac` folder. (you will need to init the correct terraform workspace before running this. recommend running it from a bastion host with access to the database. Otherwise a temporary network rule needs to be added to the pgsql db server. )

## Workarounds 

- It was not possible to retrieve the ci/cd webhook link natively though terraform. 
- `null_resource` and `local_file` data source was used as a change that always run. 
- This should be changed overtime when things improve with the ARM control plane.

## Links

- A Successful Deployment Run: https://github.com/venura9/TechChallengeApp/runs/1828083189?check_suite_focus=true
- Deployed app: https://prd-todo-app-webapp.azurewebsites.net (if there's enough credits left - will be taken down on the 10th Feb 2021)
