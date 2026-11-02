# Blockchain del MVP integrado

Actualizado: 2026-11-02. [Negocio vigente](business/MVP-ACADEMICO.md), [estado técnico](business/IMPLEMENTATION-STATUS.md), [decisión de integración](adr/0005-integracion-express-publicacion.md).

## Ejecución

`npm run node` y `npm run deploy:academic` en terminales separadas. Solo Hardhat local, chain ID 31337. El manifiesto `deployments/academic-local.json`, ignorado por Git, contiene deploymentId, bloque inicial, registry, paymentToken, factory, admin/verificador y token/C4 de cuatro proyectos. **Express lo lee**; Next consume Express con JWT. No se configuran MVP_ENABLED/MVP_RPC_URL en frontend.

Cuentas locales de prueba: 0 administra/fondea; 1 vehículo C3; 2 plataforma C3; 3 verificador; 4+ usuarios. mUSDC tiene seis decimales y el admin recibe fondos ficticios para repartir. Fixtures: 1000 tokens enteros por proyecto, precio **1000 centavos USD**, no 10000000 unidades mUSDC. C3 está firmado con datos ficticios; 0,5 % es ejemplo, sin cobro real. Las cuentas de prueba preinscritas en registry no sustituyen la revisión de perfil de Express.

Preparación restante: en backend ejecutar migración/importación del MVP y habilitar los flags de escritura local; frontend apunta `NEXT_PUBLIC_API_URL` a Express. La guía completa está en `docs/architecture/ACADEMIC-MVP-RUNBOOK.md` del frontend y `docs/MVP-INTEGRATION.md` del backend hermano. Reiniciar cadena exige redesplegar y usar otra base de prueba; importar un manifiesto no migra derechos ni borra compras anteriores.

## Contratos y guardas

`AcademicFranchiseToken` extiende el token general conservando sus correcciones de ingresos y facultades administrativas. El token general/C1/C2 quedan disponibles para estudiar el modelo completo; no se usan como atajo para la compra académica.

| Acción | Regla |
|---|---|
| Publicar / operar / cerrar | Owner, transiciones hacia adelante. Cerrada no reabre y mantiene ingresos anteriores. |
| Emitir | Published/Operating; C4 controlador y agente; términos, elegibilidad, precio y referencias exactos; sin pausa/congelamiento. |
| Transferir | transfer/transferFrom/batchTransfer ordinarios revertidos, sin bloquear mint/cobro. Recuperación/forcedTransfer heredadas no se exponen como mercado secundario. |
| Distribuir | Agente, Operating, fondeo positivo, titulares, período YYYYMM válido/no usado. distributeRevenue genérico revierte. |
| Cobrar | Titular firma claimRevenue; no paga automáticamente el backend. Pausa/congelamiento vigentes impiden cobro; cierre no. |

`MonthlyRevenueDistributed` registra mes, importe y supply del corte. Marca del mes y fondeo/asignación revierten juntos si falla la transacción. Correcciones evitan ingresos retroactivos al comprar después; redondeo entero puede dejar residuos.

## Publicación de solicitudes

`AcademicProjectFactory.createProject(key,name,symbol,cap,compliance)` solo owner. La clave estable deriva del ID de proyecto reservado por Express, sin DNI/CUIL. Crea token académico y C4, asigna C4 como agente/controlador, admin como agente/owner y publica. Usa el registry, pago, C3 firmado y verificador configurados en su despliegue. La misma clave/configuración recupera direcciones; otra configuración se rechaza. C3 debe ser USD con dos decimales; precio 1000.

Deployers auxiliares separados crean token/C4 para mantener cada runtime dentro del límite EIP-170. No añaden permisos web ni intervención del usuario en despliegues. Express crea compliance usando el artefacto público compilado y reserva el proyecto antes de llamar a la fábrica; si una respuesta se pierde consulta el mapping de la misma clave. No hace una llamada nueva con una clave aleatoria.

## Evidencia y límites

- `npm test`: **58 pasan**, suite general, seis escenarios del token académico y uno de fábrica (roles, configuración, controladores y reintento).
- Backend `npm run test:mvp` / frontend `node scripts/test-academic-integration.cjs`: **14 escenarios pasan**, clientes frontend → rutas/middlewares Express/JWT → Sequelize/SQL real → Hardhat. Incluyen nueva solicitud/publicación/compra/reparto/cobro y reintentos.
- El runner solo sustituye sockets y driver sqlite3 por node:sqlite; firmas, SQL y EVM son reales. No requiere abrir puertos ni toca una cadena/base existentes. Requiere Node 24.
- Sin prueba visual de extensión, transporte TCP ni servidor MySQL/PostgreSQL; el sandbox restringe sockets. Sin fondos reales. La suite no certifica cumplimiento jurídico o producción.
