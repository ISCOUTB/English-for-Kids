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
│   │ TextGenerator  SpeechToText │   │ BD (ADR-007)      │              │
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
| `speech` | Grabar la voz del niño, pedir el resultado al backend y mostrar la respuesta | RF-02, RF-03 |
| `stories` | Elegir palabras, solicitar la historia y reproducir su narración | RF-06, RF-07 |
| `progress` | Registrar intentos y mostrar avance al tutor | RF-04, RF-05 |
| `parent_zone` | Consentimiento, ajustes y panel del tutor, protegido para que el niño no entre solo | RNF-04, RF-05 |

### 3.2 Backend (FastAPI)

| Módulo | Responsabilidad | Requisitos |
|---|---|---|
| `stories` | Armar el prompt con las palabras, pedir el texto, filtrar/moderar, generar el audio y guardar en caché | RF-06, RF-07, RNF-05, RNF-06 |
| `speech` | Recibir el audio, obtener la transcripción y compararla con la palabra objetivo | RF-02, RF-03 |
| `progress` | Guardar aciertos y errores por palabra y calcular el dominio estimado | RF-04, RF-05 |
| `auth` | Identificar al tutor y proteger los datos de cada niño | RNF-02 |
| `providers` | Interfaces y adaptadores para Google AI Studio y ElevenLabs | RNF-03, RNF-05 |

**Regla de dependencias:** los módulos de negocio (`stories`, `speech`, `progress`) usan las *interfaces* de `providers`, nunca un proveedor concreto. Por eso cambiar de ElevenLabs a otro servicio solo afecta al adaptador.

---

## 4. Flujos principales

### 4.1 Tocar una palabra (RF-01)
1. El niño toca la imagen.
2. La app reproduce el audio **local**. No interviene el backend ni la red.

### 4.2 Repetir una palabra (RF-02, RF-03, RF-04)
1. La app graba el intento del niño (solo si el tutor dio el consentimiento).
2. Envía el audio y el identificador de la palabra al backend.
3. El módulo `speech` obtiene la transcripción mediante la interfaz `SpeechToText`.
4. Compara la transcripción con la palabra objetivo (normalizando mayúsculas, signos y variantes simples).
5. Devuelve un resultado **categórico** ("acierto" o "intentar otra vez"), sin porcentajes.
6. La app muestra una animación o frase positiva y el módulo `progress` registra el intento.

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

- El backend se empaqueta en un contenedor **Docker (Dockerfile)** y se despliega en `panel.iscoutb.dev` (ADR-005).
- La app Flutter se distribuye como APK de Android (RNF-01).

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
  app/modules/ (stories, speech, progress, auth)
  app/providers/ (interfaces y adaptadores)
  Dockerfile
tests/
```

---

## 8. Trazabilidad requisito → componente

| Requisito | Componente principal |
|---|---|
| RF-01 | `vocabulary` (app) |
| RF-02 | `speech` (app y backend) + `SpeechToText` |
| RF-03 | `speech` (app) |
| RF-04 | `progress` (backend) |
| RF-05 | `progress` y `parent_zone` |
| RF-06, RF-07 | `stories` (app y backend) + `TextGenerator`, `TextToSpeech` |
| RNF-01 | Flutter |
| RNF-02, RNF-04 | `auth` y `parent_zone` |
| RNF-03 | `providers` (interfaces) |
| RNF-05, RNF-06 | `stories` y configuración del backend |
| RNF-07 | `vocabulary` (assets locales) |
| RNF-08 | Docker y despliegue |

---

## 9. Pendientes

- Elegir base de datos y modelo de autenticación (ADR-007) y dibujar el `modelo-er.png`.
- Confirmar los requisitos de la plataforma de despliegue (ADR-005).
- Validar el reconocimiento de voz infantil con el proveedor elegido.
- Confirmar la licencia de los recursos de vocabulario.
