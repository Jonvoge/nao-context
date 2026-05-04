# nao Azure Deployment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy nao as a self-hosted Conversational BI agent on Azure Container Apps, connected to two Microsoft Fabric data sources, with automated CI/CD via GitHub Actions.

**Architecture:** Docker container (FROM getnao/nao:latest + baked context) running on Azure Container Apps (consumption/serverless), backed by PostgreSQL Flexible Server for app state, secrets in Key Vault. GitHub Actions deploys both infrastructure (Bicep) and application (container image) via OIDC.

**Tech Stack:** Bicep, GitHub Actions, Docker, nao-core (Python), Azure Container Apps, Azure PostgreSQL Flexible Server, Azure Key Vault, Microsoft Fabric (SQL endpoints)

---

## File Structure

```
c:\repos\nao\
├── nao_config.yaml
├── RULES.md
├── Dockerfile
├── .dockerignore
├── .gitignore
├── .env.example
├── agent/
│   ├── mcps/
│   │   └── mcp.json
│   ├── skills/
│   └── tools/
├── databases/                    # populated by nao sync
├── docs/
├── queries/
│   └── examples.md
├── infra/
│   ├── main.bicep               # orchestrator
│   ├── modules/
│   │   ├── containerAppsEnv.bicep
│   │   ├── containerApp.bicep
│   │   ├── postgres.bicep
│   │   └── keyVault.bicep
│   └── main.bicepparam
└── .github/
    └── workflows/
        ├── deploy-infra.yml
        └── deploy-app.yml
```

---

### Task 1: Initialize Git Repo & Project Scaffolding

**Files:**
- Create: `.gitignore`
- Create: `.env.example`
- Create: `RULES.md`
- Create: `queries/examples.md`
- Create: `agent/mcps/mcp.json`
- Create: `agent/skills/.gitkeep`
- Create: `agent/tools/.gitkeep`
- Create: `databases/.gitkeep`
- Create: `docs/.gitkeep`

- [ ] **Step 1: Initialize git repo**

```bash
cd c:\repos\nao
git init
```

- [ ] **Step 2: Create .gitignore**

```gitignore
.env
venv/
__pycache__/
.DS_Store
databases/
!databases/.gitkeep
```

- [ ] **Step 3: Create .env.example**

```env
ANTHROPIC_API_KEY=sk-ant-...
FABRIC_SP_CLIENT_ID=00000000-0000-0000-0000-000000000000
FABRIC_SP_SECRET=your-secret-here
FABRIC_SP_TENANT_ID=a7ed0222-1883-488c-8bbb-6ee4f043da6d
DB_URI=postgres://nao:password@localhost:5432/nao
BETTER_AUTH_URL=http://localhost:5005
```

- [ ] **Step 4: Create RULES.md**

```markdown
# Agent Rules

You are an analytics agent for Inspari. You help users explore and analyze data from Microsoft Fabric.

## Behavior

- Always write T-SQL (Fabric uses T-SQL dialect: use TOP N instead of LIMIT, use square brackets for identifiers)
- When uncertain about a column or table, check the schema context before guessing
- Present results clearly with explanations of what the data means
- If a question is ambiguous, ask a clarifying question before writing SQL

## Data Sources

- **RetailDemoDB**: Retail planning data including products, stores, sales, and forecasts
- **ContosoLH**: Contoso dataset in a Lakehouse — sales, customers, products, geography

## Formatting

- Use markdown tables for tabular results
- Include the SQL query you ran so users can learn
- Summarize key insights after presenting data
```

- [ ] **Step 5: Create agent directory scaffolding**

Create `agent/mcps/mcp.json`:
```json
{
  "mcpServers": {}
}
```

Create `agent/skills/.gitkeep`, `agent/tools/.gitkeep`, `databases/.gitkeep`, `docs/.gitkeep` as empty files.

- [ ] **Step 6: Create queries/examples.md**

```markdown
# Example Queries

These help the agent understand what kinds of questions users ask.

## RetailDemoDB

- What were total sales by store last month?
- Show me the top 10 products by revenue
- Compare actual vs forecast for Q1

## ContosoLH

- What are the top selling product categories?
- Show customer distribution by geography
- What's the month-over-month sales trend?
```

- [ ] **Step 7: Commit scaffolding**

```bash
git add -A
git commit -m "chore: initialize nao project scaffolding"
```

---

### Task 2: nao Configuration File

**Files:**
- Create: `nao_config.yaml`

- [ ] **Step 1: Create nao_config.yaml**

```yaml
project_name: inspari-nao

databases:
  - name: retail-demo-db
    type: fabric
    server: eibo3j4ddcgerc53n3spaq62nu-ljqt5nlzvp4utphqm4squnhwgm.datawarehouse.fabric.microsoft.com
    database: RetailDemoDB
    schema_name: dbo
    auth_method: azure_service_principal
    client_id: "{{ env('FABRIC_SP_CLIENT_ID') }}"
    client_secret: "{{ env('FABRIC_SP_SECRET') }}"
    tenant_id: "{{ env('FABRIC_SP_TENANT_ID') }}"
    templates:
      - columns
      - how_to_use
      - preview

  - name: contoso-lakehouse
    type: fabric
    server: eibo3j4ddcgerc53n3spaq62nu-hcdqqkllll5uxnxa3jtidw25wu.datawarehouse.fabric.microsoft.com
    database: ContosoLH
    schema_name: dbo
    auth_method: azure_service_principal
    client_id: "{{ env('FABRIC_SP_CLIENT_ID') }}"
    client_secret: "{{ env('FABRIC_SP_SECRET') }}"
    tenant_id: "{{ env('FABRIC_SP_TENANT_ID') }}"
    templates:
      - columns
      - how_to_use
      - preview

llm:
  provider: anthropic
  api_key: "{{ env('ANTHROPIC_API_KEY') }}"
  annotation_model: claude-sonnet-4-6
```

- [ ] **Step 2: Commit**

```bash
git add nao_config.yaml
git commit -m "feat: add nao configuration with Fabric databases"
```

---

### Task 3: Dockerfile & Docker Config

**Files:**
- Create: `Dockerfile`
- Create: `.dockerignore`

- [ ] **Step 1: Create Dockerfile**

```dockerfile
FROM getnao/nao:latest

COPY . /app/project/

WORKDIR /app/project
```

- [ ] **Step 2: Create .dockerignore**

```
.env
.env.example
venv/
.git/
.github/
infra/
docs/superpowers/
__pycache__/
.DS_Store
*.md
!RULES.md
!queries/examples.md
```

- [ ] **Step 3: Verify Docker build locally**

```bash
docker build -t nao-inspari:local .
```

Expected: successful build, image tagged `nao-inspari:local`.

- [ ] **Step 4: Commit**

```bash
git add Dockerfile .dockerignore
git commit -m "feat: add Dockerfile for nao deployment"
```

---

### Task 4: Bicep Infrastructure — Key Vault

**Files:**
- Create: `infra/modules/keyVault.bicep`

- [ ] **Step 1: Create infra/modules/keyVault.bicep**

```bicep
@description('Name of the Key Vault')
param name string

@description('Azure region')
param location string

@description('Principal ID that gets Secrets Officer role')
param adminPrincipalId string

@description('Principal ID for the Container App managed identity')
param containerAppPrincipalId string = ''

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Admin gets full secrets management
resource adminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, adminPrincipalId, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: kv
  properties: {
    principalId: adminPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalType: 'ServicePrincipal'
  }
}

// Container App gets read-only secrets access
resource appRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(containerAppPrincipalId)) {
  name: guid(kv.id, containerAppPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: kv
  properties: {
    principalId: containerAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalType: 'ServicePrincipal'
  }
}

output vaultUri string = kv.properties.vaultUri
output vaultName string = kv.name
output vaultId string = kv.id
```

- [ ] **Step 2: Commit**

```bash
git add infra/modules/keyVault.bicep
git commit -m "feat(infra): add Key Vault Bicep module"
```

---

### Task 5: Bicep Infrastructure — PostgreSQL

**Files:**
- Create: `infra/modules/postgres.bicep`

- [ ] **Step 1: Create infra/modules/postgres.bicep**

```bicep
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
output connectionString string = 'postgres://${adminLogin}:PASSWORD_PLACEHOLDER@${pg.properties.fullyQualifiedDomainName}:5432/nao?sslmode=require'
```

- [ ] **Step 2: Commit**

```bash
git add infra/modules/postgres.bicep
git commit -m "feat(infra): add PostgreSQL Flexible Server Bicep module"
```

---

### Task 6: Bicep Infrastructure — Container Apps Environment & App

**Files:**
- Create: `infra/modules/containerAppsEnv.bicep`
- Create: `infra/modules/containerApp.bicep`

- [ ] **Step 1: Create infra/modules/containerAppsEnv.bicep**

```bicep
@description('Environment name')
param name string

@description('Azure region')
param location string

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  properties: {
    zoneRedundant: false
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

output id string = env.id
output name string = env.name
```

- [ ] **Step 2: Create infra/modules/containerApp.bicep**

```bicep
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
      registries: [
        {
          server: 'ghcr.io'
          username: ''
          passwordSecretRef: ''
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
```

- [ ] **Step 3: Commit**

```bash
git add infra/modules/containerAppsEnv.bicep infra/modules/containerApp.bicep
git commit -m "feat(infra): add Container Apps Environment and App Bicep modules"
```

---

### Task 7: Bicep Infrastructure — Main Orchestrator

**Files:**
- Create: `infra/main.bicep`
- Create: `infra/main.bicepparam`

- [ ] **Step 1: Create infra/main.bicep**

```bicep
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
module keyVaultAppAccess 'modules/keyVault.bicep' = {
  scope: rg
  name: 'keyVaultAppAccess'
  params: {
    name: kvName
    location: location
    adminPrincipalId: deploymentPrincipalId
    containerAppPrincipalId: containerApp.outputs.principalId
  }
}

output containerAppFqdn string = containerApp.outputs.fqdn
output resourceGroupName string = rg.name
output keyVaultName string = kvName
output postgresFqdn string = postgres.outputs.fqdn
```

- [ ] **Step 2: Create infra/main.bicepparam**

```bicep
using './main.bicep'

param location = 'northeurope'
param baseName = 'nao'
param containerImage = 'ghcr.io/jonvoge/nao-context:latest'
// pgAdminPassword and deploymentPrincipalId supplied via GitHub Actions workflow
```

- [ ] **Step 3: Validate Bicep compiles**

```bash
az bicep build --file infra/main.bicep
```

Expected: no errors, generates ARM JSON.

- [ ] **Step 4: Commit**

```bash
git add infra/main.bicep infra/main.bicepparam
git commit -m "feat(infra): add main Bicep orchestrator"
```

---

### Task 8: GitHub Actions — Infrastructure Deployment

**Files:**
- Create: `.github/workflows/deploy-infra.yml`

- [ ] **Step 1: Create .github/workflows/deploy-infra.yml**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ['infra/**']
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy Bicep
        uses: azure/arm-deploy@v2
        with:
          scope: subscription
          region: northeurope
          template: infra/main.bicep
          parameters: >-
            pgAdminPassword=${{ secrets.PG_ADMIN_PASSWORD }}
            deploymentPrincipalId=${{ secrets.AZURE_CLIENT_ID }}
            containerImage=ghcr.io/${{ github.repository_owner }}/nao-context:latest
          deploymentName: nao-infra-${{ github.run_number }}

      - name: Populate Key Vault Secrets
        run: |
          KV_NAME=$(az deployment sub show \
            --name nao-infra-${{ github.run_number }} \
            --query properties.outputs.keyVaultName.value -o tsv)

          PG_FQDN=$(az deployment sub show \
            --name nao-infra-${{ github.run_number }} \
            --query properties.outputs.postgresFqdn.value -o tsv)

          DB_URI="postgres://naoadmin:${{ secrets.PG_ADMIN_PASSWORD }}@${PG_FQDN}:5432/nao?sslmode=require"

          az keyvault secret set --vault-name "$KV_NAME" --name "DB-URI" --value "$DB_URI"
          az keyvault secret set --vault-name "$KV_NAME" --name "ANTHROPIC-API-KEY" --value "${{ secrets.ANTHROPIC_API_KEY }}"
          az keyvault secret set --vault-name "$KV_NAME" --name "FABRIC-SP-CLIENT-ID" --value "${{ secrets.FABRIC_SP_CLIENT_ID }}"
          az keyvault secret set --vault-name "$KV_NAME" --name "FABRIC-SP-SECRET" --value "${{ secrets.FABRIC_SP_SECRET }}"

      - name: Update BETTER_AUTH_URL
        run: |
          FQDN=$(az deployment sub show \
            --name nao-infra-${{ github.run_number }} \
            --query properties.outputs.containerAppFqdn.value -o tsv)

          RG=$(az deployment sub show \
            --name nao-infra-${{ github.run_number }} \
            --query properties.outputs.resourceGroupName.value -o tsv)

          az containerapp update \
            --name ca-nao \
            --resource-group "$RG" \
            --set-env-vars "BETTER_AUTH_URL=https://${FQDN}"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/deploy-infra.yml
git commit -m "ci: add infrastructure deployment workflow"
```

---

### Task 9: GitHub Actions — Application Deployment

**Files:**
- Create: `.github/workflows/deploy-app.yml`

- [ ] **Step 1: Create .github/workflows/deploy-app.yml**

```yaml
name: Deploy Application

on:
  push:
    branches: [main]
    paths-ignore: ['infra/**', 'docs/**', '*.md', '!RULES.md']
  workflow_dispatch:

permissions:
  id-token: write
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/nao-context

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Container Apps
        run: |
          az containerapp update \
            --name ca-nao \
            --resource-group rg-nao-northeurope \
            --image ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/deploy-app.yml
git commit -m "ci: add application deployment workflow"
```

---

### Task 10: One-Time Manual Setup (Portal/GitHub UI)

This task is a checklist for Jon to complete manually — no code to write.

- [ ] **Step 1: Create Entra App Registration for GitHub Actions**

1. Azure Portal → Entra ID → App registrations → New registration
2. Name: `sp-nao-github-actions`
3. After creation, note the **Application (client) ID** and **Directory (tenant) ID**
4. Go to Certificates & secrets → Federated credentials → Add credential
5. Scenario: GitHub Actions deploying Azure resources
6. Organization: `Jonvoge`
7. Repository: `nao-context`
8. Entity type: Branch → `main`
9. Name: `github-actions-main`

- [ ] **Step 2: Grant Azure RBAC to GitHub Actions SP**

```
Subscription → Access control (IAM) → Add role assignment:
- Role: Contributor
- Assign to: sp-nao-github-actions
```

- [ ] **Step 3: Create Entra App Registration for Fabric**

1. Azure Portal → Entra ID → App registrations → New registration
2. Name: `sp-nao-fabric-reader`
3. After creation, go to Certificates & secrets → New client secret
4. Note: **Client ID**, **Client Secret**, **Tenant ID**

- [ ] **Step 4: Grant Fabric workspace access to the SP**

1. Fabric Portal → Workspace "Fabric Demos: Retail Planning" → Manage access → Add → `sp-nao-fabric-reader` → Viewer
2. Fabric Portal → Workspace "Fabric Demos - Writeback" → Manage access → Add → `sp-nao-fabric-reader` → Viewer

- [ ] **Step 5: Create GitHub repo and add secrets**

1. GitHub → New repository: `Jonvoge/nao-context` (private)
2. Settings → Secrets and variables → Actions → New repository secret:
   - `AZURE_CLIENT_ID` — from Step 1
   - `AZURE_TENANT_ID` — `a7ed0222-1883-488c-8bbb-6ee4f043da6d`
   - `AZURE_SUBSCRIPTION_ID` — your Azure subscription ID
   - `PG_ADMIN_PASSWORD` — generate a strong password (e.g. `openssl rand -base64 24`)
   - `ANTHROPIC_API_KEY` — your Anthropic API key
   - `FABRIC_SP_CLIENT_ID` — from Step 3
   - `FABRIC_SP_SECRET` — from Step 3

- [ ] **Step 6: Push code and trigger deployment**

```bash
cd c:\repos\nao
git remote add origin https://github.com/Jonvoge/nao-context.git
git push -u origin main
```

This triggers `deploy-infra.yml` (infra changes) and `deploy-app.yml` (app changes).

- [ ] **Step 7: First sign-up**

Once deployed, open `https://ca-nao.<hash>.northeurope.azurecontainerapps.io` in browser. Sign up with your email — you become admin.

---

### Task 11: Local nao sync (populate database schemas)

- [ ] **Step 1: Install nao-core locally**

```bash
pip install nao-core
```

- [ ] **Step 2: Create .env with real credentials**

Copy `.env.example` to `.env` and fill in real values for the Fabric SP and Anthropic key.

- [ ] **Step 3: Run nao sync**

```bash
cd c:\repos\nao
nao sync
```

Expected: databases/ folder gets populated with schema files for both Fabric sources.

- [ ] **Step 4: Verify with nao debug**

```bash
nao debug
```

Expected: all checks pass (config syntax, database connectivity, LLM access).

- [ ] **Step 5: Commit synced schemas and push**

```bash
git add databases/
git commit -m "feat: sync database schemas from Fabric"
git push
```

This triggers a new app deployment with the schema context baked into the image.

---

### Task 12: Verify End-to-End

- [ ] **Step 1: Wait for GitHub Actions to complete**

Check Actions tab — both workflows should succeed.

- [ ] **Step 2: Open nao chat UI**

Navigate to the Container Apps URL. Confirm UI loads and you can sign in.

- [ ] **Step 3: Ask a test question against RetailDemoDB**

```
What are the top 5 products by total sales?
```

Expected: nao generates T-SQL, executes against Fabric, returns results.

- [ ] **Step 4: Ask a test question against ContosoLH**

```
Show me customer count by geography
```

Expected: nao queries the Lakehouse SQL endpoint and returns results.

- [ ] **Step 5: Add a colleague**

Admin panel → Team → Add user with email/password. Have them sign in.

---
