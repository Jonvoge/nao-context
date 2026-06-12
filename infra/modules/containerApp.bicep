@description('Container App name')
param name string

@description('Azure region')
param location string

@description('Container Apps Environment ID')
param environmentId string

@description('Container image (e.g. ghcr.io/jonvoge/nao-context:latest)')
param containerImage string

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
            { name: 'FABRIC_SP_TENANT_ID', value: 'a7ed0222-1883-488c-8bbb-6ee4f043da6d' }
            { name: 'BETTER_AUTH_URL', value: 'https://placeholder.northeurope.azurecontainerapps.io' }
            { name: 'NAO_DEFAULT_PROJECT_PATH', value: '/app/context' }
          ]
          probes: [
            {
              type: 'startup'
              httpGet: {
                path: '/'
                port: 5005
              }
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 60
            }
            {
              type: 'liveness'
              httpGet: {
                path: '/'
                port: 5005
              }
              periodSeconds: 30
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
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
