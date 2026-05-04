using './main.bicep'

param location = 'northeurope'
param baseName = 'nao'
param containerImage = 'ghcr.io/jonvoge/nao-context:latest'
// pgAdminPassword and deploymentPrincipalId supplied via GitHub Actions workflow
