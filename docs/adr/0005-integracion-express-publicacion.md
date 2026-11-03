# ADR-0005: Express y publicación académica

Fecha: 2026-11-02. Estado: implementado por instrucción del usuario de completar la integración MVP y documentar sus flujos. Complementa ADR-0004 y sustituye el gateway Next para el recorrido web vigente. Las condiciones económicas siguen el alcance aprobado, sin nuevos derechos ni captación real.

## Problema y decisión

Había dos coordinadores de compra y ninguna forma completa de convertir la solicitud de un usuario en una franquicia comprable. Se usa Express/JWT y SQL como coordinador único; wallet firma vínculo, términos y cobro. Un usuario puede invertir y solicitar; admin revisa documentación privada, habilita y publica. Sin roles excluyentes.

Se elige AcademicProjectFactory con clave estable del proyecto para crear token+C4 idempotentemente. Cada publicación configura el controlador exclusivo y permisos antes de publicar; admin/verificador son cuentas técnicas distintas. Deployers auxiliares evitan superar EIP-170. Alternativa descartada: publicaciones manuales pegando direcciones, que no completaban el flujo solicitado y podían dejar proyectos desconectados. No se introduce proxy ni servicio externo.

## Actores, amenazas e invariantes

- Usuario autenticado opera solo su cuenta/wallet vinculada; no elige investorAddress ni emite directamente. Solicitar no permite publicar ni ser admin.
- Admin revisa/aprueba/publica y registra importes de prueba; verificador es el único que atesta la compra C4. Claves fuera de frontend/Git y opt-in para cuentas desbloqueadas locales.
- Un corte RPC no demuestra fracaso: intención SQL antes de emisión, clave C4 estable y recuperación por eventos. Publicación con misma clave no duplica contratos. Mes único en contrato; claim no duplica pagos.
- 1000 centavos USD de precio y seis decimales mUSDC de reparto; no mezclar escalas ni inventar tenencias SQL. Perfil privado fuera de cadena.
- Cierre conserva reclamos; transferencias ordinarias siguen bloqueadas. No agregar campañas, retornos fijos ni cascada real.

## Consecuencias y verificación

Manifest incluye factory; requiere redesplegar el fixture para publicar solicitudes. Express importa direcciones de fixtures y guarda las nuevas; el catálogo consulta la base y luego cadena. Un solo proceso escritor en el MVP, sin worker/indexador. Un reinicio de Hardhat requiere una base de prueba nueva, sin borrado automático.

58 pruebas de contratos y 14 escenarios integrados SQL/EVM pasan. No se comprobaron navegador/HTTP real ni un servidor MySQL/PostgreSQL; no se cambió una base de usuario ni se movieron activos reales. Ver [guía](../ACADEMIC-MVP.md).
