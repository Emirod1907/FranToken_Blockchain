# Verificación de integración

Fecha: 2026-10-04. Raíz: `/home/mrtfog/projects/FranToken`.

## Inventario y carga de instrucciones

Se leyeron `AGENTS.md`, `docs/PROJECT.md`, `docs/DECISIONS.md` y las guías de blockchain, negocio y calidad pertinentes. Cotejo pedido por `agent/BOOTSTRAP.md`:

| Respuesta de la herramienta | Cotejo en archivos |
|---|---|
| Manual: `docs/FranToken-manual-consulta.md` | `AGENTS.md`, sección «Contexto mínimo y lectura»; archivo presente |
| Tres decisiones pendientes: D03 (derecho representado), D06 (base de reparto), D10 (red/estándar/administración) | `docs/DECISIONS.md`, estado PENDIENTE para D01–D12 |
| Prueba real de contratos: `npm test` desde la raíz | `package.json` → `scripts.test` = `hardhat test`; `agent/repo-config.json` |

Este cotejo demuestra el comportamiento de esta sesión; no prueba que otra sesión o herramienta cargue las guías automáticamente.

## Comprobaciones

| Comando y directorio | Resultado | Límite |
|---|---|---|
| `npm test`, raíz, sandbox | EROFS al crear configuración de Hardhat; no ejecutó tests | Restricción de escritura del entorno |
| `npm test`, raíz, acceso autorizado fuera del sandbox | 23 archivos Solidity compilados; 24 pruebas Hardhat pasan | Solo pruebas locales del código actual; descargó compilador 0.8.24 |
| `python3 scripts/validate_setup.py`, raíz | OK: 19 archivos requeridos, referencias locales y estructura; status `discovered` | No evalúa producto ni conducta futura del agente |

No se ejecutaron instalación, CI, despliegues, nodo persistente, migraciones, proveedores, transferencias económicas ni pruebas de red externa. `npm run compile` está descubierto, pero no ejecutado por separado: `npm test` compiló. No se detectaron CI, frontend, backend, archivo de versión de Node ni ejemplo de entorno en el repositorio inspeccionado. Las variables nombradas en `hardhat.config.js` se inventariaron sin leer sus valores.

La comparación con el dominio está en `docs/adr/0001-integracion-contratos-existentes.md` como PROPUESTA. D01–D12 continúan PENDIENTES. La prueba local no demuestra idoneidad jurídica, exactitud del derecho económico, seguridad de los contratos ni aptitud para producción.

Los cambios previos en `README.md` y `package-lock.json`, así como los archivos de setup no versionados, se preservaron. El bootstrap solo añadió o ajustó documentación y `agent/repo-config.json`; no modificó contratos ni el lockfile.
