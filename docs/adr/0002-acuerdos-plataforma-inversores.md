# ADR-0002 — Acuerdos de la plataforma y de inversión

- Estado: PROPUESTA
- Fecha: 2026-10-29
- Responsable: pendiente
- Referencia verificable de aprobación: ninguna
- Decisiones relacionadas: D02–D06, D08–D12

## Problema, derechos afectados y restricciones

El README identifica dos relaciones aún sin implementación: fideicomiso ↔ FranToken SAS (servicios y honorarios) y fideicomiso/emisor ↔ inversor (derecho de inversión). El código actual permite emitir tokens y distribuir un importe, pero no vincula esas operaciones a suscripciones conciliadas ni a derechos económicos aprobados. La lógica de negocio del repositorio puede estar desactualizada; los términos de ambos acuerdos requieren confirmación del usuario.

## Actores, estados y amenazas

| Ámbito | Actores y autoridad por definir | Estados mínimos a distinguir | Amenaza principal |
|---|---|---|---|
| Servicios | Prestador FranToken, obligado al pago, aprobador de entregables | Borrador, firmado, activo, prestación acreditada, importe aprobado, pagado, terminado | El prestador se autoaprueba o cobra dos veces |
| Inversión | Emisor/obligado, inversor/titular, verificador de elegibilidad, custodio de fondos | Suscrita, aporte recibido, conciliado, derecho constituido, token asignado, cancelada/devuelta | Emisión por pago no final o duplicado; fondos de otra emisión |
| Distribución | Responsable de propuesta, aprobador, financiador, beneficiario | Propuesta, aprobada, financiada, reclamable, pagada, cerrada | Reparto sin caja ni corte válido; reclamo repetido |

Un pago recibido, un derecho constituido, una transacción enviada y una liquidación final son hechos separados. Los datos sensibles de identidad y los documentos privados quedan fuera de la cadena pública.

## Invariantes para la implementación

1. Una referencia de prestación, aporte o período no puede producir un segundo pago o una segunda asignación de derechos.
2. El prestador no aprueba unilateralmente su propio honorario; la autoridad y el método de aprobación deben quedar definidos.
3. La emisión definitiva exige elegibilidad, aporte conciliado y derecho constituido conforme a reglas vigentes de la emisión.
4. Cada activo y emisión tiene fondos y permisos propios; ninguna operación de una emisión consume los de otra.
5. Lo reclamado por beneficiario y período no supera su asignación neta; el total pagado no supera los fondos reservados.
6. La transferencia o recuperación del token no modifica retrospectivamente un corte de titulares aprobado.
7. La cancelación y el cierre de la campaña no pueden habilitar simultáneamente devolución y desembolso de los mismos fondos.

## Alternativas

1. Acuerdo de servicios bilateral on-chain con obligaciones económicas parametrizadas y evidencia externa; reutiliza `BilateralAgreement` sólo si sus estados y períodos coinciden con el servicio real.
2. Términos comunes por emisión, aceptación individual y registro de suscripciones; evita desplegar un contrato bilateral completo por inversor, pero necesita definir registro prevalente, transferencias y relación con `FranchiseToken`.
3. Documentos jurídicos y registro convencional, usando la cadena sólo para compromisos y liquidación que aporten verificabilidad demostrable.
4. No automatizar pagos ni emisión definitiva hasta cerrar derechos, autoridades y custodia.

## Evidencia y supuestos

Fuentes internas: `README.md`, `docs/PROJECT.md`, `docs/DECISIONS.md`, `docs/FranToken-manual-consulta.md` §§1, 3–4 y 6, `contracts/agreements/`, `contracts/token/FranchiseToken.sol`. Los contratos 1 y 2 y sus pruebas son evidencia de una implementación existente, no aprobación de sus supuestos económicos.

Dato aportado por el usuario el 2026-10-29: la compra se haría por una web; el precio propuesto es USD 10 por token más gas pagado aparte por el comprador. FranToken retendría 0,5 % de los USD 10 (USD 0,05) como supuesto provisional y USD 9,95 corresponderían al fideicomiso. El cobro y la conciliación serían externos, administrados por un tercero; la emisión ocurre después de esa conciliación. El inversor recibiría ingresos, sin fórmula definida. Una campaña fallida sería gestionada por ese tercero, pero sus condiciones no se especificaron. Jurisdicción, custodia exacta, finalización del pago, prioridad y base del derecho económico siguen pendientes.

## Decisión propuesta y condición que la cambiaría

Para prototipo local, `PlatformServicesAgreement` contiene moneda, escala, porcentaje de comisión y hash de términos; fideicomiso y plataforma firman antes de que se habilite la emisión. La comisión se calcula con enteros y redondeo hacia abajo; el residual queda para el fideicomiso. No custodia ni transfiere fondos. `InvestmentAgreement` contiene precio unitario y hash de términos de la emisión, registra aceptación de la wallet y permite emitir sólo al verificador de pago designado, una vez por compra y referencia de pago. `FranchiseToken` puede vincular de forma irreversible un controlador de emisión antes del primer mint para cerrar la ruta directa de agentes. La forma de liquidación económica y los derechos definitivos requieren decisiones posteriores.

Se eligió un registro compartido por emisión en lugar de un contrato bilateral por inversor para evitar desplegar contratos idénticos por cada comprador. Se eligió no usar `BilateralAgreement`: ese contrato presupone períodos y un token de pago on-chain, mientras que el cobro indicado es externo. La cadena no puede certificar el pago externo; el verificador designado asume esa atestación y el tercero debe asegurar unicidad también entre emisiones.

## Consecuencias, pruebas y transición

Las pruebas locales comprueban firmas de las partes, cálculo exacto del 0,5 % sobre USD 10, rechazo de actor no autorizado, importe incorrecto, términos no aceptados, compra o pago duplicado, rechazo del token, pausa y rotación del verificador. La llamada del verificador es una atestación de conciliación, no prueba automática de fondos externos. Un pago aceptado fuera de la cadena cuya emisión revierta requiere una incidencia y reintento con la misma referencia; el contrato evita asentar el intento fallido.

Quedan fuera del prototipo: cierre de campaña, devoluciones, custodia, conciliación bancaria real, prevención de reutilización de un mismo pago entre emisiones, corte y fórmula de distribuciones, aceptación de términos por adquirentes secundarios y migración de un controlador de emisión fallido. `distributeRevenue` conserva su comportamiento previo y no representa todavía la fórmula contractual de ingresos. No desplegar con valor económico por la existencia de esta ADR.

## Historial y decisión sustituida

2026-10-29: borrador de alcance e implementación local conforme a las respuestas del usuario; no sustituye una decisión aprobada.
