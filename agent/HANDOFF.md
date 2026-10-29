# Estado de trabajo

Actualizado: 2026-10-29. Base Git observada: 2a658d0; rama develop.

## Hechos

El setup documental se integró previamente en el repositorio Hardhat. `docs/adr/0001-integracion-contratos-existentes.md` conserva esa revisión como propuesta. El registro de decisiones mantiene D01–D12 pendientes para una operación real.

En la tarea actual, el usuario indicó compra web a USD 10 por token más gas; comisión ilustrativa de FranToken de 0,5 % sobre los USD 10; cobro y conciliación externos por un tercero; emisión posterior a conciliación; derecho del inversor a ingresos sin fórmula; campaña fallida gestionada por ese tercero sin reglas detalladas. Se implementaron `PlatformServicesAgreement` y `InvestmentAgreement`, pruebas, vínculo opcional e irreversible de controlador de emisión en `FranchiseToken`, y despliegue sólo local con datos ficticios. ADR-0002 documenta supuestos y límites. No se modificó `package-lock.json`.

Verificación actual: `npm ci --offline --no-audit --no-fund` completó; `npm test` pasó 49 pruebas; `node --check` de script y prueba nueva pasó; `git diff --check` pasó. No se ejecutó el script de despliegue. Las pruebas no verifican pagos externos, devolución, derecho económico ni seguridad de producción.

## Continuación

Antes de uso real, completar términos de servicios y derechos, autoridades del estudio, mecanismo de conciliación, cierre/devolución y fórmula de distribuciones; revisar D02–D06, D08–D12 y ADR-0002. La misma referencia de pago puede reutilizarse en otra instancia si el conciliador externo no lo impide. El token conserva un reparto técnico sin base económica aprobada y permite transferencias a nuevos titulares sin aceptación de términos del contrato 4. Esta memoria no autoriza despliegues con valor económico.

## Formato para próximas actualizaciones

Objetivo activo; commit/base cuando exista; cambios y rutas; evidencia ejecutada; fallas preexistentes; decisiones aprobadas con referencia; propuestas; bloqueos; siguiente paso concreto. Mantener breve. No guardar secretos, datos personales, razonamiento interno ni afirmaciones de pruebas sin evidencia.
