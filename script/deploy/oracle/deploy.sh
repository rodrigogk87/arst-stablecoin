#!/bin/bash

# Cargar .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ No se encontró archivo .env"
  exit 1
fi

# Verificar que pasaste la red
if [ -z "$1" ]; then
  echo "❌ Debes pasar la red como argumento. Ej: ./deploy.sh sepolia"
  exit 1
fi

NETWORK=$1
NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')

# Construir nombres de variables
RPC_VAR="${NETWORK_UPPER}_RPC_URL"

# Obtener valores
RPC_URL=${!RPC_VAR}

# Verificar
if [ -z "$RPC_URL" ]; then
  echo "❌ No se encontró $RPC_VAR en .env"
  exit 1
fi

echo "🚀 Deploying en red: $NETWORK"
echo "🔗 RPC URL: $RPC_URL"


# Ejecutar
forge script script/deploy/oracle/DeployOracle.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  -vvvv
