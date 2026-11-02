# Estado de trabajo

Actualizado: 2026-11-02. Rama blockchain conservada: feat/academic-mvp. Frontend en la misma rama; backend feat/mvp-integracion-completa desde develop fd67b09. Usuario autorizó implementación/documentación integral para MVP, sin dinero real.

Se mantiene AcademicFranchiseToken y se agrega AcademicProjectFactory con deployers separados, clave idempotente y C4 exclusivo. deploy-academic genera factory en manifiesto. Express/JWT reemplaza gateway Next; perfil mínimo privado, revisión manual, cualquier usuario invierte y solicita, admin publica token+C4 y reparte mensualmente. Precio 1000 centavos USD; ingresos mUSDC seis decimales. Ver docs/ACADEMIC-MVP.md y ADR-0005.

58 pruebas de contrato pasan; 14 escenarios cliente frontend -> Express/JWT -> SQL SQLite real -> Hardhat real pasan, incluida publicación nueva con compra/reparto/cobro y migración repetida. Transporte en memoria por restricción de sockets. Sin prueba visual/extensión ni servidor MySQL/PostgreSQL; sin datos privados ni activos reales.

Para demo local: tres repositorios, nodo/deploy académico, migración/importación backend, NEXT_PUBLIC_API_URL hacia Express. Reiniciar cadena exige usar otra base de prueba; no convertir ni borrar historial automáticamente. Pendientes de operación real Dxx siguen abiertos.
