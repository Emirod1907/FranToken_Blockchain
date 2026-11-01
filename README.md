# FranToken — Tokenización de franquicias (ERC-3643)

Prototipo de token permisionado y acuerdos asociados a una emisión para financiar una franquicia. El derecho del inversor es a ingresos; el modelo declara una cascada de pagos, pero su fórmula y parámetros contractuales finales siguen pendientes. Los pagos al franquiciante se distinguen de las distribuciones al inversor.

Documentación vigente: [modelo de negocio](docs/business/BUSINESS-LOGIC.md), [ciclos de vida DTE](docs/business/LIFECYCLES.md), [estado técnico y brechas](docs/business/IMPLEMENTATION-STATUS.md), [decisiones](docs/business/DECISIONS.md) y [fuentes](docs/business/source/README.md).

## Modelo

1. Se analiza la viabilidad de la franquicia y se crea un fideicomiso.
2. El inversor compra tokens desde la web. Un tercero gestiona el cobro externo y su conciliación; sólo entonces se emiten los tokens.
3. El precio de suscripción es **fijo: USD 10 por token más fees de transacción blockchain**, informados por separado. El prototipo calcula un 0,5 % del principal (USD 0,05 y neto USD 9,95), sin cobrarlo: es un supuesto técnico, no una comisión comercial definitiva. La liquidación monetaria de la compra ocurre fuera de estos contratos.
4. Un administrador profesional (operadora) gestiona el local.

| # | Partes | Contrato | Estado |
|---|---|---|---|
| 1 | Franquiciante ↔ Fideicomiso | `agreements/FranchiseAgreement.sol` | Implementado |
| 2 | Fideicomiso ↔ Operadora | `agreements/OperatingAgreement.sol` | Implementado |
| 3 | Fideicomiso ↔ FranToken SAS | `agreements/PlatformServicesAgreement.sol` | Prototipo: firmas y cálculo de comisión; sin cobro on-chain |
| 4 | Fideicomiso / emisor ↔ Inversor | `agreements/InvestmentAgreement.sol` | Prototipo por emisión: aceptación de términos y emisión tras conciliación externa |

Los contratos 3 y 4 no usan `BilateralAgreement`: ese contrato presupone períodos y pagos en un token de pago, mientras que la compra definida para esta etapa se cobra fuera de la cadena. El contrato 3 no se registra como obligación senior: la prioridad de la comisión frente a otros pagos no está definida.

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
| `agreements/PlatformServicesAgreement.sol` | **Contrato 3.** Términos económicos firmados por fideicomiso y FranToken; calcula comisión y neto en unidades mínimas de la moneda configurada. |
| `agreements/InvestmentAgreement.sol` | **Contrato 4.** Términos comunes por emisión, aceptación por wallet y emisión única por compra y referencia de pago tras atestación del conciliador externo. |

## Uso

```bash
npm install
npm run compile
npm test
npx hardhat run scripts/deploy.js                 # red en memoria
npm run node   # en otra terminal
npm run deploy:local
```

`scripts/deploy.js` usa importes y hashes de documentos ficticios y sólo admite redes locales.

### Red local de varios nodos (Hyperledger Besu)

Red Ethereum privada en Docker con 4 validadores Besu y consenso QBFT (tolera 1 nodo caído). Bloques cada 2 s, chain ID 2026. Sirve para ver consenso, propagación y latencia reales con los mismos contratos; no es la elección de red de producción (decisión D10 pendiente).

```bash
npm run besu:up        # genera génesis y claves la primera vez y levanta los 4 nodos
npm run besu:status    # bloque, pares y validadores de cada nodo
npm run deploy:besu    # despliega los contratos en la red Besu
npm run besu:logs      # ver los logs
npm run besu:down      # detener (conserva la cadena)
npm run besu:reset     # borrar la red completa (bloques, génesis y claves)
```

- RPC en el host: nodo 1 en `http://127.0.0.1:18545`, nodos 2–4 en 18546–18548.
- Las claves de los validadores se generan dentro del volumen de Docker y no se guardan en el repositorio. Las cuentas que despliegan son las de prueba públicas de Hardhat, con 1.000 ETH de prueba cada una en el génesis: no sirven fuera de esta red.
- Variante de un nodo para Railway: `infra/besu/Dockerfile.railway` (Root Directory `infra/besu`, `RAILWAY_DOCKERFILE_PATH=Dockerfile.railway` y un volumen en `/data`). El backend la usa por red privada en `http://<servicio>.railway.internal:8545`.

## Flujo operativo

1. El agente KYC registra inversores: `registry.registerIdentity(wallet, onchainId, pais)`.
2. Las partes del contrato 3 firman con `services.sign()`; el inversor acepta los términos del contrato 4 con `investment.acceptTerms()`.
3. El proveedor externo cobra y concilia USD 10 por token, sin incluir gas. Su wallet autorizada llama `investment.issueAfterPayment(purchaseId, paymentReference, inversor, cantidad, importeEnCentavos, evidenceHash)`.
4. El contrato 4 comprueba importe, aceptación y unicidad, y llama `token.mint`. La comisión de FranToken y el neto del fideicomiso quedan registrados en `PurchaseIssued` para conciliación externa; la transferencia de dinero no ocurre on-chain.
5. El reparto actual del token (`distributeRevenue` / `claimRevenue`) es un mecanismo técnico existente. Aún necesita reglas aprobadas de ingresos distribuibles, corte, reservas y pagos antes de representar el derecho económico real.

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
- Los contratos 3 y 4 no custodian aportes ni ejecutan devoluciones. El tratamiento de una campaña fallida corresponde al tercero y a términos todavía no definidos.
- El verificador externo es la fuente de la atestación de pago; una referencia y un hash en cadena no demuestran por sí solos que hubo cobro final o reparto monetario. La misma referencia de pago no puede reutilizarse dentro de una instancia del contrato 4; la unicidad entre emisiones depende del conciliador externo.
- El contrato 4 no define fórmula ni calendario del derecho a ingresos. La aceptación inicial por wallet no impone por sí sola aceptación de términos a un adquirente posterior del token.
- En este flujo el verificador paga el gas de la transacción de emisión; cualquier cargo de red al comprador se liquida externamente y no está calculado ni cobrado por los contratos.
