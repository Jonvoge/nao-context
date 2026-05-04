using './main.bicep'

param location = 'northeurope'
param baseName = 'nao'
param containerImage = 'docker.io/getnao/nao:latest'
// pgAdminPassword and deploymentPrincipalId supplied via GitHub Actions workflow
