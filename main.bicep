targetScope = 'subscription'

param resourceGroupName string = ''

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Enter the AD group name for Sql Admin Login')
param ADGroupAdmin string 
@description('sid of the AD group name for Sql Admin Login')
param sid string 
@description('tenant id')
param tenantId string 

param storageAccountName string = ''
param storageResourceGroupName string = ''
param storageResourceGroupLocation string = location
param storageSkuName string = 'Standard_LRS' // Set in main.parameters.json
param storageContainerName string = 'content'
param appServicePlanName string = ''
param sqlResourceGroupName string = ''
param sqlname string = ''
param dbServerName string = ''
param searchServiceResourceGroupName string = ''
param speechServiceResourceGroupName string = ''
param searchServiceName string = ''
param speechServiceName string = ''
param searchServiceLocation string = ''

param openAiResourceGroupName string = ''
param openAiServiceName string = ''
param openAiResourceGroupLocation string
param openAiSkuName string = 'S0'
param chatGptDeploymentName string // Set in main.parameters.json
param chatGptModelName string = (openAiHost == 'azure') ? 'gpt-3.5-turbo' : 'gpt-35-turbo'
param chatGptModelVersion string = '0613'
param chatGptDeploymentCapacity int = 30
param embeddingDeploymentName string // Set in main.parameters.json
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingDeploymentCapacity int = 30
param useGPT4V bool = true
param gpt4vDeploymentName string = 'gpt-4v'
param gpt4vModelName string = 'gpt-4'
param gpt4vModelVersion string = 'vision-preview'
param chatGpt4vDeploymentCapacity int = 10


@allowed([ 'azure', 'openai' ])
param openAiHost string // Set in main.parameters.json

// The free tier does not support managed identity (required) or semantic search (optional)
@allowed([ 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2' ])
param searchServiceSkuName string // Set in main.parameters.json

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

param sku object = {
  name: 'S0'
}

param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules) ? {
  defaultAction: 'Allow'
} : {
  ipRules: allowedIpRules
  defaultAction: 'Deny'
}

var defaultOpenAiDeployments = [
  {
    name: chatGptDeploymentName
    properties: {
      model: {
        format: 'OpenAI'
        name: chatGptModelName
        version: chatGptModelVersion
      }
      raiPolicyName: null
    }
    sku: {
      name: 'Standard'
      capacity: chatGptDeploymentCapacity
    }
  }
  {
    name: embeddingDeploymentName
    properties: {
      model: {
        format: 'OpenAI'
        name: embeddingModelName
        version: '2'
      }
      raiPolicyName: null
    }
    sku: {
      name: 'Standard'
      capacity: embeddingDeploymentCapacity
    }
  }
]

var openAiDeployments = concat(defaultOpenAiDeployments, useGPT4V ? [
  {
    name: gpt4vDeploymentName
    properties: {
      model: {
        format: 'OpenAI'
        name: gpt4vModelName
        version: gpt4vModelVersion
      }
      raiPolicyName: null
    }
    sku: {
      name: 'Standard'
      capacity: chatGpt4vDeploymentCapacity
    }
  }
] : [])


// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(storageResourceGroupName)) {
  name: !empty(storageResourceGroupName) ? storageResourceGroupName : resourceGroup.name
}


resource sqlResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(sqlResourceGroupName)) {
  name: !empty(sqlResourceGroupName) ? sqlResourceGroupName : resourceGroup.name
}


resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(searchServiceResourceGroupName)) {
  name: !empty(searchServiceResourceGroupName) ? searchServiceResourceGroupName : resourceGroup.name
}

resource speechServiceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(speechServiceResourceGroupName)) {
  name: !empty(speechServiceResourceGroupName) ? speechServiceResourceGroupName : resourceGroup.name
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}


module storage 'storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    sku: {
      name: 'B1'
      capacity: 1
    }
    kind: 'linux'
  }
}


module sqlserver 'sql/sql.bicep' = {
  scope: sqlResourceGroup
  name: 'sqlserverdeployment'
  params: {
    dbServerName: !empty(sqlname) ? sqlname : '${abbrs.sqlname}${resourceToken}'
    sqlDbName: !empty(dbServerName) ? dbServerName : '${abbrs.dbServerName}${resourceToken}'
    location: location
    ADGroupAdmin: ADGroupAdmin
    sid: sid
    tenantId: tenantId
  }
}

module searchService 'search/search-services.bicep' = {
  name: 'search-service'
  scope: searchServiceResourceGroup
  params: {
    name: !empty(searchServiceName) ? searchServiceName : 'gptkb-${resourceToken}'
    location: !empty(searchServiceLocation) ? searchServiceLocation : location
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}

module speechServiceModule 'speech/speech-service.bicep' = {
  name: 'speechServiceModule'
  scope: speechServiceResourceGroup
  params: {
    name: !empty(speechServiceName) ? speechServiceName : 'gptkb-${resourceToken}'
    location: location
    publicNetworkAccess: 'Enabled'
    sku: sku
    networkAcls: networkAcls
  }
}

module openAi 'ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    sku: {
      name: openAiSkuName
    }
    deployments: openAiDeployments
  }
}


// Debugging output
output debugInfo object = {
  environmentName: environmentName
  location: location
  openAiDeployments: openAiDeployments
}


output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = storageResourceGroup.name
