#!/usr/bin/env pwsh
# Run nao sync locally using Docker
# Prerequisites: Docker Desktop running, .env file present

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot/..

if (-not (Test-Path .env)) {
    Write-Error ".env file not found. Create one with FABRIC_SP_CLIENT_ID, FABRIC_SP_SECRET, FABRIC_SP_TENANT_ID, ANTHROPIC_API_KEY, DB_URI"
    exit 1
}

docker run --rm --env-file .env -v "${PWD}:/app/project" -w /app/project --entrypoint "" getnao/nao:latest sh -c "
    apt-get update -qq 2>/dev/null &&
    apt-get install -y -qq gnupg2 2>/dev/null &&
    curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg &&
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main' > /etc/apt/sources.list.d/mssql-release.list &&
    apt-get update -qq 2>/dev/null &&
    ACCEPT_EULA=Y apt-get install -y -qq msodbcsql18 2>/dev/null &&
    nao sync -p databases
"
