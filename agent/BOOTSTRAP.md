# Primer encargo: integrar el setup

Objetivo: adaptar el setup al repositorio real sin cambiar funcionalidad del producto.

1. Leer AGENTS.md y reglas existentes aplicables. Identificar raíz, instrucciones más específicas y cambios sin commit. No sobrescribirlos.
2. Inspeccionar manifiestos, lockfiles, CI, directorios, ejemplos de entorno sin secretos y documentación. Determinar si hay aplicación; no inventar apps/web, apps/api o contracts.
3. Registrar en agent/repo-config.json rutas detectadas, stack, gestor, versiones observadas y comandos reales. Usar status=discovered; mantener null para campos no encontrados.
4. Antes de ejecutar un comando, revisar su definición y efectos; distinguir pruebas locales de scripts que hacen deploy, migraciones o llaman proveedores. Usar solo entorno autorizado.
5. Ejecutar comprobaciones seguras pertinentes; guardar comando, directorio, fecha, resultado y limitaciones en baseline. Un fallo preexistente queda documentado; no marcar verde.
6. Comparar arquitectura existente con reglas de dominio sin refactorizarla automáticamente. Registrar conflictos y propuestas en ADR.
7. Verificar que la herramienta cargó AGENTS.md y sus guías: pedirle que identifique el manual, tres decisiones pendientes y el comando real de pruebas. Cotejar contra archivos, no contra su afirmación de haberlos leído.
8. Ejecutar python3 scripts/validate_setup.py y cerrar con inventario, evidencia y bloqueos materiales.

Criterio de aceptación: no hay comandos inventados, no se perdieron instrucciones existentes, se conoce el estado de verificación y ningún pendiente económico se convirtió en decisión aprobada.

Si no hay aplicación, mantener status=unconfigured, registrar ese hecho y finalizar integración documental. Crear una aplicación requiere un encargo posterior o una instrucción vigente que lo autorice; este bootstrap no elige el stack.
