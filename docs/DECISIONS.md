# Registro de decisiones

Actualizado: 2026-10-29. Estado de todos los D01–D12: PENDIENTE para operación real. Responsable de decisión y evidencia de aprobación: no designados.

| ID | Pendiente | Bloquea en operación real |
|---|---|---|
| D01 | Jurisdicciones y residencia de inversores | Encuadre y reglas de admisión/oferta |
| D02 | Tipo de fideicomiso, partes y contratos | Autoridades y obligaciones |
| D03 | Derecho representado | Instrumento, cálculo y token |
| D04 | Denominador del porcentaje | Asignación y comunicación económica |
| D05 | Meta, mínimos, máximos, plazo, excedentes | Cierre, sobrecaptación y devolución |
| D06 | Base de reparto, prioridades, reservas, impuestos | Cálculo y habilitación de pagos |
| D07 | Franquiciante, operador y consentimientos | Operación y cesiones |
| D08 | Moneda, cobro, conversión y custodia | Integraciones y disponibilidad |
| D09 | Transferencia, rescate, recuperación, sucesión | Movimiento de derechos |
| D10 | Red, estándar, administración y upgrades | Contratos y despliegue |
| D11 | Unidades, emisiones y carteras | Segregación y autorización |
| D12 | Comisiones y destinatarios | Tesorería y conflictos |

## Propuestas de ingeniería de este paquete

| ID | Propuesta | Estado | Condición de revisión |
|---|---|---|---|
| S01 | Entrada AGENTS.md y guías bajo demanda | PROPUESTA | Compatibilidad con herramienta y tamaño del repo |
| S02 | Un ejecutor como modo base | PROPUESTA | Necesidad explícita de revisión independiente o trabajo paralelo |
| S03 | Evaluar primero monolito modular y adaptadores | PROPUESTA | Escala, aislamiento, equipo y requisitos operativos |
| S04 | Usar simulaciones para dependencias sin decisión | PROPUESTA | Validación de reglas y proveedores |

Agregar decisiones mediante ADR con problema, alternativas, evidencia, decisión, estado, responsable, aprobación explícita y consecuencias. Los agentes pueden redactar propuestas; no pueden autoaprobar derechos económicos ni usar el silencio como aceptación. Registrar sustituciones y conservar el historial.

## Información nueva de producto, sin cierre de las Dxx

El usuario indicó el 2026-10-29 que la compra se haría en la web por un precio propuesto de USD 10 por token más gas; un tercero gestionaría el cobro externo y su conciliación, tras la cual se emitiría el token. FranToken recibiría 0,5 % de los USD 10 como supuesto provisional y el neto correspondería al fideicomiso. El inversor recibiría ingresos, todavía sin fórmula económica. El tercero gestionaría la campaña fallida, pero no se definieron condiciones de cierre o devolución. Se mantiene el estado PENDIENTE de D02–D06, D08 y D12 para la operación real; el prototipo local sólo parametriza el flujo descrito. Véase ADR-0002.
