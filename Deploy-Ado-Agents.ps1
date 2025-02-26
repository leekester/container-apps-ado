# Variables

$variables = Get-Content .\variables.json | ConvertFrom-Json

$seedValue = "adoagent"
$location = "uksouth"
$resourceGroupName = "rg-$seedValue"
$acrName = "cr$seedValue"
$acrSku = "Basic"
$vnetName = "vnet-$seedValue"
$vnetCidr = "10.0.0.0/16"
$subnetName = "snet-$seedValue"
$subnetCidr = "10.0.0.0/24"
$containerAppEnvName = "cae-$seedValue"
$containerAppName = "ca-$seedValue"
$agentImageName = "devops/ado-agent:1.0"
$minReplicas = 1
$maxReplicas = 5

$adoOrganisationUrl = "https://dev.azure.com/maleekie"
$adoAgentPoolName = "ADO_Agents_MI_Authentication"
$adoAgentPoolId = 49 # Look at the agent pool within a browser, and the pool ID is shown in the browser URL
$tenantDomain = "maleekiegmail.onmicrosoft.com"

# $adoPatToken = Read-Host -Prompt 'Please enter PAT for authentication to Azure Devops:' -AsSecureString
# $adoPatTokenPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adoPatToken))
# $adoPatToken = ""

# Create resource group
Write-Host "Creating resource group..." -ForegroundColor Yellow
$resourceGroupCreationResult = az group create --name "rg-$($variables.seedValue)" --location $($variables.location)

# Create a container registry
Write-Host "Creating container registry..." -ForegroundColor Yellow
$containerRegistryCreationResult = az acr create --resource-group "rg-$($variables.seedValue)" --name "cr$($variables.seedValue)" --sku $($variables.acrSku) --admin-enabled true
$crCredentials = az acr credential show --name  "cr$($variables.seedValue)"
$crUserName = ($crCredentials | ConvertFrom-Json).username
$crPassword = ($crCredentials | ConvertFrom-Json).passwords[0].value

# Build the ADO agent container image
Write-Host "Building container image..." -ForegroundColor Yellow

az acr build --registry "cr$($variables.seedValue)" `
  --file Dockerfile . `
  -t $($variables.agentImageName)

# Create a virtual network
Write-Host "Creating virtual network..." -ForegroundColor Yellow
$vnetCreationResult = az network vnet create `
  --resource-group "rg-$($variables.seedValue)" `
  --name $($variables.vnetName) `
  --address-prefix "vnet-$($variables.seedValue)" `
  --subnet-name "snet-$($variables.seedValue)" `
  --subnet-prefix $($variables.subnetCidr)

$subnetId = ($vnetCreationResult | ConvertFrom-Json).newVnet.subnets[0].id

# Delegate subnet for use by container apps
Write-Host "Delegating subnet for use by container apps..." -ForegroundColor Yellow
$subnetDelegationResult = az network vnet subnet update `
  --ids $subnetId `
  --delegations Microsoft.App/environments

# Create a UAMI which will be used to register the agent with the ADO agent pool
$uamiName = "uami_ado_$($variables.adoAgentPoolName.ToLower())"
$uamiCreationResult = az identity create --name "uami_ado_$($variables.adoAgentPoolName.ToLower())" --resource-group "rg-$($variables.seedValue)" --location $($variables.location)

# Create container apps environment
Write-Host "Creating container apps environment..." -ForegroundColor Yellow
$caeCreationResult = az containerapp env create `
  --name "cae-$($variables.seedValue)" `
  --resource-group "rg-$($variables.seedValue)" `
  --location $($variables.location) `
  --infrastructure-subnet-resource-id $subnetId `
  --logs-destination none

# Create container app
$caCreationResult = az containerapp create `
  --name "ca-$($variables.seedValue)" `
  --resource-group "rg-$($variables.seedValue)" `
  --environment "cae-$($variables.seedValue)" `
  --image "cr$($variables.seedValue).azurecr.io`/$($variables.agentImageName)" `
  --registry-server "$acrName.azurecr.io" `
  --registry-username $crUserName `
  --registry-password $crPassword `
  --env-vars AZP_URL=$($variables.adoOrganisationUrl) AZP_POOL=$($variables.adoAgentPoolName) AZP_TOKEN=$adoPatTokenPlainText `
  --scale-rule-name ado-scaler `
  --scale-rule-type azure-pipelines `
  --scale-rule-metadata "activationTargetPipelinesQueueLength=2" `
                        "organizationURLFromEnv=AZP_URL" `
                        "personalAccessTokenFromEnv=AZP_TOKEN" `
                        "poolID=$adoAgentPoolId" `
                        "poolName=$adoAgentPoolName" `
                        "targetPipelinesQueueLength=2" `
  --min-replicas $minReplicas `
  --max-replicas $maxReplicas