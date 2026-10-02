# FranToken — Tokenización de franquicias (ERC-3643)

Security token permisionado basado en ERC-3643 (T-REX) que representa participaciones en una franquicia, con reparto de regalías en stablecoin.

## Contratos

| Contrato | Función |
|---|---|
| `token/FranchiseToken.sol` | Token ERC-3643: emisión, quema, congelamiento, transferencias forzadas, recuperación de wallets, pausa, operaciones en lote, datos de la franquicia y reparto de ingresos. |
| `registry/IdentityRegistry.sol` | Inversores verificados (wallet → ONCHAINID + país + vencimiento de KYC). |
| `compliance/FranchiseCompliance.sol` | Reglas: máximo de inversores, tenencia máxima, países bloqueados, lock-up. |
| `roles/AgentRole.sol` | Owner + agentes autorizados. |
| `mocks/MockStablecoin.sol` | USDC de prueba (sólo local/tests). |

## Uso

```bash
npm install
npm run compile
npm test
npx hardhat run scripts/deploy.js                 # red en memoria
npm run node   # en otra terminal
npm run deploy:local
```

Para Sepolia define `SEPOLIA_RPC_URL`, `PRIVATE_KEY` y `PAYMENT_TOKEN`, y ejecuta
`npx hardhat run scripts/deploy.js --network sepolia`.

## Flujo operativo

1. El agente KYC registra inversores: `registry.registerIdentity(wallet, onchainId, pais)`.
2. El agente emite participaciones: `token.mint(inversor, cantidad)`.
3. La franquicia deposita regalías: `stablecoin.approve(token, x)` + `token.distributeRevenue(x, "Enero")`.
4. Cada inversor reclama: `token.claimRevenue()`.

## Limitaciones conocidas

- El `IdentityRegistry` es simplificado: el agente es la fuente de verdad del KYC. El T-REX completo verifica claims de ONCHAINID firmados por emisores de confianza (`ClaimTopicsRegistry` + `TrustedIssuersRegistry`). Para producción considera `@tokenysolutions/t-rex` + `@onchain-id/solidity`.
- Contratos no actualizables (sin proxy).
- Los tokens congelados siguen generando ingresos; las wallets congeladas no pueden reclamarlos hasta ser descongeladas.
- No auditado. Requiere auditoría y revisión legal antes de usarse con valores reales.
