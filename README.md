# FranToken — Tokenización de franquicias (ERC-3643)

Versión 1.0 · 2026-10-04 · Idioma de trabajo: español.

Security token permisionado basado en ERC-3643 (T-REX) que representa participaciones en una franquicia, con reparto de regalías en stablecoin.

Conserva contexto, decisiones pendientes y evidencia de verificación; no configura un runtime autónomo. El código existente es un prototipo y sus supuestos económicos y técnicos no están aprobados por el manual.

## Contratos

| Contrato                             | Función                                                                                                                                                                    |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `token/FranchiseToken.sol`           | Token ERC-3643: emisión, quema, congelamiento, transferencias forzadas, recuperación de wallets, pausa, operaciones en lote, datos de la franquicia y reparto de ingresos. |
| `registry/IdentityRegistry.sol`      | Inversores verificados (wallet → ONCHAINID + país + vencimiento de KYC).                                                                                                   |
| `compliance/FranchiseCompliance.sol` | Reglas: máximo de inversores, tenencia máxima, países bloqueados, lock-up.                                                                                                 |
| `roles/AgentRole.sol`                | Owner + agentes autorizados.                                                                                                                                               |
| `mocks/MockStablecoin.sol`           | USDC de prueba (sólo local/tests).                                                                                                                                         |

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

## Qué incluye

| Archivo                                      | Función                                                   |
| -------------------------------------------- | --------------------------------------------------------- |
| `AGENTS.md`                                  | Entrada breve, reglas universales y selección de contexto |
| `docs/FranToken-manual-consulta.md`          | Copia íntegra del manual recibido; fuente documental      |
| `docs/PROJECT.md`                            | Resumen operativo y límites del dominio                   |
| `docs/DECISIONS.md`                          | D01–D12 pendientes y decisiones del setup propuestas      |
| `docs/ARCHITECTURE.md`                       | Opciones, límites modulares y ruta de implementación      |
| `agent/CODING.md`                            | Reglas de código independientes del framework             |
| `agent/FRONTEND.md`                          | Interfaces, estados, accesibilidad y precisión            |
| `agent/BACKEND.md`                           | Autorización, dinero, transacciones e integraciones       |
| `agent/BLOCKCHAIN.md`                        | Contratos, registro, finalización y controles             |
| `agent/BUSINESS.md`                          | Derechos, evidencia y conexión con implementación         |
| `agent/SECURITY.md`                          | Permisos del agente y amenazas del producto               |
| `agent/QUALITY.md`                           | Pruebas por riesgo y criterios de cierre                  |
| `agent/BOOTSTRAP.md`                         | Primer encargo ejecutable por un agente                   |
| `agent/repo-config.json`                     | Rutas, stack, comandos y línea base descubiertos          |
| `agent/TASK-TEMPLATE.md`, `agent/HANDOFF.md` | Alcance y memoria durable                                 |
| `docs/adr/TEMPLATE.md`                       | Registro de decisiones con estado y aprobación            |
| `agent/EVALUATION.md`                        | Casos para evaluar conducta del agente                    |
| `scripts/validate_setup.py`                  | Comprobación local sin dependencias externas              |

## Diseño y mantenimiento

Un agente ejecutor es el modo base. Las guías son lentes de trabajo que puede aplicar el mismo agente; no son procesos simultáneos, skills instaladas ni un sistema multiagente. Una revisión separada se justifica por riesgo o tamaño y requiere que la tarea y el entorno habiliten delegación. No asignar varios agentes al mismo archivo sin partición y coordinación.

Cargar siempre el resumen y las decisiones; leer solo las guías necesarias. Volver al manual para resolver matices. Evitar copiar el manual completo en cada tarea. Mantener memoria con rutas, decisiones y evidencia; no almacenar cadenas de razonamiento, secretos ni transcripciones extensas.

Actualizar PROJECT cuando cambie un dato aprobado, DECISIONS cuando se resuelva una decisión, repo-config cuando cambie un comando verificado y HANDOFF al interrumpir trabajo relevante. Mantener propuestas separadas de aprobaciones. Revisar las instrucciones cuando un error se repita; eliminar duplicación antes de agregar reglas.

El código existente usa Hardhat, Solidity 0.8.24 y una implementación propia que se presenta como ERC-3643. Su presencia no resuelve D01–D12 ni autoriza su uso en una oferta real. No hay frontend, backend, contratos de captación ni configuración de producción verificados. Las discrepancias de dominio están registradas en `docs/adr/0001-integracion-contratos-existentes.md`.

## Evidencia y límites de entrega

Base documental: manual v1.0 del 02-10-2026. El repositorio y sus pruebas locales se inspeccionaron durante el bootstrap; resultados y límites en `VERIFICATION.md`. No se validó una operación jurídica o financiera.

Referencia de integración: [guía oficial de AGENTS.md](https://developers.openai.com/codex/guides/agents-md/), consultada el 04-10-2026. La carga real debe verificarse en la herramienta instalada. Este paquete no modifica permisos del runtime.
