metadata description = 'Creates an Azure App Service in an existing Azure App Service plan.'
param name string
param location string = resourceGroup().location

// Reference Properties
param appServicePlanId string
param keyVaultName string = ''
param managedIdentity bool = !empty(keyVaultName)

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string 

// Runtime Properties
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'
param runtimeVersion string

// Microsoft.Web/sites Properties
param kind string = 'app,linux'

// Microsoft.Web/sites/config
param allowedOrigins array = []
param additionalScopes array = []
param additionalAllowedAudiences array = []
param allowedApplications array = []
param alwaysOn bool = true
param appCommandLine string = ''
@secure()
param appSettings object = {}
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param linuxFxVersion string = runtimeNameAndVersion
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param scmDoBuildDuringDeployment bool = false
param use32BitWorkerProcess bool = false
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = ''
param clientAppId string = ''
param networkAcls object 
param serverAppId string = ''
@secure()
param clientSecretSettingName string = ''
param authenticationIssuerUri string = ''

var msftAllowedOrigins = [ 'https://portal.azure.com', 'https://ms.portal.azure.com' ]
var loginEndpoint = environment().authentication.loginEndpoint
var loginEndpointFixed = lastIndexOf(loginEndpoint, '/') == length(loginEndpoint) - 1 ? substring(loginEndpoint, 0, length(loginEndpoint) - 1) : loginEndpoint
var allMsftAllowedOrigins = !(empty(clientAppId)) ? union(msftAllowedOrigins, [loginEndpointFixed]) : msftAllowedOrigins

// .default must be the 1st scope for On-Behalf-Of-Flow combined consent to work properly
// Please see https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow#default-and-combined-consent
var requiredScopes = ['api://${serverAppId}/.default', 'openid', 'profile', 'email', 'offline_access']
var requiredAudiences = ['api://${serverAppId}']

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      ftpsState: ftpsState
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      publicNetworkAccess: publicNetworkAccess
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      cors: {
        allowedOrigins: union(allMsftAllowedOrigins, allowedOrigins)
      }
    }
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
  }

  identity: { type: managedIdentity ? 'SystemAssigned' : 'None' }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(appSettings,
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: string(scmDoBuildDuringDeployment)
        ENABLE_ORYX_BUILD: string(enableOryxBuild)
      },
      runtimeName == 'python' ? { PYTHON_ENABLE_GUNICORN_MULTIWORKERS: 'true'} : {})
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
    dependsOn: [
      configAppSettings
    ]
  }

  resource basicPublishingCredentialsPoliciesFtp 'basicPublishingCredentialsPolicies' = {
    name: 'ftp'
    properties: {
      allow: false
    }
  }

  resource basicPublishingCredentialsPoliciesScm 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: false
    }
  }

  resource configAuth 'config' = if (!(empty(clientAppId))) {
    name: 'authsettingsV2'
    properties: {
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: 'RedirectToLoginPage'
        redirectToProvider: 'azureactivedirectory'
      }
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            clientId: clientAppId
            clientSecretSettingName: clientSecretSettingName
            openIdIssuer: authenticationIssuerUri
          }
          login: {
            loginParameters: ['scope=${join(union(requiredScopes, additionalScopes), ' ')}']
          }
          validation: {
            allowedAudiences: union(requiredAudiences, additionalAllowedAudiences)
            defaultAuthorizationPolicy: {
              allowedApplications: allowedApplications
            }
          }
        }
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
    }
  }
}

output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
