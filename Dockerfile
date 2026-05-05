FROM getnao/nao:latest

COPY . /app/context/

ENV NAO_DEFAULT_PROJECT_PATH=/app/context

WORKDIR /app/context
