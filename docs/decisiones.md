# Registro de decisiones — English-for-Kids

> Cada decisión importante se documenta en formato **ADR** (*Architecture Decision Record*).
> **Por qué se hace así:** dentro de seis meses nadie recordará por qué se eligió una opción y se descartó otra. Este registro conserva el razonamiento, no solo el resultado, y permite reabrir una decisión si cambian las condiciones.

**Estados posibles:** Aceptada · Propuesta (falta confirmar) · Pendiente (falta información) · Reemplazada

| ID | Decisión | Estado |
|---|---|---|
| ADR-001 | Monolito modular en vez de microservicios | Aceptada |
| ADR-002 | Vocabulario base empaquetado en la app (offline) | Aceptada |
| ADR-003 | Backend único como intermediario de las APIs externas | Propuesta |
| ADR-004 | Proveedores de IA y voz detrás de interfaces | Propuesta |
| ADR-005 | Despliegue en panel.iscoutb.dev con Docker | Propuesta |
| ADR-006 | Canales de TV infantil (iptv-org) aplazados | Aceptada |
| ADR-007 | Base de datos y autenticación | Pendiente |

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

**Estado:** Propuesta

**Contexto.** Las historias usan Google AI Studio (texto) y ElevenLabs (audio y reconocimiento de voz). Estas APIs requieren llaves secretas.

**Decisión.** La app Flutter nunca llama directamente a los proveedores. Siempre pasa por el backend, que guarda las llaves, valida las peticiones y registra el uso.

**Alternativas consideradas.**
- *Llamar desde Flutter:* menos código, pero las llaves viajarían dentro de la app y cualquiera podría extraerlas y gastar la cuota.

**Consecuencias.**
- (+) Las llaves nunca salen del servidor.
- (+) Se puede limitar el uso por usuario, **moderar el contenido** generado para niños y **guardar en caché** historias y audios ya generados para no pagar dos veces.
- (−) El backend pasa a ser un punto único de fallo y requiere estar desplegado.

---

## ADR-004 — Proveedores de IA y voz detrás de interfaces

**Estado:** Propuesta

**Contexto.** En el documento inicial se comparaban Azure AI Speech y Whisper para el reconocimiento de voz; ahora se plantea ElevenLabs. Ninguno ha sido evaluado con voz de niños de 3 a 6 años.

**Decisión.** El backend define interfaces (generador de texto, voz a texto, texto a voz) y cada proveedor es una implementación intercambiable. Los primeros proveedores serán Google AI Studio y ElevenLabs.

**Consecuencias.**
- (+) Cambiar de proveedor implica modificar un solo archivo de adaptación (cumple RNF-03).
- (+) Permite comparar proveedores con pruebas reales.
- (−) Un poco más de código al inicio.
- ⚠️ **Por validar:** la precisión del reconocimiento con voz infantil, la latencia y el costo de cada proveedor.

---

## ADR-005 — Despliegue en panel.iscoutb.dev con Docker

**Estado:** Propuesta

**Contexto.** La universidad ofrece la plataforma `panel.iscoutb.dev` para desplegar proyectos y se tiene permiso para usarla. Sustituye la plataforma de despliegue planteada al inicio.

**Decisión.** El backend se empaquetará en un contenedor Docker y se desplegará en esa plataforma.

**Consecuencias.**
- (+) Sin costo de hosting y bajo el control de la universidad.
- (+) Docker hace el entorno reproducible.
- ⚠️ **Pendiente:** no se conocen aún los requisitos de la plataforma (¿Dockerfile o docker-compose?, ¿variables de entorno?, ¿base de datos incluida?, ¿límites de recursos?, ¿dominio y HTTPS?). Esta decisión se confirma al revisarlos.

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

## ADR-007 — Base de datos y autenticación

**Estado:** Pendiente

**Contexto.** El documento inicial planteaba Supabase (PostgreSQL con Row Level Security). Al desplegar un backend propio en la universidad, hay que decidir dónde se guardan los datos de progreso y cómo se identifica a los usuarios.

**Opciones a evaluar.**
- PostgreSQL propio, accesible desde la plataforma de la universidad.
- Supabase, como estaba previsto, con el backend propio como intermediario o junto a él.

**Información que falta:** qué ofrece la plataforma de despliegue (¿hay base de datos?) y si las cuentas serán del tutor, del niño o de ambos. Esto afecta también a RNF-02 (privacidad).
