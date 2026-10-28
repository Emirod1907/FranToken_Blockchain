# Arquitectura: guía de decisión

Estado: propuesta para la arquitectura futura; el repositorio ya contiene una implementación Solidity/Hardhat, descrita en `agent/repo-config.json`. Su existencia no aprueba red, estándar, derecho ni despliegue real. Conservar el stack existente si no hay un problema demostrado. Véase `docs/adr/0001-integracion-contratos-existentes.md` para las discrepancias detectadas.

## Alternativas a contrastar

| Opción                                   | Beneficio potencial                          | Costo o dependencia                                        |
| ---------------------------------------- | -------------------------------------------- | ---------------------------------------------------------- |
| Aplicación y base de datos con auditoría | Menor complejidad operativa                  | Confianza en administración y continuidad                  |
| Diseño híbrido con blockchain            | Verificación externa de hechos comprometidos | Claves, privacidad, finalización, conciliación y gas       |
| Red permisionada                         | Gobierno compartido entre organizaciones     | Participantes y gobernanza reales, operación del consorcio |

Medir necesidad de verificabilidad, número de organizaciones, carga, presupuesto y amenazas. No atribuir liquidez a ninguna arquitectura. Si no hay evidencia suficiente, mantener un adaptador simulado y una ADR pendiente.

## Límites lógicos propuestos

Identidad/elegibilidad; proyectos/emisiones; suscripciones; cobros/conciliación; registro de derechos; tesorería/hitos; distribuciones; documentos/auditoría. Son límites de responsabilidad, no una orden de crear nueve servicios.

Las reglas de dominio no dependen de componentes visuales, RPC ni SDK bancario. Los casos de uso coordinan; los adaptadores acceden a persistencia y servicios externos. Introducir interfaces en fronteras que necesiten simulación, sustitución o control transaccional. Evitar crear capas vacías por seguir una plantilla.

Definir quién posee cada dato y cómo se detectan discrepancias. La interfaz muestra estados, el backend aplica permisos y el mecanismo de liquidación verifica sus propias precondiciones. Un ledger operativo no sustituye contabilidad legal ni registro jurídico.

## Primera entrega vertical propuesta

En entorno local: emisión ficticia → suscripción → pago simulado → conciliación → asignación simulada de derechos → consulta del inversor. Aceptación: repetición y concurrencia no duplican asignación; otro inversor no puede leerla; otra emisión no puede consumir sus fondos; la interfaz identifica la simulación.

Después: cancelación/devolución, propuesta de distribución con corte reproducible, aprobación y fondeo simulados, reclamo idempotente. Conectar proveedores y blockchain solo tras fijar reglas, responsabilidades y compatibilidad.

## Antes de seleccionar infraestructura

Registrar usuarios y concurrencia esperada, emisiones, picos de operaciones, tamaño de documentos, latencia/finalización, disponibilidad, presupuesto, residencia de datos, recuperación y capacidades del equipo. Usar hipótesis medibles si no hay datos y una condición de revisión. No instalar infraestructura por anticipación especulativa.
