# ADR-0004 — Implementar el recorrido académico sin cambiar el backend separado

- Estado: IMPLEMENTADA para el MVP local; verificación visual y TCP pendiente.
- Fecha: 2026-11-01.
- Responsable de la autorización: usuario del proyecto.
- Evidencia: instrucción posterior a ADR-0003: «Procedé a implemntar los cambios necesarios en Frontend y Blockchain. Todos los cambios deben partir desde develop a una rama nueva».
- Rama en ambos repositorios: `feat/academic-mvp`, creada desde `develop` local. La sincronización remota no se pudo verificar por DNS.

## Problema y alternativas

El recorrido debe comprar con pago simulado, emitir por C4 y cobrar ingresos mensuales. Modificar el backend separado excede los dos repositorios solicitados; hacer mint desde el navegador o dar al inversor la clave verificadora permitiría emitir sin autorización; mantener arrays ficticios no demuestra la emisión real.

Se eligió un coordinador local en handlers Next del frontend, con ethers 6.17.0, firma de cada solicitud y transacciones del verificador/admin de Hardhat. No introduce banco, servicio externo, ledger contable ni claves privadas de usuario. Los eventos y estados de los contratos son el registro persistente de resultados mientras la cadena local está activa. La referencia pendiente se guarda antes de enviar desde el navegador.

## Actores, estados, amenazas e invariantes

- El inversor firma términos C4 y reclamos desde su wallet; firma también solicitudes de pago simulado vinculadas a origen, chain ID, deploymentId, vencimiento y payload completo.
- El verificador local ejecuta issueAfterPayment; C4 sigue comprobando condiciones y unicidad. Un reintento con el mismo ID recupera el evento; diferente comprador/cantidad con ese ID se rechaza.
- El administrador es el owner del despliegue y agente del token. Solo su firma habilita cambios de estado, registro manual de identidad demo y distribución mensual en el gateway; los contratos vuelven a verificar los permisos.
- El token académico controla Draft → Published → Operating → Closed, compra solo en estados habilitados y distribución solo en Operating. Cierre no borra reclamos.
- Una compra emite una vez, un contrato/período se acredita una vez y lo cobrado no supera lo asignado. Se mantiene segregación por contrato y no se asignan devengados previos a emisiones posteriores.
- Transferencias ordinarias directas, delegadas y por lote se bloquean on-chain. Las facultades administrativas heredadas no se exponen como reventa.
- El gateway solo se habilita expresamente, con RPC loopback y chain ID 31337; valida origen local, firma y despliegue. El nodo de cuentas desbloqueadas no debe exponerse públicamente.

## Implementación y consecuencias

AcademicFranchiseToken deriva del token general; transfer, transferFrom, mint y distributeRevenue se hicieron virtuales sin alterar sus reglas generales. El subtipo impone controles de estado/congelamiento/pausa y exige distributeMonthly para el reparto. La marca de período y el fondeo revierten juntos ante error.

El script deploy-academic prepara fixtures, firmas C3, C4 exclusivo y un manifiesto sin claves. Conserva los scripts y contratos generales para no reemplazar ejemplos C1/C2 ni escoger Besu como red del MVP. El 0,5 % de C3 continúa siendo ilustrativo.

## Evidencia y transición

La suite de 57 casos pasa, y ocho escenarios integrados de cliente/API/EVM pasan en memoria. El frontend pasa tipos, arquitectura, Biome del alcance y build Next con Webpack. El entorno bloquea el puerto 8545: no se afirma prueba por HTTP real ni revisión visual con wallet. Ver [guía y límites](../ACADEMIC-MVP.md).

ADR-0003 conserva la aprobación histórica del alcance. Su autorización documental inicial fue sustituida para esta etapa por la nueva instrucción de implementar; los pendientes jurídicos/operativos para valor real no cambian.
