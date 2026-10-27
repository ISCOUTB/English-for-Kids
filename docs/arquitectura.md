# Arquitectura — English-for-Kids

> **Para qué sirve este documento:** `requisitos.md` dice *qué* debe hacer el sistema; este documento explica *con qué piezas* y *cómo se conectan* para lograrlo. Las razones de cada elección están en `decisiones.md`.

Versión: 0.1 (borrador)

---

## 1. Estilo arquitectónico

**Monolito modular** (ver ADR-001): una app móvil en Flutter y un único backend. Cada responsabilidad vive en su propio módulo con una interfaz clara, pero todo el backend se despliega como un solo contenedor.

**Principios que guían el diseño**
1. **Offline primero para lo esencial:** el vocabulario base funciona sin internet (ADR-002).
2. **Las llaves secretas nunca salen del servidor:** la app solo habla con nuestro backend (ADR-003).
3. **Los proveedores externos son reemplazables:** se usan a través de interfaces (ADR-004).
4. **Seguridad y privacidad por defecto:** los usuarios son menores de edad.

---

## 2. Vista general

```
┌────────────────────────── App móvil (Flutter) ──────────────────────────┐
│  vocabulario   historias   voz (micrófono)   progreso   zona del tutor  │
│  (local, sin     │            │                 │            │          │
│   internet)      │            │                 │            │          │
└──────────────────┼────────────┼─────────────────┼────────────┼──────────┘
                   │  HTTPS     │                 │            │
                   ▼            ▼                 ▼            ▼
┌──────────────── Backend único (FastAPI en Docker) ─────────────────────┐
│  módulo stories   módulo speech   módulo progress   módulo auth        │
│        │               │                │                │             │
│        ▼               ▼                ▼                ▼             │
│   ┌─ Interfaces de proveedores ─┐   ┌────── Datos ──────┐              │
│   │ TextGenerator  SpeechToText │   │ PostgreSQL        │              │
│   │ TextToSpeech                │   │ Caché de historias│              │
│   └───────┬─────────────┬───────┘   │ y audios          │              │
└───────────┼─────────────┼───────────┴───────────────────┘──────────────┘
            ▼             ▼
     Google AI Studio   ElevenLabs
       (historias)     (audio y voz)
```

Los proveedores de la parte inferior son las **primeras implementaciones**; pueden cambiarse sin tocar los módulos.

---

## 3. Componentes

### 3.1 App móvil (Flutter)

Organizada **por funcionalidad** y no por tipo de archivo. Así cada parte se puede entender, probar y cambiar de forma independiente.

| Módulo | Responsabilidad | Requisitos |
|---|---|---|
| `vocabulary` | Mostrar imágenes interactivas y reproducir audio local | RF-01, RNF-01 |
| `speech` | Reconocer la voz con el teléfono, aplicar el juez local (reglas y alias), consultar la segunda opinión si hace falta y mostrar la respuesta positiva | RF-02, RF-03 |
| `stories` | Elegir palabras, solicitar la historia y reproducir su narración | RF-06, RF-07 |
| `progress` | Registrar intentos y mostrar avance al tutor | RF-04, RF-05 |
| `parent_zone` | Consentimiento, ajustes y panel del tutor, protegido para que el niño no entre solo | RNF-04, RF-05 |

### 3.2 Backend (FastAPI)

| Módulo | Responsabilidad | Requisitos |
|---|---|---|
| `stories` | Armar el prompt con las palabras, pedir el texto, filtrar/moderar, generar el audio y guardar en caché | RF-06, RF-07, RNF-05, RNF-06 |
| `speech` | `POST /speech/judge`: segunda opinión con IA a partir del texto reconocido; `POST /speech/check`: respaldo que recibe audio y lo transcribe con ElevenLabs | RF-02, RF-03 |
| `progress` | Guardar los intentos por palabra y calcular el resumen (dominio, racha, días activos) al consultarlo (ADR-010) | RF-04, RF-05 |
| `auth` | Registro e inicio de sesión del tutor con nombre y correo; entrega el token de sesión (ADR-008) | RF-09, RNF-02 |
| `family` | Perfiles de niños, consentimiento del tutor y borrado de datos; regla "cada niño pertenece a un tutor" | RNF-02, RNF-04 |
| `providers` | Interfaces y adaptadores para Google AI Studio y ElevenLabs | RNF-03, RNF-05 |

**Regla de dependencias:** los módulos de negocio (`stories`, `speech`, `progress`) usan las *interfaces* de `providers`, nunca un proveedor concreto. Por eso cambiar de ElevenLabs a otro servicio solo afecta al adaptador.

---

## 4. Flujos principales

### 4.1 Tocar una palabra (RF-01)
1. El niño toca la imagen.
2. La app reproduce el audio **local**. No interviene el backend ni la red.

### 4.2 Repetir una palabra (RF-02, RF-03, RF-04)
1. El niño toca el micrófono (solo si el tutor dio el consentimiento).
2. El **teléfono** reconoce lo que dijo, en el idioma activo (inglés o español), y entrega varias alternativas de texto. El audio no llega a nuestro backend.
3. La app aplica el **juez local**: normaliza el texto y lo compara con la palabra, su clave fonética y sus alias. Si acepta, termina aquí (instantáneo, sin conexión).
4. Si no acepta y hay conexión, la app envía solo el **texto** y el `idioma` a `POST /speech/judge`; el backend usa la edad del niño para ser más o menos indulgente. El backend repite la comprobación local y, si también falla, pregunta a Gemini (booleano, temperatura 0, entrada sanitizada).
5. Si la segunda opinión falla o tarda más de unos 3 segundos, la app trata el intento como "intentar otra vez".
6. La app muestra una animación o frase positiva **local** (nunca porcentajes ni mensajes generados por la IA) y se registra el intento para el módulo `progress`.

Al acertar en un idioma, la app reproduce el audio de transición ("ahora en español" o "ahora en inglés") y activa el otro idioma; al acertar en ambos, celebra la palabra completa. Decisión y alternativas: ADR-009.

### 4.3 Crear una historia (RF-06, RF-07)
1. El niño o el tutor elige palabras estudiadas o escribe otras.
2. La app envía las palabras al backend.
3. `stories` revisa la caché; si ya existe una historia equivalente, la devuelve.
4. Si no, arma un prompt con reglas para niños (vocabulario simple, tono seguro), llama a `TextGenerator` y **filtra** el resultado.
5. Convierte el texto en audio con `TextToSpeech` y guarda ambos en caché.
6. La app muestra la historia y reproduce la narración.

---

## 5. Decisiones transversales

| Tema | Enfoque |
|---|---|
| **Seguridad de llaves** | Solo existen en variables de entorno del backend (`.env` no se versiona; `.env.example` documenta los nombres) |
| **Privacidad de menores** | Consentimiento del tutor antes de usar el micrófono; datos mínimos; acceso por usuario |
| **Moderación de contenido** | Prompts restrictivos, filtro posterior y vocabulario controlado en las historias |
| **Costos** | Caché de historias y audios, límite de uso por usuario |
| **Fallos de red o de proveedor** | El vocabulario funciona sin red; las historias y la voz muestran un mensaje amable y permiten reintentar |

---

## 6. Despliegue

- El backend se empaqueta en un contenedor **Docker** y se despliega en `panel.iscoutb.dev` (ADR-005).
- La app Flutter se distribuye como APK de Android (RNF-01).
- La base de datos PostgreSQL ya existe en la plataforma y solo es accesible por su red interna; el backend se conecta con `DATABASE_URL` (la *Internal Connection URL* del panel).
- La plataforma construye la imagen con `backend/Dockerfile` (contexto `backend`) y escribe las variables del panel en un `.env` que el Dockerfile copia a la imagen. El contenedor escucha en el puerto 8000. Detalles en ADR-005.
- El dominio automático solo ofrece HTTP; para usuarios reales hará falta un dominio con HTTPS.
- ⚠️ **Pendiente:** confirmar si hay un volumen persistente para los audios de las historias y los límites de recursos.

---

## 7. Estructura propuesta del repositorio

Se reemplaza la carpeta `src/` por dos carpetas, ya que hay dos aplicaciones:

```
README.md
.gitignore
.env.example
docs/
  requisitos.md · arquitectura.md · decisiones.md · informe-final.pdf
  diagramas/ (casos-de-uso.png, modelo-er.png)
frontend/            # Flutter
  lib/features/ (vocabulary, speech, stories, progress, parent_zone)
  assets/ (imágenes y audios del vocabulario)
backend/             # FastAPI
  app/modules/ (auth, family, stories, speech, progress)
  app/providers/ (interfaces y adaptadores)
  Dockerfile
tests/
```

---

## 8. Trazabilidad requisito → componente

| Requisito | Componente principal |
|---|---|
| RF-01 | `vocabulary` (app) |
| RF-02 | `speech` (app: reconocedor del teléfono y juez local; backend: `/speech/judge`) + `PronunciationJudge` |
| RF-03 | `speech` (app) |
| RF-04 | `progress` (backend) |
| RF-05 | `progress` y `parent_zone` |
| RF-06, RF-07 | `stories` (app y backend) + `TextGenerator`, `TextToSpeech` |
| RNF-01 | Flutter |
| RF-09 | `auth` (backend) y `parent_zone` (app) |
| RNF-02, RNF-04 | `auth`, `family` y `parent_zone` |
| RNF-03 | `providers` (interfaces) |
| RNF-05, RNF-06 | `stories` y configuración del backend |
| RNF-07 | `vocabulary` (assets locales) |
| RNF-08 | Docker y despliegue |

---

## 9. Pendientes

- Dibujar el `modelo-er.png`: el modelo ya está implementado en `backend/app/models.py`.
- Usar el dominio de cada palabra para ajustar qué palabras se sugieren al niño (motor adaptativo, RF-04): hoy el panel solo informa al tutor.
- Reemplazar el nombre por un código enviado al correo al iniciar sesión (ADR-008).
- Probar la conexión real con la base de datos del panel y el `Dockerfile`; confirmar los requisitos de la plataforma de despliegue (ADR-005).
- Probar las llamadas reales a Google AI Studio y ElevenLabs cuando estén las llaves.
- Añadir migraciones (Alembic) antes de cambiar el esquema de la base de datos.
- Validar el reconocimiento de voz infantil con el proveedor elegido.
- Confirmar la licencia de los recursos de vocabulario.
