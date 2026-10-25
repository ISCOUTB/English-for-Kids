from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChildIn(BaseModel):
    # Datos mínimos a propósito: apodo y rango de edad, nunca nombre completo ni fecha de nacimiento.
    apodo: str = Field(min_length=1, max_length=40, examples=["Lulú"])
    rango_edad: Literal["3-4", "5-6"]
    avatar: str | None = Field(default=None, max_length=40)

    @field_validator("apodo")
    @classmethod
    def _clean(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("El apodo no puede estar vacío")
        return value


class ChildOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    apodo: str
    rango_edad: str
    avatar: str | None


class ConsentIn(BaseModel):
    tipo: Literal["voz"]
    aceptado: bool


class ConsentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    tipo: str
    aceptado: bool
    fecha: datetime
