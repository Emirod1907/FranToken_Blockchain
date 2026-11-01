# Interfaz e interacción

Aplicar junto a reglas comunes. Framework y librerías se descubren en el repo.

- Separar lectura, intención del usuario y resultado confirmado. Mostrar solicitado, pendiente, confirmado, fallido y estado desconocido según la operación real; nunca éxito solo por un hash.
- El backend y/o contrato deciden permisos. Ocultar un botón no es autorización. Evitar filtrar datos de otro usuario en caché, rutas, consultas o hidratación.
- Mantener importes exactos hasta formatear; introducir moneda, separador y decimales de forma inequívoca. Evitar convertir cantidades grandes a Number para mostrarlas.
- Formularios con etiquetas, navegación por teclado, errores asociados y estados de carga/vacío/error. Prevenir envíos accidentales repetidos en UX, sin sustituir idempotencia del servidor.
- Confirmaciones de usuario para transacciones económicas deben mostrar activo, red cuando corresponda, destinatario, importe y efecto; no confundir conexión de wallet con inversión aprobada.
- Considerar wallet desconectada, cambio de cuenta/red, firma rechazada, saldo insuficiente y RPC caído. No persistir secretos ni documentos sensibles en almacenamiento del navegador.
- No prometer rentabilidad ni usar porcentaje aportado como porcentaje de propiedad. Mostrar términos, estado de elegibilidad y límites conforme a decisiones aprobadas.
- Una demo debe indicar datos ficticios y desactivar las rutas reales desde el sistema, no solo con un cartel.
- Verificar componentes con estados críticos y un recorrido integrado del flujo cambiado. Revisar accesibilidad básica y comportamiento responsivo cuando el cambio lo afecte.
