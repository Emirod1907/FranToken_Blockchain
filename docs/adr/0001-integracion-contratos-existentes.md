# ADR-0001 — Encaje de los contratos existentes con el modelo pendiente

- Estado: PROPUESTA
- Fecha: 2026-10-04
- Responsable: pendiente
- Referencia verificable de aprobación: ninguna
- Decisiones relacionadas: D02–D11, especialmente D03, D05, D06, D08 y D10

## Problema, derechos afectados y restricciones

El repositorio ya contiene `contracts/`, `test/`, `hardhat.config.js` y `scripts/deploy.js`. El setup documental llegó después. El código puede ejecutarse localmente, pero el manual aún deja abiertos el derecho representado, el cierre de aportes, la moneda, la distribución y el estándar. Mantener la implementación como evidencia técnica existente, sin convertir sus parámetros en decisiones económicas aprobadas.

## Comparación con el dominio

| Implementación observada | Discrepancia o condición pendiente | Propuesta para trabajo posterior |
|---|---|---|
| `FranchiseToken` es ERC-20 con interfaz `IERC3643`, registro y módulo de compliance propios. `IdentityRegistry.isVerified` usa registro local y vencimiento de KYC. | D09–D10 no eligen estándar ni fuente de elegibilidad. El registro actual no acredita por sí mismo claims de identidad ni cumplimiento normativo. | Definir derechos, fuente de identidad y restricciones antes de decidir si mantener, sustituir o ampliar estos contratos. |
| `mint` puede ejecutarlo un agente para una wallet verificada; `scripts/deploy.js` fija 10.000 participaciones y valuación ilustrativa de 500.000 unidades con 6 decimales. | No hay vínculo comprobado con suscripción, aporte conciliado, cierre, instrumento o identificador idempotente. D03–D05 y D08 siguen pendientes. | Tratar números del despliegue como fixture local. Diseñar referencia única y precondiciones de emisión después de aprobar reglas. |
| `distributeRevenue` acepta un importe del agente y reparte según saldo al momento del depósito; `claimRevenue` transfiere el token de pago. | La base distribuible, prelación, reservas, impuestos, corte y responsable de aprobación no están definidos (D06). El nombre «revenue/regalías» no determina el derecho del inversor ni equivale a la regalía del franquiciante. | Definir período, corte reproducible, importe habilitado y conciliación de fondos; probar reclamos, residuales y discrepancias contra esas reglas. |
| `AgentRole` y el owner concentran emisión, transferencia forzada, recuperación y cambios de módulos. El despliegue local usa la misma cuenta para varios roles. | D02, D09–D11 no asignan autoridades reales ni procedimiento de revisión y recuperación. Una instancia tiene un token de pago inmutable; no existe separación de fondos de varias emisiones demostrada. | Modelar actores, permisos y aislamiento por emisión antes de conectar fondos o usuarios reales. |
| `setFranchiseInfo` permite URI y hash de documento; el registro guarda wallet, identidad y país en cadena. | Falta decidir qué datos pueden hacerse públicos, quién verifica documentos y cuál registro prevalece. Un hash no prueba el contenido económico ni habilita publicar datos privados. | Acordar política de datos y fuente documental; usar ejemplos sin identidad sensible mientras tanto. |

## Alternativas

1. Conservar el prototipo como banco de pruebas local y cerrar las Dxx antes de ampliar flujos económicos. Permite aprender con el código ya existente, sin asumir validez jurídica.
2. Sustituirlo por un registro convencional o arquitectura híbrida después de comparar privacidad, autoridad, costos, conciliación y verificabilidad.
3. No desarrollar distribución ni captación adicionales hasta que se definan derechos y responsables.

## Evidencia y supuestos

Evidencia interna: `docs/FranToken-manual-consulta.md` §§1, 3–4; `docs/DECISIONS.md`; `contracts/token/FranchiseToken.sol`; `contracts/registry/IdentityRegistry.sol`; `scripts/deploy.js`; `test/FranchiseToken.test.js`. Revisión de archivos y pruebas locales el 2026-10-04. No se hizo auditoría de seguridad ni revisión jurídica o de especificación ERC-3643; no se infiere cumplimiento de la interfaz o el nombre del contrato.

## Decisión propuesta y condición que la cambiaría

Inventariar y conservar el código existente para pruebas locales. No interpretar el despliegue de ejemplo como plantilla de una emisión real. Revisar esta propuesta cuando exista evidencia aprobada de derechos, reglas de fondos, autoridades y elección técnica.

## Consecuencias, requisitos y transición

No refactorizar contratos durante el bootstrap. Antes de uso con valor económico, traducir las decisiones aprobadas a precondiciones y pruebas sobre emisión, transferencias, recuperación, distribución, segregación y conciliación. Registrar una nueva ADR si se escoge o descarta esta arquitectura. Hasta entonces, D01–D12 permanecen PENDIENTES.

## Historial y decisión sustituida

2026-10-04: propuesta inicial de integración; no sustituye una decisión aprobada.
