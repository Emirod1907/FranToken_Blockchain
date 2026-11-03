# Registro de decisiones

## MVP-2026-11-01 — Implementación autorizada

El usuario autorizó implementar frontend y blockchain desde `develop` en ramas nuevas. La rama `feat/academic-mvp` aplica el alcance aprobado mediante un token académico derivado y un despliegue local separado. [ADR-0004](adr/0004-implementacion-mvp-academico.md) registra actores, guardas, amenazas, alternativas y verificación. La limitación «solo documentación» de los antecedentes corresponde a la entrega anterior.

## MVP-2026-11-01 — Alcance académico aprobado

Responsable de la definición: usuario del proyecto. Estado: **APROBADO exclusivamente para el MVP académico; implementación pendiente**. Evidencia: [confirmación del usuario y seis definiciones](business/MVP-ACADEMICO.md#fuente-autoridad-y-límites). Decisión técnica de alcance: [ADR-0003](adr/0003-alcance-mvp-academico.md).

Se eligen Hardhat local, pago simulado, inicio manual de operación, distribuciones mensuales con importe manual y prorrata al ejecutar, reclamo individual y transferencias deshabilitadas. La autorización actual es documental y de publicación en rama; no incluye implementación o despliegue. D03/D04/D06/D08/D09/D10 tienen estas respuestas para la demo, sin cerrar los pendientes de valor real de las tablas siguientes.

Actualizado: 2026-11-01. Estado de todos los D01–D12: PENDIENTE para operación real. Responsable de decisión y evidencia de aprobación: no designados.

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

## Reconciliación del 2026-11-01

Ver [definiciones recibidas y pendientes por Dxx](business/DECISIONS.md). El precio pasa de propuesto a **fijo: USD 10 por token + fees blockchain** por instrucción expresa del usuario. El 0,5 % de la sección histórica anterior y ADR-0002 queda como supuesto del prototipo, sin aprobación como comisión definitiva. Argentina/fideicomiso financiero son referencias declaradas de la presentación; los DTE definen estados y guardas, sin cerrar los parámetros operativos de D02–D10. Ninguna Dxx queda íntegramente resuelta para operación real.

El informe del 29-10-2026 corrige la presentación: C4 ya emite una vez por compra conciliada y C3 calcula/registra comisión sin cobrar. Las diferencias con código, incluida validación KYC solo del receptor en transferencias ordinarias, constan en [estado técnico](business/IMPLEMENTATION-STATUS.md). Los estados PROPUESTA e historial de las ADR se conservan.

## MVP-2026-11-02 — Integración única Express y publicación de solicitudes

Estado: implementado dentro del alcance académico solicitado. Instrucción vigente del usuario: realizar los cambios necesarios en las ramas actuales; backend en rama nueva desde develop. Complementa el alcance aprobado y sustituye la decisión técnica anterior del gateway Next para esta demo.

Express autentica JWT, comprueba perfil/aprobación y vincula wallets por desafío firmado. Admin y verificador usan firmantes distintos del manifiesto. La misma cuenta puede invertir y solicitar franquicias; no se agrega un rol excluyente. Perfil en SQL, sin documentación personal en cadena.

La publicación necesita token+C4 para que una solicitud aprobada pueda comprarse y cobrar. Se elige una fábrica local con clave de proyecto idempotente y deployers separados por tamaño de bytecode. Se conserva C3 firmado de prueba. No se agrega cálculo de campañas, caja, ROI ni estructura jurídica real. Precio 1000 centavos USD; ingresos mUSDC seis decimales.

La migración es aditiva; el seed no genera compras/repartos. Los endpoints alternativos de escritura quedan 410. Reintentos se concilian con eventos y claves únicas; no hay fallback que confirme derechos solo en base de datos. La cola del MVP presupone un proceso escritor. Reiniciar Hardhat exige una base de prueba nueva para una nueva presentación, sin borrado automático.

Evidencia: 58 tests de contratos y 14 escenarios integrados con SQL y EVM reales en memoria. Límites: sin prueba visual/TCP ni ejecución contra servidor MySQL/PostgreSQL; no se prueba uso con valor real. [Flujo vigente](business/MVP-ACADEMICO.md).
