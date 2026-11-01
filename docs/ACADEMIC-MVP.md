# Blockchain del MVP académico

El nuevo `AcademicFranchiseToken` extiende `FranchiseToken` sin modificar el comportamiento del token general: solo se hicieron virtuales sus puntos de extensión. Conserva C4, aceptación, precio exacto, unicidad de compra y correcciones de ingresos ya asignados.

## Preparar la presentación

1. Instalar dependencias con el lockfile npm del repositorio y ejecutar `npm test`.
2. Ejecutar `npm run node` en una terminal y `npm run deploy:academic` en otra.
3. Usar el manifiesto `deployments/academic-local.json` desde el frontend hermano. Solo contiene direcciones, red, deploymentId y datos públicos del proyecto. Reiniciar Hardhat exige redesplegar y actualizar el frontend.
4. En el frontend habilitar `MVP_ENABLED=true`, RPC `http://127.0.0.1:8545` y, opcionalmente, `MVP_MANIFEST_PATH` apuntando al manifiesto. La guía completa de UI está en el documento ACADEMIC-MVP-RUNBOOK.md, en la carpeta de arquitectura del frontend.

Solo admite Hardhat/localhost y chain ID 31337. Las cuentas 0, 1, 2 y 3 se usan como administrador, vehículo, plataforma y verificador de pago simulado; las restantes como inversores. Usar únicamente las cuentas públicas de prueba del nodo, nunca fondos o claves reales. Las cuatro marcas son referencias ilustrativas, sin alianza ni unidad real acreditada. Cada proyecto usa 1.000 tokens enteros como fixture de presentación; el principal simulado es USD 10 por token.

## Guardas y decisiones

| Acción | Control |
|---|---|
| Publicar | Solo owner; Draft → Published. |
| Iniciar operación | Solo owner; Published → Operating. |
| Comprar/emitir | Published u Operating, C4 exclusivo configurado, aceptación, habilitación demo, límites, precio exacto y referencias de compra/pago únicas; token no pausado y receptor no congelado. |
| Transferir | transfer, transferFrom y batchTransfer ordinarios no mueven tokens en el MVP. Las facultades administrativas heredadas no se exponen como mecanismo de reventa. |
| Distribuir | Solo agente, Operating, token no pausado, mes YYYYMM válido y no usado; cantidad positiva, titulares y fondeo real en token de prueba. La entrada genérica distributeRevenue revierte para impedir eludir el período. |
| Cobrar | El titular llama claimRevenue; conserva los controles de pausa/congelamiento y el registro de lo ya cobrado. Puede retirar lo acumulado de varios meses. |
| Cerrar | Solo owner desde Published/Operating; no se reabre, no se emite ni reparte más, pero se conservan ingresos reclamables. No implica liquidación económica ni devolución. |

`distributedPeriod` se marca en la misma transacción que fondea/asigna. Si falla el fondeo o el importe es inválido, la EVM revierte también esa marca. La prorrata usa el supply al ejecutar; `MonthlyRevenueDistributed` registra período, monto y oferta del corte. Las correcciones heredadas evitan que una emisión posterior reciba distribuciones previas. El redondeo puede dejar residuos inferiores a unidades mínimas de cobro; no se altera la suma mediante floats.

C3 se firma con cuentas de prueba para satisfacer la dependencia de C4, con 0,5 % como ejemplo histórico; no se aprueba una comisión comercial definitiva. El despliegue académico no registra C1/C2 como obligaciones senior: su contabilidad y pagos reales están fuera de este recorrido. El despliegue general existente sigue disponible para estudiar esas relaciones.

## Verificación y límites

- `npm test`: **57 pruebas pasan**, incluidas seis del MVP y la suite anterior.
- Desde el frontend hermano: `node scripts/test-academic-integration.cjs` verifica ocho escenarios de cliente wallet → API Next → contratos reales en Hardhat en memoria. Incluye respuesta de compra perdida, rechazo de permisos y no duplicación de mes/cobro.
- El despliegue académico se ejecutó dentro de esa prueba integrada; no se abrieron nodos ni se movieron fondos reales.
- La verificación TCP/navegador quedó pendiente porque el sandbox rechaza escuchar en 127.0.0.1:8545 con EPERM. No se afirma prueba visual ni integración por extensión real.
- Las ramas partieron del develop local; no se pudo actualizar GitHub por DNS. Las decisiones jurídicas y de operación con valor real siguen pendientes.
