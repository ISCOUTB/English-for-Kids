"""Límite de uso simple en memoria (ventana deslizante) para proteger la cuota de la IA.

Limitación conocida: los contadores viven en la memoria del proceso. Si el contenedor se
reinicia, se vacían; y si algún día hay varias réplicas, cada una cuenta por separado.
Para un solo contenedor (ADR-001) es suficiente.
"""

import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, status


class RateLimiter:
    def __init__(self, limit: int, window_seconds: float):
        self.limit = limit
        self.window = window_seconds
        self._hits: dict[object, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: object) -> None:
        """Registra un uso. Si ya se superó el límite en la ventana, responde 429."""
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                raise HTTPException(
                    status.HTTP_429_TOO_MANY_REQUESTS,
                    "Demasiados intentos seguidos. Espera un momento.",
                )
            hits.append(now)
