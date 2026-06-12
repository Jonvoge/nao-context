@description('Name of the Key Vault')
param name string

@description('Azure region')
param location string

@description('Principal ID that gets Secrets Officer role')
param adminPrincipalId string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: adminPrincipalId
        permissions: {
          secrets: ['get', 'list', 'set', 'delete', 'backup', 'restore', 'recover', 'purge']
        }
      }
    ]
  }
}

output vaultUri string = kv.properties.vaultUri
output vaultName string = kv.name
output vaultId string = kv.id
