@description('Azure region for all resources')
param location string = 'northeurope'

@description('Base name for resources')
param baseName string = 'nao'

@description('PostgreSQL admin password')
@secure()
param pgAdminPassword string

@description('Container image to deploy')
param containerImage string = 'docker.io/getnao/nao:latest'

@description('GitHub Actions SP principal ID (for Key Vault admin)')
param deploymentPrincipalId string

var kvName = 'kv-${baseName}-${uniqueString(resourceGroup().id)}'
var pgName = 'pg-${baseName}-${uniqueString(resourceGroup().id)}'
var envName = 'cae-${baseName}'
var appName = 'ca-${baseName}'

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    name: kvName
    location: location
    adminPrincipalId: deploymentPrincipalId
  }
}

module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    name: pgName
    location: location
    adminPassword: pgAdminPassword
  }
}

module containerAppsEnv 'modules/containerAppsEnv.bicep' = {
  name: 'containerAppsEnv'
  params: {
    name: envName
    location: location
  }
}

module containerApp 'modules/containerApp.bicep' = {
  name: 'containerApp'
  params: {
    name: appName
    location: location
    environmentId: containerAppsEnv.outputs.id
    containerImage: containerImage
  }
}

// Grant Container App managed identity access to Key Vault secrets
module keyVaultAppAccess 'modules/keyVaultRoleAssignment.bicep' = {
  name: 'keyVaultAppAccess'
  params: {
    keyVaultName: kvName
    principalId: containerApp.outputs.principalId
  }
}

output containerAppFqdn string = containerApp.outputs.fqdn
output resourceGroupName string = resourceGroup().name
output keyVaultName string = kvName
output postgresFqdn string = postgres.outputs.fqdn
