# Design: nao Conversational BI on Azure

**Date:** 2025-05-04  
**Status:** Approved  
**Author:** Jon Vöge  

## Overview

Deploy [nao](https://github.com/getnao/nao) (open-source analytics agent) as a self-hosted Conversational BI solution on Azure, connected to Microsoft Fabric data sources, accessible to a small team (< 10 users).

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  GitHub (Jonvoge/nao-context)                                │
│  ┌─────────────┐  ┌────────────────────┐                    │
│  │ nao context │  │ .github/workflows/ │                    │
│  │ + Bicep     │  │ deploy-infra.yml   │                    │
│  │ + Dockerfile│  │ deploy-nao.yml     │                    │
│  └─────────────┘  └────────────────────┘                    │
└───────────────────────────┬──────────────────────────────────┘
                            │ GitHub Actions (OIDC)
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Azure (North Europe)                                        │
│                                                              │
│  ┌─────────────────────┐     ┌──────────────────────┐       │
│  │ Azure Container Apps│────▶│ Azure Key Vault      │       │
│  │ (getnao/nao:latest) │     │ - ANTHROPIC_API_KEY  │       │
│  │ Port 5005           │     │ - FABRIC_SP_SECRET   │       │
│  └─────────┬───────────┘     │ - DB_URI             │       │
│            │                  └──────────────────────┘       │
│            ▼                                                 │
│  ┌─────────────────────┐                                     │
│  │ Azure PostgreSQL    │                                     │
│  │ Flexible Server     │                                     │
│  │ (Burstable B1ms)   │                                     │
│  └─────────────────────┘                                     │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼ (Fabric connector via SP)
┌──────────────────────────────────────────────────────────────┐
│  Microsoft Fabric                                            │
│                                                              │
│  Workspace: "Fabric Demos: Retail Planning"                  │
│    └── RetailDemoDB (SQL Database)                           │
│                                                              │
│  Workspace: "Fabric Demos - Writeback"                       │
│    └── ConsosoLH (Lakehouse SQL endpoint)                    │
└──────────────────────────────────────────────────────────────┘
```

## Components

### 1. Azure Infrastructure (Bicep)

| Resource | Type | Configuration |
|---|---|---|
| Resource Group | `Microsoft.Resources/resourceGroups` | `rg-nao-northeurope` |
| Container Apps Environment | `Microsoft.App/managedEnvironments` | Consumption plan, North Europe |
| Container App | `Microsoft.App/containerApps` | Image: custom (FROM getnao/nao:latest), port 5005, min 0 / max 2 replicas |
| PostgreSQL Flexible Server | `Microsoft.DBforPostgreSQL/flexibleServers` | Burstable B1ms, 32GB storage, PG 16 |
| Key Vault | `Microsoft.KeyVault/vaults` | Standard SKU, RBAC access model |

### 2. nao Configuration (`nao_config.yaml`)

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

### 3. GitHub Actions Workflows

**`deploy-infra.yml`** — Triggered on push to `infra/**`:
- Authenticates to Azure via OIDC (federated credentials, no secret rotation)
- Deploys Bicep templates
- Outputs Container Apps URL, PostgreSQL connection string

**`deploy-nao.yml`** — Triggered on push to `main` (excluding `infra/**`):
- Builds Docker image (FROM getnao/nao:latest + COPY context)
- Pushes to GitHub Container Registry (ghcr.io)
- Updates Container App revision with new image

### 4. Docker Image

```dockerfile
FROM getnao/nao:latest
COPY . /app/project/
WORKDIR /app/project
```

Stock nao image with context baked in. Env vars injected at runtime by Container Apps (from Key Vault references).

### 5. Authentication & User Management

- Built-in nao auth (email/password)
- First signup becomes admin (Jon)
- Admin manually adds colleagues via admin panel
- No SSO, no Google OAuth

### 6. Fabric Service Principal

- Single Entra ID App Registration used for both Fabric connections
- Granted Viewer/Member role on both workspaces
- Tenant admin must enable "Service principals can use Fabric APIs" in tenant settings (or it may already be enabled)
- Client ID + Secret stored in Key Vault

### 7. Container App Environment Variables

| Variable | Source | Purpose |
|---|---|---|
| `NAO_DEFAULT_PROJECT_PATH` | Hardcoded: `/app/project` | Points nao to the context folder |
| `BETTER_AUTH_URL` | Container Apps FQDN | Auth callback URL |
| `DB_URI` | Key Vault reference | PostgreSQL connection string |
| `ANTHROPIC_API_KEY` | Key Vault reference | LLM provider key |
| `FABRIC_SP_CLIENT_ID` | Key Vault reference | Service Principal client ID |
| `FABRIC_SP_SECRET` | Key Vault reference | Service Principal client secret |
| `FABRIC_SP_TENANT_ID` | Hardcoded: `a7ed0222-...` | Entra tenant ID |

## Decisions & Trade-offs

| Decision | Rationale | Alternative considered |
|---|---|---|
| Container Apps over AKS | < 10 users, no need for K8s complexity. Scale-to-zero saves cost. | AKS (overkill), App Service (no scale-to-zero) |
| Bake context into image | Simpler than `NAO_CONTEXT_GIT_URL` clone-on-startup. Rebuild on push ensures consistency. | Git sync at runtime (slower cold start, needs git credentials) |
| Anthropic direct over Azure OpenAI | Simpler setup, nao's SQL agent is optimized for Claude. | Azure OpenAI (requires resource provisioning + model deployment) |
| PostgreSQL Flex over Cosmos/SQLite | nao requires PostgreSQL specifically. Flex Server is cheapest managed option. | Azure SQL (not supported by nao) |
| GitHub Actions + OIDC | No secrets to rotate, push-to-deploy, free tier sufficient. | Cloud Shell scripts (manual, error-prone per user's past experience) |
| Manual auth over Entra SSO | nao doesn't natively support OIDC/SAML with Entra. Would require reverse proxy. Overkill for < 10 users. | Azure Front Door + Entra auth (complex, costly) |

## One-Time Manual Setup (Portal UI)

These steps cannot be automated and must be done once by Jon:

1. **Create App Registration for GitHub Actions OIDC** — add federated credential for the GitHub repo
2. **Create App Registration for Fabric SP** — grant workspace access in Fabric
3. **Add GitHub Secrets** — `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
4. **Add Anthropic API key** to GitHub Secrets (so it can be pushed to Key Vault)
5. **First sign-up** on the deployed nao URL to become admin

## Out of Scope (Future)

- Microsoft Teams bot integration
- Custom domain / TLS certificate
- Entra ID SSO
- nao Cloud (managed hosting)
- Additional databases beyond the two Fabric sources
- GitHub Actions for `nao sync` automation (can add later)
- Monitoring / alerting

## Success Criteria

1. nao chat UI accessible at Container Apps URL
2. Can ask natural-language questions and get SQL-generated answers from both Fabric sources
3. Colleagues can sign in with admin-created accounts
4. Infrastructure redeploys automatically on git push
