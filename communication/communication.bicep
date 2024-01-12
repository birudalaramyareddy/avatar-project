param name string
param location string
param properties object = {
  dataLocation: 'United States'
}

resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01-preview' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: properties
}

output communicationServiceResourceId string = communicationService.id
output communicationServiceResourceName string = communicationService.name
