param name string
param location string

resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01-preview' = {
  name: name
  location: location
  identity: {
    type: 'string'
    userAssignedIdentities: {}
  }
  properties: {
    dataLocation: 'string'
    linkedDomains: [
      'string'
    ]
  }
}
