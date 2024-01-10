param location string 
param dbServerName string 
param sqlDbName string 

@description('Enter the AD group name for Sql Admin Login')
param ADGroupAdmin string 
@description('sid of the AD group name for Sql Admin Login')
param sid string 
@description('tenant id')
param tenantId string 


resource sqlserver 'Microsoft.Sql/servers@2021-11-01-preview' = {
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: ADGroupAdmin
      sid: sid
      tenantId: tenantId
      azureADOnlyAuthentication: true
    }
    
    restrictOutboundNetworkAccess: 'Disabled'
  }
  location: location
  name: dbServerName
}

// Create a firewall rule to allow Azure services
resource firewallRule 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: '${sqlserver.name}/AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0' // Allow all Azure IPs
    endIpAddress: '0.0.0.0'
  }
}

resource sqldb 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 10
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    isLedgerOn: false
  }
  location: location
  name: '${sqlserver.name}/${sqlDbName}'
}

