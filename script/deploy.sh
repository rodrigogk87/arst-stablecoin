#!/bin/bash

# Cargar variables de entorno desde .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ No se encontró archivo .env"
  exit 1
fi

# Verificar que SEPOLIA_RPC_URL esté definido
if [ -z "$SEPOLIA_RPC_URL" ]; then
  echo "❌ Falta la variable SEPOLIA_RPC_URL en el .env"
  exit 1
fi

# Ejecutar el deployment con Foundry
forge script script/Deploy.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --broadcast \
  --verify \
  -vvvv
