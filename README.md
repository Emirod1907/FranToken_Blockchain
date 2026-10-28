# FranToken — Tokenización de franquicias (ERC-3643)

Security token permisionado basado en ERC-3643 (T-REX) que representa participaciones en una franquicia, con reparto de regalías en stablecoin, y los contratos que vinculan al fideicomiso con el franquiciante y con la operadora.

## Modelo

1. Se analiza la viabilidad de la franquicia y se crea un fideicomiso.
2. El fideicomiso vende los tokens y con lo recaudado compra la franquicia.
3. FranToken SAS cobra comisión por la gestión y por la ganancia generada.
4. Un administrador profesional (operadora) gestiona el local.

| # | Partes | Contrato | Estado |
|---|---|---|---|
| 1 | Franquiciante ↔ Fideicomiso | `agreements/FranchiseAgreement.sol` | Implementado |
| 2 | Fideicomiso ↔ Operadora | `agreements/OperatingAgreement.sol` | Implementado |
| 3 | Fideicomiso ↔ FranToken SAS | Contrato de servicios y honorarios | Pendiente (Martín) |
| 4 | Fideicomiso / emisor ↔ Inversor | Documentación de inversión (usa `FranchiseToken`) | Pendiente (Martín) |

Los contratos 3 y 4 pueden reutilizar `BilateralAgreement` (firmas, vigencia, cláusulas, incumplimientos y terminación). Si generan pagos senior a los inversores, implementan `IPaymentObligation` y se registran en el token con `addSeniorObligation`.

## Contratos

| Contrato | Función |
|---|---|
| `token/FranchiseToken.sol` | Token ERC-3643: emisión, quema, congelamiento, transferencias forzadas, recuperación de wallets, pausa, operaciones en lote, datos de la franquicia y reparto de ingresos. |
| `registry/IdentityRegistry.sol` | Inversores verificados (wallet → ONCHAINID + país + vencimiento de KYC). |
| `compliance/FranchiseCompliance.sol` | Reglas: máximo de inversores, tenencia máxima, países bloqueados, lock-up. |
| `roles/AgentRole.sol` | Owner + agentes autorizados. |
| `mocks/MockStablecoin.sol` | USDC de prueba (sólo local/tests). |
| `agreements/BilateralAgreement.sol` | Base común: firma de una versión de los términos, vigencia, renovación, cláusulas, períodos de liquidación, notificación de incumplimiento con plazo de subsanación y terminación. |
| `agreements/FranchiseAgreement.sol` | **Contrato 1.** Uso de marca, know-how versionado, territorio, duración, canon de entrada, regalía y fondo de publicidad, estándares con inspecciones y causales de terminación. |
| `agreements/OperatingAgreement.sol` | **Contrato 2.** Local y seguro, reportes de ventas/costos/personal, KPIs, proveedores y compras, honorarios (fijo + éxito), auditorías y causales de terminación. |

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

### Contratos 1 y 2

1. Se despliegan en borrador. Mientras tanto las partes pueden agregar cláusulas (`addClause`) o cambiar el documento legal; cada cambio sube `termsVersion`.
2. Cada parte firma la versión vigente (`sign(termsVersion)`) y una de ellas llama `activate()`. En el contrato 1 se cobra el canon de entrada.
3. Cada período (mensual en el ejemplo):
   - Contrato 1: el fideicomiso (o un delegado vía `setSalesReporter`) reporta ventas con `reportSales` y paga con `payRoyalty`.
   - Contrato 2: la operadora presenta `submitReport`. El fideicomiso lo aprueba, lo observa dentro del plazo de revisión o lo deja aprobar tácitamente. Después paga con `payFees`.
4. Mientras haya regalías u honorarios vencidos, `token.distributeRevenue` revierte: los inversores cobran después.
5. Ante un incumplimiento: `notifyBreach(causal, evidencia)` → plazo de subsanación → `terminateForCause(id)`. Las causales verificables on-chain (pagos vencidos, reportes atrasados, KPIs, inspección o auditoría reprobada, franquicia terminada) sólo se pueden invocar y ejecutar si el incumplimiento existe y persiste.

## Limitaciones conocidas

- El `IdentityRegistry` es simplificado: el agente es la fuente de verdad del KYC. El T-REX completo verifica claims de ONCHAINID firmados por emisores de confianza (`ClaimTopicsRegistry` + `TrustedIssuersRegistry`). Para producción considera `@tokenysolutions/t-rex` + `@onchain-id/solidity`.
- Contratos no actualizables (sin proxy).
- Los tokens congelados siguen generando ingresos; las wallets congeladas no pueden reclamarlos hasta ser descongeladas.
- Los contratos 1 y 2 registran on-chain términos, reportes y pagos; el texto legal vinculante es el documento cuyo hash firman las partes. Las causales no verificables on-chain (uso indebido de marca, mala conducta, etc.) se resuelven fuera de la cadena.
- No auditado. Requiere auditoría y revisión legal antes de usarse con valores reales.
