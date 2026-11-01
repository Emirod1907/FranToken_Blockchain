/**
 * Muestra el estado de la red Besu local: altura de bloque, pares conectados y
 * validadores QBFT de cada nodo. Sirve para comprobar que los 4 nodos están en consenso.
 *
 *   npm run besu:status
 *
 * BESU_RPC_URLS permite indicar otras URLs separadas por coma.
 */
const DEFAULT_URLS = [18545, 18546, 18547, 18548].map((port) => `http://127.0.0.1:${port}`);
const urls = process.env.BESU_RPC_URLS ? process.env.BESU_RPC_URLS.split(",") : DEFAULT_URLS;

async function rpc(url, method, params = []) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
    signal: AbortSignal.timeout(20000),
  });
  const body = await response.json();
  if (body.error) throw new Error(body.error.message);
  return body.result;
}

async function nodeStatus(url) {
  try {
    const [block, peers, validators] = await Promise.all([
      rpc(url, "eth_getBlockByNumber", ["latest", false]),
      rpc(url, "net_peerCount"),
      rpc(url, "qbft_getValidatorsByBlockNumber", ["latest"]),
    ]);
    return {
      nodo: url,
      bloque: BigInt(block.number).toString(),
      hash: `${block.hash.slice(0, 10)}…`,
      pares: Number(BigInt(peers)),
      validadores: validators.length,
    };
  } catch (error) {
    return { nodo: url, error: error.cause?.code ?? error.message };
  }
}

async function main() {
  const statuses = await Promise.all(urls.map(nodeStatus));
  console.table(statuses);

  const ok = statuses.filter((s) => !s.error);
  if (ok.length === 0) {
    console.log("Ningún nodo responde. ¿Está levantada la red? npm run besu:up");
    process.exitCode = 1;
    return;
  }
  const chainId = BigInt(await rpc(urls[0], "eth_chainId")).toString();
  console.log(`Chain ID: ${chainId} · nodos respondiendo: ${ok.length}/${statuses.length}`);
}

main();
