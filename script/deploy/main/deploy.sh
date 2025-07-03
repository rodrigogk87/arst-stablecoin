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
COLLATERAL_VAR="${NETWORK_UPPER}_COLLATERAL"
PRICE_FEED_VAR="${NETWORK_UPPER}_PRICE_FEED"
ORACLE_VAR="${NETWORK_UPPER}_ORACLE_ADDRESS"

# Obtener valores
RPC_URL=${!RPC_VAR}
COLLATERAL=${!COLLATERAL_VAR}
PRICE_FEED=${!PRICE_FEED_VAR}
ORACLE_ADDRESS=${!ORACLE_VAR}

# Verificar
if [ -z "$RPC_URL" ]; then
  echo "❌ No se encontró $RPC_VAR en .env"
  exit 1
fi
if [ -z "$COLLATERAL" ] || [ -z "$PRICE_FEED" ] || [ -z "$ORACLE_ADDRESS" ]; then
  echo "❌ Faltan COLLATERAL, PRICE_FEED o ORACLE_ADDRESS en .env para $NETWORK"
  exit 1
fi

echo "🚀 Deploying en red: $NETWORK"
echo "🔗 RPC URL: $RPC_URL"
echo "💰 COLLATERAL: $COLLATERAL"
echo "💹 PRICE_FEED: $PRICE_FEED"
echo "🧙 ORACLE_ADDRESS: $ORACLE_ADDRESS"

# Exportar para que forge las lea con vm.envAddress()
export COLLATERAL
export PRICE_FEED
export ORACLE_ADDRESS

# Ejecutar
forge script script/deploy/main/Deploy.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  -vvvv
