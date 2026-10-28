from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class TutorCredentials(BaseModel):
    """Datos para registrarse o iniciar sesión: nombre y correo del tutor."""

    nombre: str = Field(min_length=1, max_length=80, examples=["María Pérez"])
    correo: EmailStr = Field(examples=["maria@correo.com"])

    @field_validator("nombre")
    @classmethod
    def _clean_name(cls, value: str) -> str:
        value = " ".join(value.split())  # sin espacios repetidos ni en los extremos
        if not value:
            raise ValueError("El nombre no puede estar vacío")
        return value


class GoogleLoginIn(BaseModel):
    """Token de identidad que entrega Google a la app después de elegir la cuenta."""

    id_token: str = Field(min_length=20, max_length=4096)


class TutorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    correo: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    tutor: TutorOut
