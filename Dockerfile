FROM getnao/nao:latest

# Install ODBC Driver 18 for SQL Server (required for Fabric connections)
RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends gnupg2 curl \
    && curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main' > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update -qq \
    && ACCEPT_EULA=Y apt-get install -y -qq --no-install-recommends msodbcsql18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY . /app/context/

ENV NAO_DEFAULT_PROJECT_PATH=/app/context

WORKDIR /app/context
