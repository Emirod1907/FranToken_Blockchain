# Contexto operativo

Fuentes vigentes: [modelo de negocio](business/BUSINESS-LOGIC.md), [DTE](business/LIFECYCLES.md), [estado frente al modelo](business/IMPLEMENTATION-STATUS.md) y [material recibido](business/source/README.md). Actualizado: 2026-11-01. El manual y las respuestas del 29-10-2026 son antecedentes; no prevalecen sobre estas definiciones.

FranToken propone financiar la puesta en marcha de franquicias mediante aportes canalizados a un fideicomiso y representar ciertos derechos con tokens. El negocio operativo debe aportar los fondos que permitan cumplir distribuciones contractuales. La plataforma no se presume fiduciaria, custodio ni emisora.

## Confirmado como intención del proyecto

- Modelo adaptable a franquicias de diferentes marcas y sectores.
- Web para interacción del inversor; fideicomiso como estructura propuesta.
- Representación de un derecho a ingresos mediante tokens; fórmula, porcentaje y condiciones todavía pendientes.
- USD 500.000 es ilustrativo. No existe acreditación de vínculo con McDonald's.
- Precio fijo indicado por el usuario: USD 10 por token más fees de transacción blockchain, separados. Compra desde la web, cobro externo y emisión mediante C4 tras conciliación. El 0,5 % calculado por C3 es un parámetro del prototipo; comisión comercial definitiva y gestión/resultado siguen pendientes.
- El inversor recibiría ingresos. La fórmula, base, prioridad, periodicidad, pérdidas y vencimiento siguen sin definirse. El tercero gestionaría una campaña fallida conforme a términos aún pendientes.

## No confirmado

Argentina y fideicomiso financiero son referencias declaradas en la presentación. Faltan jurisdicciones e instrumento definitivos, partes, denominadores, presupuesto, metas/plazos/procedimiento de cierre y devolución, tercero, custodia/conversión, registro, red, parámetros de transferencia, fórmula de reparto y comisión definitiva. Los DTE ya describen guardas de cierre, elegibilidad, distribución y liquidación: ver [definiciones y pendientes](business/DECISIONS.md) y D01–D12.

No trasladar requisitos de Follow the Sun: hoteles, habitaciones, membresías, NFTs turísticos o compensación entre establecimientos.

## Procesos propuestos, todavía sujetos a reglas

Estructuración → elegibilidad y suscripción → recepción y conciliación → cierre o devolución → desembolsos y puesta en marcha → operación → distribuciones → incidencias y liquidación.

Campaña, cobro, asignación de derechos, obra, operación y distribución tienen estados separados. Un indicador global no describe todos los procesos. Registrar evidencia, actor y versión de reglas en cada transición sensible.

## Fuente de verdad

Los documentos aprobados definen derechos. Los registros técnicos conservan hechos y permiten conciliación, pero la prevalencia jurídica está pendiente. Un indexador, una wallet o un webhook no adquieren esa autoridad por ser accesibles. Ante discrepancias, abrir una incidencia y bloquear las operaciones afectadas conforme al procedimiento definido; nunca reescribir saldos silenciosamente.

Integración al repositorio real: ya existen contratos Solidity y pruebas Hardhat en la raíz; no se detectaron frontend ni backend. Este código antecede al setup documental y no acredita aprobación de sus supuestos económicos o técnicos. Los ejemplos del manual son ilustrativos. No considerar que un ADR, fixture o plan constituye aprobación del usuario.
