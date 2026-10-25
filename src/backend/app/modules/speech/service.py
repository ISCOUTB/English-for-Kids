"""Comparación entre la palabra objetivo y lo que entendió el reconocimiento de voz."""

import re
from difflib import SequenceMatcher

from app.core.text import fold

# El reconocimiento de voz devuelve palabras reales del diccionario, así que normalmente
# basta la coincidencia exacta. Solo se tolera una diferencia pequeña en palabras LARGAS
# (6+ letras), p. ej. "elefant" ~ "elephant". En palabras cortas se exige coincidencia
# exacta porque ninguna medida de similitud separa de forma fiable "horse" de "house"
# (ambas dan 0.8 igual que "elephant" y "elefant"). Estos valores hay que ajustarlos
# con grabaciones reales de niños.
FUZZY_MIN_LENGTH = 6
FUZZY_THRESHOLD = 0.8


def _tokens(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", fold(text))


def _close(target: str, heard: str) -> bool:
    if target == heard:
        return True
    if min(len(target), len(heard)) < FUZZY_MIN_LENGTH:
        return False
    return SequenceMatcher(None, target, heard).ratio() >= FUZZY_THRESHOLD


def is_match(target: str, transcript: str) -> bool:
    """True si la palabra (o frase) objetivo aparece en lo que dijo el niño."""
    wanted = _tokens(target)
    heard = _tokens(transcript)
    if not wanted or not heard:
        return False
    size = len(wanted)
    for start in range(len(heard) - size + 1):
        window = heard[start : start + size]
        if all(_close(w, h) for w, h in zip(wanted, window)):
            return True
    return False
