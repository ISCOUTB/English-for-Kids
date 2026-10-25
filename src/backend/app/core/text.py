"""Utilidades de texto compartidas."""

import unicodedata


def fold(text: str) -> str:
    """Minúsculas, sin acentos y con espacios normalizados.

    "  José   PÉREZ " -> "jose perez". Sirve para comparar nombres y palabras
    sin que importen mayúsculas, tildes ni espacios de más.
    """
    decomposed = unicodedata.normalize("NFKD", text)
    no_marks = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(no_marks.casefold().split())
