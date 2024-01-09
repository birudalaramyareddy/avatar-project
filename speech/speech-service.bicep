param name string
param location string
param publicNetworkAccess string
param sku object

param networkAcls object

resource speechService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  kind: 'SpeechServices'
  properties: {
    customSubDomainName: '${name}-speech'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
  }
  sku: sku
}
