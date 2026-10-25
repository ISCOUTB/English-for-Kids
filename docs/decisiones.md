# Registro de decisiones — English-for-Kids

> Cada decisión importante se documenta en formato **ADR** (*Architecture Decision Record*).
> **Por qué se hace así:** dentro de seis meses nadie recordará por qué se eligió una opción y se descartó otra. Este registro conserva el razonamiento, no solo el resultado, y permite reabrir una decisión si cambian las condiciones.

**Estados posibles:** Aceptada · Propuesta (falta confirmar) · Pendiente (falta información) · Reemplazada

| ID | Decisión | Estado |
|---|---|---|
| ADR-001 | Monolito modular en vez de microservicios | Aceptada |
| ADR-002 | Vocabulario base empaquetado en la app (offline) | Aceptada |
| ADR-003 | Backend único como intermediario de las APIs externas | Aceptada |
| ADR-004 | Proveedores de IA y voz detrás de interfaces | Aceptada |
| ADR-005 | Despliegue en panel.iscoutb.dev con Docker | Aceptada (desplegado, con limitaciones) |
| ADR-006 | Canales de TV infantil (iptv-org) aplazados | Aceptada |
| ADR-007 | Base de datos: PostgreSQL de la plataforma | Aceptada |
| ADR-008 | Inicio de sesión del tutor con nombre y correo | Aceptada (con riesgo conocido) |

---

## ADR-001 — Monolito modular en vez de microservicios

**Estado:** Aceptada

**Contexto.** La app tiene partes de naturaleza distinta: vocabulario local, historias con IA, reconocimiento de voz y progreso del niño. Se propuso inicialmente una arquitectura de microservicios para separarlas. El equipo es de tres estudiantes, el proyecto es un prototipo y el despliegue se hará en un único servidor.

**Decisión.** Un único backend dividido internamente en módulos con límites claros, y una app Flutter organizada por funcionalidades.

**Alternativas consideradas.**
- *Microservicios:* permiten escalar y desplegar cada parte por separado, pero añaden costos (varios contenedores, comunicación por red que puede fallar, depuración distribuida, más configuración de despliegue). Esos beneficios aplican a equipos grandes o sistemas con mucha carga, y no a este proyecto.
- *Monolito sin módulos:* más simple al inicio, pero mezcla responsabilidades y dificulta cambiar proveedores (RNF-03).

**Consecuencias.**
- (+) Un solo contenedor, despliegue y depuración más simples.
- (+) La modularidad interna cumple RNF-03 sin pagar el costo de la red.
- (+) Si más adelante un módulo necesita separarse, los límites ya existen.
- (−) Todo escala junto. Aceptable para un prototipo.
- (−) Exige disciplina: los módulos solo se comunican por sus interfaces públicas.

---

## ADR-002 — Vocabulario base empaquetado en la app

**Estado:** Aceptada

**Contexto.** Las funciones centrales (RF-01 y RF-02) deben responder rápido (<500 ms para el audio) y no depender de la red ni generar costos por uso.

**Decisión.** Las imágenes y los audios del vocabulario inicial (20–30 palabras) se incluyen en la app al instalarla.

**Alternativas consideradas.**
- *Descargar el contenido desde el backend:* permite actualizar sin publicar una nueva versión, pero agrega latencia, requiere internet y costos de servidor.

**Consecuencias.**
- (+) La parte principal funciona sin internet.
- (+) Latencia mínima y costo cero por uso.
- (−) Agregar palabras requiere actualizar la app.
- ⚠️ **Pendiente:** el repositorio de origen `anromanova/english-for-kids` es un proyecto de curso de otra persona y no se observó una licencia. Antes de usar sus imágenes y audios hay que confirmar que se pueden reutilizar; si no, se usarán recursos con licencia clara o propios.

---

## ADR-003 — Backend único como intermediario de las APIs externas

**Estado:** Aceptada (implementada en `backend/`)

**Contexto.** Las historias usan Google AI Studio (texto) y ElevenLabs (audio y reconocimiento de voz). Estas APIs requieren llaves secretas.

**Decisión.** La app Flutter nunca llama directamente a los proveedores. Siempre pasa por el backend, que guarda las llaves, valida las peticiones y registra el uso.

**Alternativas consideradas.**
- *Llamar desde Flutter:* menos código, pero las llaves viajarían dentro de la app y cualquiera podría extraerlas y gastar la cuota.

**Consecuencias.**
- (+) Las llaves nunca salen del servidor.
- (+) Se puede limitar el uso por usuario, **moderar el contenido** generado para niños y **guardar en caché** historias y audios ya generados para no pagar dos veces.
- (−) El backend pasa a ser un punto único de fallo y requiere estar desplegado.
- Consecuencia práctica: los endpoints del prototipo (`/generate-story`, `/tts`, `/list-models`) estaban abiertos a cualquiera; quien conociera la URL podía gastar la cuota de las APIs. Se reemplazaron por endpoints que exigen sesión de tutor, validan las palabras, limitan las historias por día y no exponen los mensajes de error internos.

---

## ADR-004 — Proveedores de IA y voz detrás de interfaces

**Estado:** Aceptada (implementada en `backend/app/providers/`)

**Contexto.** En el documento inicial se comparaban Azure AI Speech y Whisper para el reconocimiento de voz; ahora se plantea ElevenLabs. Ninguno ha sido evaluado con voz de niños de 3 a 6 años.

**Decisión.** El backend define interfaces (generador de texto, voz a texto, texto a voz) y cada proveedor es una implementación intercambiable. Los primeros proveedores serán Google AI Studio y ElevenLabs.

**Consecuencias.**
- (+) Cambiar de proveedor implica modificar un solo archivo de adaptación (cumple RNF-03).
- (+) Permite comparar proveedores con pruebas reales.
- (−) Un poco más de código al inicio.
- Se usa el SDK actual de Google (`google-genai`): el que usaba el prototipo (`google-generativeai`) está en desuso desde noviembre de 2025. Para voz a texto se usa ElevenLabs (modelo `scribe_v2`, configurable).
- ⚠️ **Por validar:** la precisión del reconocimiento con voz infantil, la latencia y el costo de cada proveedor. Las llamadas reales a Google y ElevenLabs aún no se han probado con llaves; las pruebas automáticas usan proveedores simulados.

---

## ADR-005 — Despliegue en panel.iscoutb.dev con Docker

**Estado:** Propuesta

**Contexto.** La universidad ofrece la plataforma `panel.iscoutb.dev` para desplegar proyectos y se tiene permiso para usarla. Sustituye la plataforma de despliegue planteada al inicio.

**Decisión.** El backend se empaquetará en un contenedor Docker y se desplegará en esa plataforma.

**Consecuencias.**
- (+) Sin costo de hosting y bajo el control de la universidad.
- (+) Docker hace el entorno reproducible.
- La plataforma ofrece bases de datos PostgreSQL (ya se creó una para el proyecto, ver ADR-007).
- **Resultado del primer despliegue (24/10/2026):** la API quedó corriendo en la plataforma (Dokploy). Lo aprendido:
  - Se configura con *Docker File* `backend/Dockerfile` y *Docker Context Path* `backend`; el contenedor escucha en el puerto 8000.
  - La plataforma **no entrega las variables como variables de entorno del contenedor**: escribe un archivo `.env` junto al Dockerfile durante el build. Por eso el `Dockerfile` copia `.env*` a la imagen y la app lo lee al arrancar.
  - La conexión a la base se hace con `DATABASE_URL` copiada de *Internal Connection URL* del panel. Escribir el host a mano falló por letras que se confunden (`i`, `l`, `1`).
  - El dominio automático (`sslip.io`) solo sirve por HTTP; no ofrece HTTPS.
- (−) **Los secretos quedan dentro de la imagen** del contenedor. Es aceptable mientras la imagen no salga del servidor de la universidad; no debe publicarse en un registro público.
- (−) Sin HTTPS, el token de sesión viaja sin cifrar. Es tolerable para pruebas del prototipo; antes de usarlo con familias reales hay que conseguir un dominio con HTTPS.
- ⚠️ **Pendiente:** definir si hay un volumen persistente para los audios de las historias (si no, se regeneran al reiniciar) y conocer los límites de recursos.

---

## ADR-006 — Canales de TV infantil (iptv-org) aplazados

**Estado:** Aceptada

**Contexto.** Se planteó una sección de canales infantiles usando la base de datos comunitaria iptv-org.

**Decisión.** Queda fuera del alcance de la primera versión y se registra como mejora futura.

**Razones.**
- Los canales provienen de enlaces comunitarios no curados para niños: pueden fallar, mostrar contenido inapropiado o tener problemas de licencia.
- Las tiendas de aplicaciones imponen políticas estrictas a apps infantiles.
- No aporta directamente al objetivo del prototipo (validar imagen → voz → retroalimentación).

**Consecuencias.** Si se retoma, deberá hacerse con una lista corta de canales revisados a mano, control parental y como módulo desactivable.

---

## ADR-007 — Base de datos: PostgreSQL de la plataforma

**Estado:** Aceptada

**Contexto.** El documento inicial planteaba Supabase (PostgreSQL con Row Level Security). Al desplegar un backend propio en la universidad, había que decidir dónde se guardan los datos de progreso.

**Decisión.** Se usa la base de datos PostgreSQL que ofrece `panel.iscoutb.dev` (ya creada para el proyecto). Solo el backend se conecta a ella, por la red interna de la plataforma. Las tablas siguen el modelo entidad-relación y se crean al arrancar el backend.

**Alternativas consideradas.**
- *Supabase:* ofrece Row Level Security y autenticación listas, pero añade un servicio externo más cuando la plataforma ya incluye PostgreSQL.

**Consecuencias.**
- (+) Sin servicios extra ni costo; los datos de menores quedan dentro de la infraestructura de la universidad.
- (−) No hay Row Level Security: **el aislamiento entre familias lo garantiza el código del backend**. Cada endpoint que toca datos de un niño debe verificar que pertenezca al tutor de la sesión (función `get_owned_child`). Hay pruebas automáticas que lo comprueban; cualquier endpoint nuevo debe usar la misma regla.
- (−) La creación automática de tablas no modifica tablas existentes. Cuando el esquema cambie hará falta usar migraciones (Alembic).
- (−) La conexión real a la base del panel todavía no se ha probado; las pruebas automáticas usan SQLite.

---

## ADR-008 — Inicio de sesión del tutor con nombre y correo

**Estado:** Aceptada (con riesgo conocido)

**Contexto.** Se quiere que el tutor inicie sesión de la forma más simple posible, con su nombre y su correo.

**Decisión.** El tutor se registra y entra con nombre y correo, sin contraseña. El backend entrega un token firmado (JWT) que dura 7 días y la app lo envía en cada petición. El nombre se compara sin distinguir mayúsculas, tildes ni espacios repetidos, y los errores no revelan cuál de los dos datos falló.

**Alternativas consideradas.**
- *Contraseña:* más conocida, pero más fricción y obliga a guardar contraseñas de forma segura.
- *Código de un solo uso enviado al correo:* seguro y sin contraseñas, pero requiere un servicio de envío de correos.

**Consecuencias.**
- (+) Registro e inicio de sesión muy simples.
- (−) **El nombre no es un secreto:** quien conozca el nombre y el correo de un tutor puede entrar como él, ver el progreso e historias de sus niños y borrar sus perfiles.
- Mitigaciones actuales: los niños solo tienen apodo y rango de edad; no se guarda el audio de su voz; los tokens vencen; y cada recurso se verifica contra el tutor de la sesión.
- ⚠️ **Mejora prevista:** reemplazar el nombre por un código enviado al correo antes de abrir la app a usuarios reales. Está pendiente averiguar si la universidad ofrece un servicio de correo.