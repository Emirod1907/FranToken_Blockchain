# FranToken — Tokenización de franquicias (ERC-3643)

Prototipo de token permisionado y acuerdos asociados a una emisión para financiar una franquicia. El derecho del inversor es a ingresos, pero su fórmula, prioridad y condiciones todavía no están definidas. Los pagos al franquiciante se distinguen de las distribuciones al inversor.

## Modelo

1. Se analiza la viabilidad de la franquicia y se crea un fideicomiso.
2. El inversor compra tokens desde la web. Un tercero gestiona el cobro externo y su conciliación; sólo entonces se emiten los tokens.
3. Sobre el precio ilustrativo de USD 10 por token, FranToken recibiría el 0,5 % (USD 0,05) y el fideicomiso USD 9,95. El gas se paga aparte. La liquidación monetaria ocurre fuera de estos contratos.
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
