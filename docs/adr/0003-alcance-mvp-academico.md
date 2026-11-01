# ADR-0003 — Alcance académico de compra e ingresos periódicos

- Estado: **APROBADA para el alcance del MVP; implementación pendiente**.
- Fecha: 2026-11-01.
- Responsable de la definición: usuario del proyecto.
- Evidencia de aprobación: [confirmación explícita y definiciones MVP-01–MVP-06](../business/MVP-ACADEMICO.md#fuente-autoridad-y-límites).
- Decisiones relacionadas: D03, D04, D06, D08, D09 y D10, resueltas solo para la demostración; las decisiones para valor real permanecen abiertas.

## Problema y restricciones

El modelo completo exige estructuración, vehículo, campañas, conciliación externa, operación, cascada de pagos y liquidación. Esa automatización excede el objetivo académico confirmado: un usuario compra el token de una franquicia publicada y luego cobra ingresos periódicos. La documentación debe delimitar un recorrido funcional comprobable, sin convertir una simulación en operación comercial ni afirmar funciones ya implementadas.

La instrucción actual autoriza actualizar documentación y subir una rama en frontend y blockchain. No se cambian contratos, deploys, configuración de redes, pruebas ni servicios. El backend deberá integrar posteriormente las necesidades documentadas, pero no forma parte de esta modificación.

## Alternativas consideradas

| Alternativa | Evaluación para esta etapa |
|---|---|
| Automatizar el modelo completo | Conserva la meta futura, pero agrega proveedores, parámetros económicos y procesos que no hacen falta para demostrar compra/cobro. Fuera del MVP. |
| Demostración solo con registros convencionales o datos fijos | Más sencilla, pero no demuestra emisión y reclamo on-chain, que forman parte del objetivo confirmado. |
| Pago simulado y contratos existentes en Hardhat local | **Elegida por el usuario.** Permite demostrar emisión, asignación y cobro con activos de prueba y operación manual. Requiere completar integración y controles mínimos. |

## Decisión aprobada

1. Mantener el precio de referencia USD 10 y gas separado; simular el pago de compra y usar C4 para emitir una vez por referencia.
2. Usar Hardhat local y el token de pago de prueba. Besu ya disponible es una alternativa previa, no la red base elegida para esta entrega. No se selecciona red pública ni de producción.
3. El administrador marca la franquicia en operación y carga/fondea ingresos de períodos mensuales; los meses pueden simularse en la presentación.
4. Repartir a prorrata de los tokens en circulación al ejecutar distributeRevenue. El titular reclama el saldo con claimRevenue; no se requiere snapshot previo, retorno fijo, distribución automática por reloj ni retiro separado por mes.
5. Deshabilitar transferencias entre inversores, incluyendo transfer y transferFrom on-chain, sin bloquear la emisión y el reclamo. El código actual permite transferir: falta implementar esta restricción.
6. Conservar C1–C3 como demostración/contexto. Satisfacer con firmas de prueba la dependencia actual de C4 respecto de C3 activo; no exigir el circuito jurídico y contable completo para comprar/cobrar. La comisión de 0,5 % sigue siendo un ejemplo, no una tasa comercial definitiva.

## Actores, estados, amenazas e invariantes

El [MVP común](../business/MVP-ACADEMICO.md#actores-y-recorrido-mínimo) identifica inversor, administrador y verificador de pago simulado; documenta estados de franquicia, compra, distribución y reclamo. No se requieren instituciones o proveedores reales para ocupar las funciones demo.

| Amenaza | Control mínimo de la implementación futura |
|---|---|
| Pago simulado o emisión repetidos | Persistir compra y referencia única; C4 configurado como emisor exclusivo; consultar/reintentar la misma operación. |
| Distribución del mismo mes repetida | Identificar franquicia/emisión y período mensual, con unicidad antes de enviar y recuperación ante respuesta perdida. |
| Cobro repetido o sin fondos | Fondear y confirmar asignación; usar el saldo reclamable y la protección de reclamo del contrato. |
| Compra/ingreso sobre otro proyecto | Vincular contratos y referencias al proyecto correcto y autorizar por objeto. |
| Transferir por fuera de la UI | Bloquear rutas ordinarias directas y delegadas on-chain. No usar recuperación o transferencia forzada como mercado secundario de la demo. |
| Pausa interpretada como bloqueo universal | Documentar y verificar por operación el alcance de pausa del token y C4; conservar derechos ya asignados. |

Invariantes: una compra emite una vez; un período de una franquicia se acredita una vez; reclamado no supera lo asignado; el fondeo disponible respalda los reclamos; comprar después no recibe ingresos anteriores; usuario y administrador no comparten facultades por defecto. El uso de enteros/unidades mínimas y decimales explícitos se mantiene.

## Consecuencias, verificación y transición

La implementación futura debe completar compra web/API → pago simulado → aceptación/habilitación demo → C4 → tenencia on-chain → operación → distribución mensual → reclamo. La aceptación se define en [criterios comunes](../business/MVP-ACADEMICO.md#controles-mínimos-y-criterios-de-aceptación); no se agregan pruebas de producto en esta tarea documental.

Las campañas con devolución, liquidación del vehículo, cascada completa, impuestos, reservas, KYC real y automatización de balances quedan fuera. Sus defectos/pendientes históricos se conservan, pero no obligan a desarrollar subsistemas que no participan del recorrido aprobado. Los controles de funciones efectivamente usadas sí deben ser coherentes.

Una nueva decisión será necesaria si se habilitan dinero real, transferencia secundaria, otro corte de titulares, rentabilidad fija, una red distinta o liquidación económica. Este ADR no acredita preparación de producción.

## Historial y decisiones sustituidas

Esta decisión delimita el alcance académico respecto del modelo completo y sus DTE; no reescribe fuentes ni cierra las D01–D12 para operación real. ADR-0001 y ADR-0002 permanecen como antecedentes con sus estados originales. La documentación de alcance aprobado prevalece sobre sus supuestos abiertos exclusivamente dentro del MVP.
