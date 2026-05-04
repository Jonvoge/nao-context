@description('Container App name')
param name string

@description('Azure region')
param location string

@description('Container Apps Environment ID')
param environmentId string

@description('Container image (e.g. ghcr.io/jonvoge/nao-context:latest)')
param containerImage string

@description('Key Vault name for secret references')
param keyVaultName string

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: environmentId
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 5005
        transport: 'auto'
        allowInsecure: false
      }
      secrets: [
        {
          name: 'db-uri'
          keyVaultUrl: 'https://${keyVaultName}.vault.azure.net/secrets/DB-URI'
          identity: 'system'
        }
        {
          name: 'anthropic-api-key'
          keyVaultUrl: 'https://${keyVaultName}.vault.azure.net/secrets/ANTHROPIC-API-KEY'
          identity: 'system'
        }
        {
          name: 'fabric-sp-client-id'
          keyVaultUrl: 'https://${keyVaultName}.vault.azure.net/secrets/FABRIC-SP-CLIENT-ID'
          identity: 'system'
        }
        {
          name: 'fabric-sp-secret'
          keyVaultUrl: 'https://${keyVaultName}.vault.azure.net/secrets/FABRIC-SP-SECRET'
          identity: 'system'
        }
      ]

    }
    template: {
      containers: [
        {
          name: 'nao'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'NAO_DEFAULT_PROJECT_PATH', value: '/app/project' }
            { name: 'FABRIC_SP_TENANT_ID', value: 'a7ed0222-1883-488c-8bbb-6ee4f043da6d' }
            { name: 'BETTER_AUTH_URL', value: 'https://PLACEHOLDER.northeurope.azurecontainerapps.io' }
            { name: 'DB_URI', secretRef: 'db-uri' }
            { name: 'ANTHROPIC_API_KEY', secretRef: 'anthropic-api-key' }
            { name: 'FABRIC_SP_CLIENT_ID', secretRef: 'fabric-sp-client-id' }
            { name: 'FABRIC_SP_SECRET', secretRef: 'fabric-sp-secret' }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output principalId string = app.identity.principalId
output name string = app.name
