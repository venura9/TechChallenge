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
And the github actions workflow does the provisioning for the environment. `.github/workflows/prod_pipeline.yml` as long as the environment variables are configured along with the varibles.
- The github actions workflow `apply` to prod from master for ‘push’ and only plans for ‘pull_request’
- One time setup needs to be completed by running `./docker.sh` from the `iac` folder. (you will need to init the correct terraform workspace before running this. recommend running it from a bastion host with access to the database. Otherwise a temporary network rule needs to be added to the pgsql db server. )