# Contexto operativo

## Entrega de implementación académica

La rama `feat/academic-mvp` parte del `develop` local e incorpora las definiciones aprobadas antes de implementar. El recorrido de compra simulada, emisión C4, distribución mensual y reclamo está implementado; las evidencias y limitaciones se registran en [estado técnico](business/IMPLEMENTATION-STATUS.md). La autorización posterior del usuario habilita este trabajo y sustituye la restricción documental de la entrega anterior. No incluye dinero real ni red pública.

## Objetivo actual: MVP académico confirmado

El alcance de entrega vigente es el [MVP académico aprobado](business/MVP-ACADEMICO.md): comprar tokens a USD 10 con pago simulado y emisión C4, iniciar operación por administrador, distribuir mensualmente un importe manual a prorrata y reclamar ingresos con token de prueba en Hardhat local. Sin transferencias entre inversores, sin bancos ni automatización completa del negocio. La aprobación no modifica el código ni cierra pendientes de una operación real.

Los antecedentes siguientes describen el modelo completo y el contexto técnico anterior. Las referencias a fórmula, periodicidad o red pendientes se refieren a valor real; para la demostración rigen las definiciones aprobadas enlazadas arriba.

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
