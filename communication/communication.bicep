param name string
param location string
param dataLocation string
param linkedDomains array

resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01-preview' = {
  name: name
  location: location
  identity: {
    type: 'string'
    userAssignedIdentities: {}
  }
  properties: {
    dataLocation: dataLocation
    linkedDomains: linkedDomains
  }
}

output communicationServiceResourceId string = communicationService.id
output communicationServiceResourceName string = communicationService.name

