@description('Server name')
param name string

@description('Azure region')
param location string

@description('Administrator login')
param adminLogin string = 'naoadmin'

@secure()
@description('Administrator password')
param adminPassword string

resource pg 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// Allow Azure services to connect
resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: pg
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Disable SSL enforcement — Container Apps network traffic is already encrypted at the Azure layer,
// and the postgres.js driver in nao:latest doesn't pass sslmode from connection URL params.
resource sslParam 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-12-01-preview' = {
  parent: pg
  name: 'require_secure_transport'
  properties: {
    value: 'off'
    source: 'user-override'
  }
}

// Create the nao database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: pg
  name: 'nao'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

output fqdn string = pg.properties.fullyQualifiedDomainName
output connectionString string = 'postgres://${adminLogin}:PASSWORD_PLACEHOLDER@${pg.properties.fullyQualifiedDomainName}:5432/nao'
