# API, datos e integraciones

## Autorización y aislamiento

Autenticar al actor y autorizar cada acción por objeto y emisión. Aplicar filtros de acceso en el servidor; no confiar en emissionId/investorId enviados por el cliente. Separar proponer, aprobar, ejecutar y conciliar donde el riesgo lo requiera. Probar IDs válidos pertenecientes a otro usuario/emisión.

## Consistencia financiera

- Mantener hechos de cobro, asientos, asignaciones de derechos y salidas separados y vinculados mediante referencias estables.
- Para ledger contable interno, definir cuentas, activo y regla de balance; no editar asientos confirmados: usar correcciones trazables. No sumar monedas distintas para afirmar balance.
- Una clave idempotente requiere alcance, unicidad persistida y semántica: misma clave/mismo payload recupera el resultado; misma clave/payload diferente es conflicto. Un flag en memoria no cubre concurrencia ni reinicios.
- Usar restricciones de base de datos y transacciones para efectos locales; controlar versión/bloqueo cuando compitan cancelación, cierre o reserva. Diseñar límites temporales y reintentos.
- Entre base y proveedor externo no asumir atomicidad: persistir intención, estado de envío, referencia externa y conciliación. Evaluar outbox/inbox cuando resuelva pérdida de eventos; entrega repetida es esperable.
- Verificar autenticidad de webhooks según documentación vigente del proveedor, incluyendo cuerpo original y antirreplay si aplica. Un evento firmado tampoco sustituye conciliación con la operación correcta.
- Ante timeout de un pago, consultar estado antes de reenviar con una referencia nueva. Mantener UNKNOWN/PENDING con reconciliación; no convertir incertidumbre en fallo definitivo ni pago exitoso.

## Auditoría y operación

Registrar actor, emisión, transición, regla/versionado, timestamp y referencia de evidencia; limitar acceso y retención. No loguear documentos KYC ni credenciales. Diseñar paginación, límites y backpressure para cargas reales. Separar simuladores y credenciales de prueba de proveedores reales.

Antes de conectar fondos reales: confirmar D01–D09 y D11–D12 relevantes, reconciliación operativa, responsables y procedimiento de incidentes. Se puede implementar infraestructura desacoplada mientras esas decisiones sigan abiertas, sin habilitar captación.
