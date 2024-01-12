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
param backendServiceName string = ''

param openAiResourceGroupName string = ''
param openAiServiceName string = ''
param communicationServiceName string = ''
param openAiSkuName string = 'S0'
param chatGptDeploymentName string // Set in main.parameters.json
param chatGptModelName string = (openAiHost == 'azure') ? 'gpt-3.5-turbo' : 'gpt-35-turbo'
param chatGptModelVersion string = '0613'
param chatGptDeploymentCapacity int = 30
param embeddingDeploymentName string // Set in main.parameters.json
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingDeploymentCapacity int = 30
param communicationResourceGroupName string = ''
param commlocation string
param formRecognizerResourceGroupName string = ''
param TextAnalyticsResourceGroupName string = ''
param multiserviceResourceGroupName string = ''
param formRecognizerServiceName string = ''
param TextAnalyticsServiceName string = ''
param multiServiceName string = ''
param formRecognizerResourceGroupLocation string = location
param TextAnalyticsResourceGroupLocation string = location
param multiserviceResourceGroupLocation string = location
param formRecognizerSkuName string = 'S0'
param TextAnalyticsSkuName string = 'S'


@description('Location for the OpenAI resource group')
@allowed(['canadaeast', 'eastus', 'eastus2', 'francecentral', 'switzerlandnorth', 'uksouth', 'japaneast', 'northcentralus', 'australiaeast', 'swedencentral'])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiResourceGroupLocation string

// Used for optional CORS support for alternate frontends
param allowedOrigin string = '' // should start with https://, shouldn't end with a /

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

param virtualNetworks_vnet1 string
param subnet string
param networkAcls object= {
  bypass: 'AzureServices'
  virtualNetworkRules: [
    {
      id: '${virtualNetworks_vnet1}/subnets/${subnet}'
      action: 'Allow'
    }
  ]
  ipRules: []
  defaultAction: 'Deny'
}
param networkAclsds object= {
  virtualNetworkRules: [
    {
      id: '${virtualNetworks_vnet1}/subnets/${subnet}'
      action: 'Allow'
    }
  ]
  ipRules: []
  defaultAction: 'Deny'
}

param tenantId string = tenant().tenantId
param authTenantId string = ''

// Used for the optional login and document level access control system
param useAuthentication bool = false


var tenantIdForAuth = !empty(authTenantId) ? authTenantId : tenantId
var authenticationIssuerUri = '${environment().authentication.loginEndpoint}${tenantIdForAuth}/v2.0'

param searchIndexName string // Set in main.parameters.json
param openAiApiKey string = ''
param openAiApiOrganization string = ''


var openAiDeployments = [
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

resource communicationResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(communicationResourceGroupName)) {
  name: !empty(communicationResourceGroupName) ? communicationResourceGroupName : resourceGroup.name
}

resource formRecognizerResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(formRecognizerResourceGroupName)) {
  name: !empty(formRecognizerResourceGroupName) ? formRecognizerResourceGroupName : resourceGroup.name
}

resource TextAnalyticsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(TextAnalyticsResourceGroupName)) {
  name: !empty(TextAnalyticsResourceGroupName) ? TextAnalyticsResourceGroupName : resourceGroup.name
}

resource multiserviceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(multiserviceResourceGroupName)) {
  name: !empty(multiserviceResourceGroupName) ? multiserviceResourceGroupName : resourceGroup.name
}

module storage 'storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled' //disable public access
    networkAcls: networkAcls
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
    name: !empty(searchServiceName) ? searchServiceName : '${abbrs.searServices}${resourceToken}'
    location: !empty(searchServiceLocation) ? searchServiceLocation : location
    publicNetworkAccess: 'enabled' //disable public access
    networkAcls: networkAclsds
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
    name: !empty(speechServiceName) ? speechServiceName : '${abbrs.speechServices}${resourceToken}'
    location: location
    publicNetworkAccess: 'enabled'
    sku: sku
    networkAcls: networkAcls
  }
}

module communicationServiceModule 'communication/communication.bicep' = {
  name: 'communicationServiceModule'
  scope: communicationResourceGroup
  params: {
    name: !empty(communicationServiceName) ? communicationServiceName : '${abbrs.communicationServices}${resourceToken}'
    location: commlocation
  }
}


module openAi 'ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    networkAcls : networkAcls
    publicNetworkAccess :'Enabled'
    sku: {
      name: openAiSkuName
    }
    deployments: openAiDeployments
  }
}

module formRecognizer 'ai/cognitiveservices.bicep' = {
  name: 'formrecognizer'
  scope: formRecognizerResourceGroup
  params: {
    name: !empty(formRecognizerServiceName) ? formRecognizerServiceName : '${abbrs.cognitiveServicesFormRecognizer}${resourceToken}'
    kind: 'FormRecognizer'
    location: formRecognizerResourceGroupLocation
    networkAcls : networkAclsds
    publicNetworkAccess :'Enabled'
    sku: {
      name: formRecognizerSkuName
    }
  }
}

module TextAnalytics 'ai/cognitiveservices.bicep' = {
  name: 'TextAnalytics'
  scope: TextAnalyticsResourceGroup
  params: {
    name: !empty(TextAnalyticsServiceName) ? TextAnalyticsServiceName : '${abbrs.cognitiveServicesTextAnalytics}${resourceToken}'
    kind: 'TextAnalytics'
    location: TextAnalyticsResourceGroupLocation
    networkAcls : networkAclsds
    publicNetworkAccess :'Enabled'
    sku: {
      name: TextAnalyticsSkuName
    }
  }
}

module multiservice 'ai/cognitiveservices.bicep' = {
  name: 'multiservice'
  scope: multiserviceResourceGroup
  params: {
    name: !empty(multiServiceName) ? multiServiceName : '${abbrs.cognitiveServicesmultiaccount}${resourceToken}'
    kind: 'CognitiveServices'
    location: multiserviceResourceGroupLocation
    networkAcls : networkAclsds
    publicNetworkAccess :'Enabled'
    sku: { 
      name: formRecognizerSkuName
    }
  }
}



// The application frontend
module backend 'host/appservice.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
    location: location
    runtimeName: 'python'
    runtimeVersion: '3.11'
    appServicePlanId: appServicePlan.outputs.id
    publicNetworkAccess: 'Enabled' //disable public access
    networkAcls: networkAcls
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    allowedOrigins: [allowedOrigin]
    authenticationIssuerUri: authenticationIssuerUri
    appSettings: {
    }
  }
}


output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenantId
output AZURE_AUTH_TENANT_ID string = authTenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

// Shared by all OpenAI deployments
output OPENAI_HOST string = openAiHost
output AZURE_OPENAI_EMB_MODEL_NAME string = embeddingModelName
output AZURE_OPENAI_CHATGPT_MODEL string = chatGptModelName

// Specific to Azure OpenAI
output AZURE_OPENAI_SERVICE string = (openAiHost == 'azure') ? openAi.outputs.name : ''
output AZURE_OPENAI_RESOURCE_GROUP string = (openAiHost == 'azure') ? openAiResourceGroup.name : ''
output AZURE_OPENAI_CHATGPT_DEPLOYMENT string = (openAiHost == 'azure') ? chatGptDeploymentName : ''
output AZURE_OPENAI_EMB_DEPLOYMENT string = (openAiHost == 'azure') ? embeddingDeploymentName : ''


// Used only with non-Azure OpenAI deployments
output OPENAI_API_KEY string = (openAiHost == 'openai') ? openAiApiKey : ''
output OPENAI_ORGANIZATION string = (openAiHost == 'openai') ? openAiApiOrganization : ''


output AZURE_FORMRECOGNIZER_SERVICE string = formRecognizer.outputs.name
output AZURE_FORMRECOGNIZER_RESOURCE_GROUP string = formRecognizerResourceGroup.name

output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = searchServiceResourceGroup.name

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = storageResourceGroup.name

output AZURE_USE_AUTHENTICATION bool = useAuthentication

output BACKEND_URI string = backend.outputs.uri
