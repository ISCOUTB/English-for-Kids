"""Cambios mínimos de esquema para bases de datos que ya existen.

`Base.metadata.create_all` crea tablas que faltan, pero NO agrega columnas nuevas a tablas ya
creadas. Mientras no usemos Alembic, aquí se añaden de forma segura las columnas nuevas.
"""

import logging

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

log = logging.getLogger(__name__)


def upgrade_schema(engine: Engine) -> None:
    columns = {c["name"] for c in inspect(engine).get_columns("historia")}
    if "idioma" in columns:
        return

    log.info("Agregando la columna historia.idioma")
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE historia ADD COLUMN idioma VARCHAR(2) NOT NULL DEFAULT 'es'"))
        # Los cuentos viejos no guardaban su idioma: los que están en inglés se reconocen por
        # sus palabras más comunes (los cuentos en español solo mezclan palabras sueltas).
        conn.execute(
            text(
                "UPDATE historia SET idioma = 'en' "
                "WHERE lower(texto) LIKE '% the %' OR lower(texto) LIKE '% and %'"
            )
        )
