# English-for-Kids

App móvil (Flutter) para que niños de 3 a 6 años aprendan inglés con imágenes, audio, voz e historias. Este repositorio contiene la documentación y el **backend** (FastAPI + PostgreSQL). La app Flutter irá en `frontend/`.

Documentación: [`docs/requisitos.md`](docs/requisitos.md) · [`docs/arquitectura.md`](docs/arquitectura.md) · [`docs/decisiones.md`](docs/decisiones.md)

## Estructura

```
backend/
  app/
    core/        configuración, base de datos, sesión (JWT) y permisos
    providers/   interfaces y adaptadores de Google AI Studio y ElevenLabs
    modules/     auth · family · stories · speech
    models.py    tablas (modelo entidad-relación)
    main.py
  Dockerfile
tests/           68 pruebas automáticas (no llaman a servicios externos)
docs/
```

## Ejecutar en local

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

cp ../.env.example .env        # y completa SECRET_KEY (mira las instrucciones dentro)
# Para probar sin PostgreSQL, en .env pon:  DATABASE_URL=sqlite:///./dev.db

uvicorn app.main:app --reload
```

Documentación interactiva de la API: http://localhost:8000/docs

## Pruebas

```bash
pip install -r backend/requirements-dev.txt
pytest
```

## Endpoints

| Método y ruta | Qué hace |
|---|---|
| `POST /auth/register` · `POST /auth/login` | Registro e inicio de sesión con `nombre` y `correo` del tutor |
| `GET /auth/me` | Tutor de la sesión |
| `POST/GET /children` · `DELETE /children/{id}` | Perfiles de niños (apodo y rango de edad) |
| `POST/GET /consents` | Consentimiento de voz del tutor (aceptar o revocar) |
| `POST /stories` · `GET /stories?nino_id=` · `GET /stories/{id}` | Crear y consultar historias |
| `GET /stories/{id}/audio` | Narración en mp3 (se genera una vez y se guarda en caché) |
| `POST /speech/judge` | Segunda opinión con IA: recibe el **texto** que reconoció el teléfono, el `idioma` (`en` o `es`) de la palabra, y responde `acierto` o `intentar_de_nuevo` (requiere consentimiento) |
| `POST /speech/check` | Respaldo: recibe el **audio**, lo transcribe con ElevenLabs y compara (requiere consentimiento) |
| `GET /health` · `GET /health/db` | Estado del servicio y de la base de datos |

Todas las rutas, salvo `/auth/register`, `/auth/login` y `/health*`, exigen la cabecera `Authorization: Bearer <token>`.

## Despliegue (panel.iscoutb.dev)

1. En el panel (Dokploy) usa *Build Type* **Dockerfile**, con *Docker File* `backend/Dockerfile` y *Docker Context Path* `backend`. Puerto del contenedor: `8000`. Usa la rama donde esté el código.
2. En la pestaña **Environment** escribe las variables y pulsa **Save**. El panel las guarda en un `.env` junto al Dockerfile, que la imagen copia (por eso no subas ese `.env` a GitHub ni publiques la imagen):
   - `SECRET_KEY` (mínimo 32 caracteres), `GOOGLE_API_KEY`, `ELEVENLABS_API_KEY`
   - `DATABASE_URL`: copia la *Internal Connection URL* de la base de datos del panel. No escribas el host a mano.
3. Pulsa **Deploy** y revisa los **Logs**: debe aparecer `Uvicorn running on http://0.0.0.0:8000`.
4. Asigna un dominio (puerto `8000`; el automático `sslip.io` solo sirve por HTTP) y comprueba `/health/db` y `/docs`.

> Los audios de las historias se guardan en `data/audio`. Si la plataforma reinicia el contenedor sin un volumen persistente, se vuelven a generar al pedirlos (cuesta una llamada a ElevenLabs por historia).
