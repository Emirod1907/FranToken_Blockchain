# Contratos y conexión con blockchain

Estado: guía condicional. Red, estándar, token, custodia y registro no elegidos.

## Antes de código desplegable

Definir derecho, fungibilidad, fuente autorizada, elegibilidad, restricciones, emisión/quema, recuperación, administradores, pausas y migraciones. Para elegir estándar comparar necesidad funcional, costos, permisos, integración, amenazas y reversibilidad. ERC-3643 es una alternativa por evaluar; este setup no afirma que haya sido seleccionado ni que garantice cumplimiento.

## Implementación

- Verificar especificaciones oficiales y versiones de compilador, librerías y herramientas. Fijar dependencias/compilador y conservar artefactos reproducibles.
- No diseñar criptografía propia. Validar dominio de firmas, chain ID, contrato destino, nonce y caducidad cuando corresponda. Prevenir replay entre emisiones/redes.
- Proteger todas las rutas que alteran titularidad o saldo: transferencias directas y delegadas, operadores, mint/burn y acciones administrativas. Una allowlist en frontend es insuficiente.
- Emitir solo una vez contra el hecho económico y derecho autorizado. Registrar referencia única; definir reversión o incidencia si la asignación externa diverge.
- Para distribuciones: corte y versión de reglas inmutables para el período aprobado, activo identificado, asignaciones reproducibles, fondos reservados y protección de reclamo repetido. Una prueba Merkle no certifica la corrección económica del conjunto.
- Evitar loops no acotados; evaluar reclamos o lotes conforme al volumen. Controlar interacción externa, reentrancia, retornos y comportamiento de activos no estándar si se admiten.
- No publicar información identificatoria ni documentación privada. Identificadores y hashes también pueden permitir correlación.
- Diferenciar transacción enviada, incluida, confirmada/finalizada y conciliada. Definir política de finalización por red y recuperación ante reorg; preservar trazabilidad del evento invalidado.
- Los indexadores deben poder reanudar y reprocesar sin duplicar efectos. Eventos repetidos/fuera de orden se manejan explícitamente.

## Administración y publicación

Justificar contratos actualizables frente a inmutables. Documentar autoridades, separación de funciones, inicialización, layout de almacenamiento, demoras y procedimientos de emergencia cuando apliquen. Definir alcance de pausa y protección de obligaciones pendientes.

Desplegar primero local/pruebas según autorización. Registrar red, chain ID, direcciones, bytecode, parámetros, roles y evidencias. No firmar ni mover fondos reales con autorización implícita de un encargo de programación. No decir auditado por haber ejecutado análisis estático o tests.
