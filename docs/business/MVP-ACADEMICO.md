# MVP académico de FranToken — alcance confirmado

Fecha: 2026-11-01. Estado: **APROBADO; recorrido implementado en las ramas `feat/academic-mvp`**. Esta especificación es común al frontend y blockchain. Para el estado del código, consultar [implementación y brechas](IMPLEMENTATION-STATUS.md).

## Fuente, autoridad y límites

La fuente es la confirmación explícita del usuario en la conversación de revisión de negocio: «Confirmo las definiciones, pero aún no implementes nada, quiero que actualices la documentación de frontend y blockchain con estas definiciones». Confirma las seis definiciones propuestas en la tabla siguiente y autoriza esta actualización documental y su publicación en ramas. Esa instrucción limitaba la tarea anterior a documentación. La instrucción posterior del usuario del 2026-11-01, «Procedé a implemntar los cambios necesarios en Frontend y Blockchain. Todos los cambios deben partir desde develop a una rama nueva», autoriza la implementación actual y sus verificaciones locales, sin dinero real.

Esta decisión tiene precedencia para el alcance académico sobre los requisitos del modelo completo en [BUSINESS-LOGIC.md](BUSINESS-LOGIC.md), los [DTE](LIFECYCLES.md), los manuales y las propuestas anteriores. Conserva esos antecedentes y sus pendientes para una operación real; no los convierte en requisitos de entrega del MVP. El repositorio backend separado no se modifica: el MVP usa un coordinador de pago simulado en rutas de servidor de Next.js, con firma de wallet y contratos como registro de resultados. No requiere banco ni un servicio externo.

## Definiciones aprobadas

| ID | Definición | Regla del MVP |
|---|---|---|
| MVP-01 | Pago de la compra | Simulado: confirmar una compra de prueba y emitir tokens en la blockchain local. No hay cobro bancario ni dinero real. |
| MVP-02 | Inicio de ingresos | El administrador marca la franquicia como **en operación**. Desde ese momento puede registrar distribuciones. |
| MVP-03 | Periodicidad e importe | Períodos **mensuales**; el administrador carga manualmente el importe distribuible. Se pueden simular meses para la presentación. |
| MVP-04 | Reparto y cobro | Prorrata según tokens en circulación al ejecutar la distribución. Cada inversor reclama su saldo disponible. Sin rentabilidad fija garantizada. |
| MVP-05 | Transferencias | Deshabilitadas entre inversores durante el MVP. El recorrido se concentra en comprar y cobrar. |
| MVP-06 | Red y activo | **Hardhat local** y un token de pago de prueba para fondear y cobrar ingresos. Una red pública de prueba requeriría otra decisión. |

El precio de suscripción se mantiene en **USD 10 por token**, con fees de red separados. USD es la unidad de referencia del precio simulado; el token de pago de prueba no demuestra paridad ni conversión con dólares. El gas local se paga con activo de prueba y se identifica como tal; no se agrega al principal ni al rendimiento. Esta confirmación no fija una comisión comercial definitiva: el 0,5 % de C3 sigue siendo un ejemplo del prototipo.

## Actores y recorrido mínimo

- **Inversor:** se autentica, vincula una wallet demostrando su control, consulta una franquicia publicada, acepta términos de demostración, compra tokens y reclama ingresos disponibles.
- **Administrador:** prepara/publica franquicias de prueba, identifica sus contratos, marca el inicio de operación, confirma pagos simulados mediante el servicio autorizado y registra/fondea distribuciones mensuales.
- **Verificador de pago de prueba:** conserva la referencia única de la compra y llama a C4 tras confirmar el pago simulado. Es una función de demostración, sin necesidad de integrar un tercero real.

Recorrido esperado: **franquicia publicada → compra → pago simulado confirmado → emisión mediante C4 → franquicia en operación → distribución mensual fondeada → ingreso disponible → reclamo confirmado**.

Cada franquicia identifica su proyecto, red y contrato de token/emisión. Las pantallas muestran cantidad, precio, disponibilidad y estado; los IDs y los contratos vinculan la compra al proyecto correcto. No se necesita una campaña con metas, cierre financiero o devolución para demostrar este recorrido.

## Estados simplificados

| Objeto | Estados y significado |
|---|---|
| Franquicia | **Publicada**, **en operación**, **cerrada**. Publicar habilita el recorrido de compra; en operación habilita las distribuciones. Cerrada detiene nuevas compras y distribuciones, sin borrar saldos o ingresos ya asignados ni afirmar liquidación del vehículo. |
| Compra | Pendiente de confirmación simulada → pago simulado confirmado → emisión pendiente → emitida. Una falla de emisión conserva la compra y sus referencias para consultar/reintentar sin duplicar tokens. |
| Distribución | Registrada para una franquicia/período → pendiente de confirmación on-chain → disponible. Solo es disponible después del fondeo y la asignación confirmados. |
| Reclamo | Disponible → transacción pendiente → cobrado tras confirmación. Un intento fallido conserva el derecho reclamable. |

Estos estados se representan en contratos y en los resultados de integración del MVP; los detalles de prueba y ejecución figuran en la documentación de cada repositorio. Un error o una respuesta perdida de RPC no prueban un resultado económico: consultar la operación antes de repetirla.

## Compras e ingresos

1. El principal es `cantidad × USD 10`; se muestra separado del gas. La compra conserva comprador, wallet, franquicia/emisión, cantidad, importe, referencia única y resultado de emisión.
2. Se mantienen aceptación de términos y elegibilidad mínima del registro requeridas por C4/token. Si se usa KYC, basta una habilitación manual **de demostración**, sin proveedor real ni afirmación de identidad verificada legalmente.
3. C4 es el controlador de emisión. El recorrido de compra no debe usar un mint administrativo directo ni crear una tenencia ficticia en la UI.
4. Solo una franquicia en operación admite una distribución mensual. El administrador aporta un monto positivo y fondea con el token de pago de prueba; la carga manual representa el ingreso distribuible simulado, sin calcular balances reales.
5. El importe se asigna proporcionalmente al saldo de cada inversor sobre la oferta en circulación **al ejecutar la distribución**. No se requiere snapshot anterior ni reparto por días de tenencia. Una compra posterior no participa de ingresos ya asignados.
6. Registrar una distribución no paga automáticamente al inversor: el inversor firma el reclamo de su saldo disponible. Puede acumular ingresos disponibles de varios períodos; no se exige modificar el contrato para reclamar cada mes por separado.
7. Las cantidades monetarias se conservan con precisión exacta y se serializan como texto. Deben respetarse los decimales del token de inversión y del activo de pago, sin prometer distribuciones fraccionarias inferiores a su unidad mínima.

## Controles mínimos y criterios de aceptación

| Caso de demostración | Resultado esperado |
|---|---|
| Comprar N tokens de una franquicia publicada | Principal N × USD 10; pago identificado como simulado; C4 emite una vez a la wallet del comprador. |
| Reintentar la misma compra o perder la respuesta de emisión | Se recupera/consulta el resultado de la misma referencia; no se emite dos veces. |
| Comprar sin términos aceptados o sin habilitación demo requerida | Se rechaza sin registrar emisión exitosa. |
| Consultar tenencias | Saldo del contrato de esa franquicia; compras e historial enlazados por referencias, sin arrays fijos como fuente operativa. |
| Distribuir antes de iniciar operación o sobre una franquicia cerrada | Se rechaza. |
| Distribuir un mes con titulares A y B | Reciben la prorrata correspondiente a sus saldos al ejecutar la distribución, con redondeo técnico y residuales visibles cuando apliquen. |
| Reintentar la distribución de la misma franquicia y período | No se vuelve a fondear/acreditar el mismo período. |
| Reclamar ingresos dos veces | El segundo intento no vuelve a pagar lo ya cobrado. |
| Comprar después de una distribución | La compra no recibe lo previamente asignado a otros titulares. |
| Transferir a otro inversor mediante transfer o transferFrom | Se rechaza también on-chain, no solo ocultando controles de UI. La restricción no debe bloquear mint ni reclamos. |
| Acceso de usuario a acciones administrativas o a compras ajenas | Se rechaza; separar usuario y administrador y autorizar por objeto. |
| Pausar durante una incidencia | La interfaz informa qué acciones se bloquean; no se confunden pausas del token y C4 ni se borran derechos existentes. |

Los criterios anteriores guían las pruebas del recorrido implementado; los resultados y límites de la verificación se registran en el estado técnico de cada repositorio. Una identificación única de compra y otra por franquicia/período de distribución son suficientes para el MVP; no se exige un ledger contable ni un indexador completo. Las tenencias pueden consultarse directamente en los contratos y las referencias de compras/transacciones persistirse en backend.

## Fuera de alcance de esta versión

- Cobros bancarios, proveedor de pagos y conciliación externa real; custodia o conversiones de dinero real.
- Metas de campaña, cierre financiero, devolución automática, liquidación económica del fideicomiso y quema por devolución/remanente.
- Balances operativos, impuestos, reservas, cascada completa C1–C3 y cálculo automático de honorarios.
- Sustitución de operadora, permisos institucionales complejos, mercado secundario, reventa y liquidez.
- Red pública de prueba o producción, indexación completa y automatización temporal con cron/oráculos como requisito de la presentación.

C1–C3 se conservan como contexto y componentes de demostración. No se exige automatizar el circuito jurídico/operativo completo para comprar y cobrar. **La dependencia técnica actual de C4 respecto de C3 activo sigue existiendo:** la preparación de la demo debe satisfacerla con firmas de prueba. El token académico extiende el token existente para bloquear transferencias, controlar estados y asegurar un reparto por mes; los contratos C1–C4 existentes mantienen sus verificaciones. Se conserva la suite del token general.

## Aprobado frente a pendiente

La periodicidad mensual, el importe manual, la prorrata al ejecutar, el reclamo por inversor, la ausencia de transferencias y Hardhat local quedan definidos **para el MVP**. Los pendientes de una operación con valor real en [DECISIONS.md](DECISIONS.md) se conservan. Fechas concretas, importes de cada mes, cantidad disponible de cada franquicia y datos de la presentación se cargarán como datos de prueba, sin inventarlos como condiciones comerciales.

No se selecciona Supabase, otro proveedor ni una red distinta por esta aprobación. El uso de Besu que pueda existir en el repositorio blockchain queda como alternativa técnica previa, fuera del recorrido base confirmado de Hardhat local.
