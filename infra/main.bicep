targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'northeurope'

@description('Base name for resources')
param baseName string = 'nao'

@description('PostgreSQL admin password')
@secure()
param pgAdminPassword string

@description('Container image to deploy')
param containerImage string = 'ghcr.io/jonvoge/nao-context:latest'

@description('GitHub Actions SP principal ID (for Key Vault admin)')
param deploymentPrincipalId string

var resourceGroupName = 'rg-${baseName}-${location}'
var kvName = 'kv-${baseName}-${uniqueString(rg.id)}'
var pgName = 'pg-${baseName}-${uniqueString(rg.id)}'
var envName = 'cae-${baseName}'
var appName = 'ca-${baseName}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module keyVault 'modules/keyVault.bicep' = {
  scope: rg
  name: 'keyVault'
  params: {
    name: kvName
    location: location
    adminPrincipalId: deploymentPrincipalId
  }
}

module postgres 'modules/postgres.bicep' = {
  scope: rg
  name: 'postgres'
  params: {
    name: pgName
    location: location
    adminPassword: pgAdminPassword
  }
}

module containerAppsEnv 'modules/containerAppsEnv.bicep' = {
  scope: rg
  name: 'containerAppsEnv'
  params: {
    name: envName
    location: location
  }
}

module containerApp 'modules/containerApp.bicep' = {
  scope: rg
  name: 'containerApp'
  params: {
    name: appName
    location: location
    environmentId: containerAppsEnv.outputs.id
    containerImage: containerImage
    keyVaultName: kvName
  }
}

// Grant Container App managed identity access to Key Vault secrets
module keyVaultAppAccess 'modules/keyVaultRoleAssignment.bicep' = {
  scope: rg
  name: 'keyVaultAppAccess'
  params: {
    keyVaultName: kvName
    principalId: containerApp.outputs.principalId
  }
}

output containerAppFqdn string = containerApp.outputs.fqdn
output resourceGroupName string = rg.name
output keyVaultName string = kvName
output postgresFqdn string = postgres.outputs.fqdn
