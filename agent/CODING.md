# Reglas comunes de implementación

Aplicar a código; no usar para imponer un framework inexistente.

- Inspeccionar convenciones, manifiestos, lockfiles, CI y código vecino. Mantener gestor de paquetes y estilo existentes. Verificar documentación oficial de la versión afectada antes de depender de una API cambiante.
- Preferir nombres del dominio y funciones de responsabilidad delimitada. Identificadores de código coherentes con el repo; documentación para el equipo en español. No mezclar idiomas arbitrariamente.
- En TypeScript, mantener comprobaciones estrictas; usar `unknown` y validación en fronteras. Evitar `any`, casts y supresiones que oculten problemas sin explicación localizada.
- Tipos estáticos no validan entradas de red. Validar formato, tamaño, rango, activo, escala, permisos y semántica. Separar DTOs externos de entidades del dominio cuando difieran.
- Modelar estados y errores de negocio explícitos. No devolver éxito tras capturar una excepción sin resolver. Evitar strings mágicos y flags incompatibles.
- Dinero con representación exacta. Persistir activo, cantidad y escala; serializar enteros grandes como cadenas. Definir residuales, límites, signo y política de redondeo por operación. No sumar activos distintos sin conversión explícita y trazable.
- Fechas de eventos con zona u offset; instantes normalizados y reglas de calendario de negocio explícitas. No inferir períodos económicos del huso del servidor.
- Dependencias solo cuando resuelvan un problema concreto: revisar licencia, mantenimiento, superficie de permisos, compatibilidad y lockfile. No actualizar paquetes no relacionados.
- Migraciones versionadas y compatibles con el despliegue. Para cambios con pérdida potencial, preparar respaldo, ensayo y plan de recuperación antes de ejecutar. Revertir código no revierte pagos.
- Comentarios para motivos, restricciones o invariantes; evitar repetir el código. No dejar TODO como sustituto de una validación sensible.
- Limitar el diff al objetivo. No borrar cambios ajenos, regenerar todo el repo ni modificar pruebas para normalizar una regresión.

Preferir composición y modularidad proporcional al dominio. SOLID y patrones son herramientas; no exigir una clase, repositorio genérico o fábrica para cada función. No instrumentar datos sensibles en logs. Registrar IDs internos y correlación suficiente para diagnóstico.
