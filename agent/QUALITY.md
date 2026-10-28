# Calidad y criterios de cierre

Seleccionar verificaciones por riesgo y diff. No exigir suites enormes para un cambio editorial ni omitir integración en movimientos financieros.

| Cambio | Verificación mínima pertinente |
|---|---|
| Documentación | Consistencia, enlaces/rutas y distinción propuesta/aprobación |
| Componente visual | Tipos/lint del alcance, estados relevantes y revisión de interacción |
| Regla de negocio | Casos normales, límites y rechazos |
| Persistencia/pagos | Integración real de persistencia, unicidad/concurrencia, reintentos y recuperación |
| Permisos | Casos negativos por actor/objeto/emisión |
| Distribución/contrato | Invariantes, fuzzing según riesgo, integración y flujo crítico |
| Migración/despliegue | Ensayo, compatibilidad, recuperación y evidencia del entorno |

## Invariantes del dominio

- INV01: un hecho de aporte autorizado no genera asignaciones duplicadas.
- INV02: no hay emisión definitiva con pago no confirmado o derecho no constituido conforme a las reglas.
- INV03: reclamado por beneficiario/período no excede lo neto asignado.
- INV04: pagos y reservas no permiten consumir más fondos disponibles del ámbito y activo correspondientes.
- INV05: fondos y permisos de A no habilitan operaciones de B.
- INV06: las rutas alternativas no eluden restricciones de elegibilidad y transferencia.
- INV07: cancelación/cierre concurrentes no liberan a obra fondos que deben devolverse.
- INV08: el corte de titulares y reglas no se recalcula silenciosamente con saldos actuales.
- INV09: redondeos/residuales preservan totales y nunca mezclan activos.
- INV10: eventos duplicados, fuera de orden, reorg o timeout no se convierten silenciosamente en hechos finales.

Incluir límites: cero, máximo admitido, decimales diferentes, payload conflictivo, firma inválida, titular de otra emisión y pago confirmado con respuesta perdida. Los mocks permiten fallas controladas; no prueban por sí solos transacciones y restricciones de una base real.

## Cierre

Comandos ejecutados y resultados; archivos y comportamiento cambiados; invariantes verificadas; comprobaciones omitidas y motivo; incertidumbre restante. No inventar porcentajes de cobertura. Si una prueba necesaria no pudo ejecutarse, clasificar la entrega como parcialmente verificada.

Antes de cerrar: revisar diff por secretos/datos sensibles, permisos omitidos, migraciones incompatibles y cambios ajenos. Corregir únicamente lo relacionado con el alcance salvo bloqueo real.

El validador del setup solo revisa estructura/configuración. No sustituye estos controles ni evalúa obediencia del modelo.
