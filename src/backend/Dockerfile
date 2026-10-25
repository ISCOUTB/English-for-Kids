FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# El servidor corre sin privilegios de administrador (buena práctica de seguridad).
RUN useradd --create-home appuser \
    && mkdir -p /srv/data/audio \
    && chown -R appuser /srv
USER appuser

EXPOSE 8000

# --proxy-headers: la plataforma pone un proxy delante y así se respetan sus cabeceras.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
