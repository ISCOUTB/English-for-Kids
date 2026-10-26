import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# Letras de cualquier idioma, con espacios, guiones o apóstrofes SOLO en medio.
# No permite números, signos ni "<" ">" : así una palabra no puede colarle
# instrucciones a la IA (ver ADR-003 y RNF-06).
_WORD_RE = re.compile(r"^[^\W\d_]+(?:[ '\-][^\W\d_]+)*$")
_CONTROL_AND_TAGS = re.compile(r"[\x00-\x1f\x7f<>]")


class StoryIn(BaseModel):
    nino_id: int
    palabras: list[str] = Field(min_length=1, max_length=8, examples=[["cat", "dog"]])
    contexto: str | None = Field(default=None, max_length=200, examples=["un día de lluvia"])
    idioma: Literal["es", "en"] = "es"  # idioma en que se narra el cuento

    @field_validator("palabras")
    @classmethod
    def _validate_words(cls, words: list[str]) -> list[str]:
        clean: list[str] = []
        seen: set[str] = set()
        for raw in words:
            word = " ".join(raw.split())
            if len(word) > 30 or not _WORD_RE.match(word):
                raise ValueError(
                    "Cada palabra debe tener solo letras (máximo 30 caracteres), sin números ni símbolos."
                )
            if word.casefold() not in seen:
                seen.add(word.casefold())
                clean.append(word)
        return clean

    @field_validator("contexto")
    @classmethod
    def _clean_context(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(_CONTROL_AND_TAGS.sub(" ", value).split())
        return value or None


class StoryOut(BaseModel):
    id: int
    nino_id: int
    titulo: str
    texto: str
    creada_en: datetime
    audio_listo: bool
    idioma: Literal["es", "en"] = "es"
