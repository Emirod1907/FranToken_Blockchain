#!/usr/bin/env bash
# Genera (una sola vez) el génesis QBFT y las claves de los validadores en $DATA_DIR.
# Las claves se crean dentro del volumen de Docker: nunca se guardan en el repositorio.
#
# Variables:
#   NODE_COUNT    cantidad de validadores (por defecto 4)
#   BOOTNODE_IP   IP con la que los demás nodos encuentran al nodo 1 (por defecto 127.0.0.1)
#   DATA_DIR      carpeta de salida (por defecto /data)
set -euo pipefail

NODE_COUNT="${NODE_COUNT:-4}"
BOOTNODE_IP="${BOOTNODE_IP:-127.0.0.1}"
DATA_DIR="${DATA_DIR:-/data}"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-/besu-config/qbftConfigFile.json}"

if [ -f "$DATA_DIR/genesis.json" ]; then
  echo "Red ya inicializada en $DATA_DIR: se reutilizan génesis y claves."
  exit 0
fi

work="$(mktemp -d)"
sed -E "s/\"count\": *[0-9]+/\"count\": $NODE_COUNT/" "$CONFIG_TEMPLATE" > "$work/qbftConfigFile.json"
besu operator generate-blockchain-config \
  --config-file="$work/qbftConfigFile.json" \
  --to="$work/networkFiles" \
  --private-key-file-name=key

mkdir -p "$DATA_DIR"
i=1
for keydir in "$work"/networkFiles/keys/*/; do
  mkdir -p "$DATA_DIR/node$i"
  cp "$keydir/key" "$keydir/key.pub" "$DATA_DIR/node$i/"
  i=$((i + 1))
done

pub="$(cat "$DATA_DIR/node1/key.pub")"
echo "enode://${pub#0x}@${BOOTNODE_IP}:30303" > "$DATA_DIR/bootnode"
cp "$work/networkFiles/genesis.json" "$DATA_DIR/genesis.json"

# Los nodos corren con el usuario sin privilegios de la imagen.
if id besu > /dev/null 2>&1; then chown -R besu:besu "$DATA_DIR"; fi
rm -rf "$work"
echo "Red inicializada: $NODE_COUNT validador(es). Bootnode: $(cat "$DATA_DIR/bootnode")"
