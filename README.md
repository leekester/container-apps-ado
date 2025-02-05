# Overview
This covers the deployment of self-hosted Azure Devops agents within Azure Container Apps.

# What You'll Need

- An Azure subscription with some credit for deployment of resources
- An Azure Devops organisation

# Benefits

- PAYG consumption for ADO agents. No standing charges
- Container apps have 180,000 vCPU seconds and 360,000 GiB seconds free each month
- Virtual network integration, for communication with private workloads

# Azure Container Registry

Deploy an Azure Container Registry, where the ADO container image will be stored. In this case I'm deploying a publicly-accessible ACR for ease of demonstration, although probably best to use a private endpoint in a corporate environment.

