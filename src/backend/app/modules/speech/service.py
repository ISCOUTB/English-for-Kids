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
# Modo indulgente (niños de 3-4 años): se tolera más en palabras de 4+ letras. Es más
# generoso a propósito: a esa edad conviene premiar el intento, y la IA da la segunda opinión.
LENIENT_MIN_LENGTH = 4
LENIENT_THRESHOLD = 0.7


def _tokens(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", fold(text))


def _close(target: str, heard: str, lenient: bool = False) -> bool:
    if target == heard:
        return True
    min_length = LENIENT_MIN_LENGTH if lenient else FUZZY_MIN_LENGTH
    threshold = LENIENT_THRESHOLD if lenient else FUZZY_THRESHOLD
    if min(len(target), len(heard)) < min_length:
        return False
    return SequenceMatcher(None, target, heard).ratio() >= threshold


def is_match(target: str, transcript: str, lenient: bool = False) -> bool:
    """True si la palabra (o frase) objetivo aparece en lo que dijo el niño.

    Sirve para inglés y español: `_tokens` ignora tildes y la ñ se compara como n.
    """
    wanted = _tokens(target)
    heard = _tokens(transcript)
    if not wanted or not heard:
        return False
    size = len(wanted)
    for start in range(len(heard) - size + 1):
        window = heard[start : start + size]
        if all(_close(w, h, lenient) for w, h in zip(wanted, window)):
            return True
    return False
