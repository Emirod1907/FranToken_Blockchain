#!/usr/bin/env bash
# Arranca el validador NODE_ID con el génesis y la clave generados por init-network.sh.
#
# Variables:
#   NODE_ID     número de nodo (1..N)
#   P2P_HOST    IP que el nodo anuncia a sus pares
#   DATA_DIR    carpeta con genesis.json, bootnode y nodeN/ (por defecto /data)
set -euo pipefail

NODE_ID="${NODE_ID:?Falta NODE_ID}"
P2P_HOST="${P2P_HOST:-127.0.0.1}"
DATA_DIR="${DATA_DIR:-/data}"
NODE_DIR="$DATA_DIR/node$NODE_ID"

args=(
  --data-path="$NODE_DIR/data"
  --node-private-key-file="$NODE_DIR/key"
  --genesis-file="$DATA_DIR/genesis.json"
  --sync-mode=FULL
  --p2p-host="$P2P_HOST"
  --p2p-port=30303
  --rpc-http-enabled
  --rpc-http-host=0.0.0.0
  --rpc-http-port=8545
  --rpc-http-api=ETH,NET,WEB3,QBFT,TXPOOL
  --rpc-http-cors-origins="*"
  --host-allowlist="*"
  --min-gas-price=0
)

# El nodo 1 es el punto de encuentro; el resto se conecta a él.
if [ "$NODE_ID" != "1" ]; then
  args+=(--bootnodes="$(cat "$DATA_DIR/bootnode")")
fi

exec besu "${args[@]}"
