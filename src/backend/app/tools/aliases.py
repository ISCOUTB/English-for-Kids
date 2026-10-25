"""Generador de alias: se ejecuta UNA vez, mientras desarrollas (no forma parte del servidor).

Para cada palabra del vocabulario, le pide a Gemini las transcripciones erróneas más probables
que daría un reconocedor de voz automático cuando un niño hispanohablante intenta decirla.
Esas listas se guardan en el vocabulario de la app: así la IA se usa donde es fuerte (generar
listas) y no en cada intento del niño.

Uso (desde la carpeta backend, con GOOGLE_API_KEY definida en el entorno o en .env):

    python -m app.tools.aliases cat dog elephant --out aliases.json
    python -m app.tools.aliases --words-file palabras.txt --out aliases.json

RESULTADO A REVISAR A MANO: la IA se equivoca. Léelo antes de pegarlo en la app, y quita los
alias que sean otra palabra real del vocabulario (si "cap" fuera una tarjeta, "cap" no puede
ser alias de "cat").
"""

import argparse
import json
import re
import sys
from pathlib import Path

from app.core.config import get_settings
from app.providers.base import ProviderError
from app.providers.gemini import GeminiTextGenerator

MAX_ALIASES = 10
_ALIAS_RE = re.compile(r"^[a-z]+(?:['\- ][a-z]+)*$")

SYSTEM = (
    "Eres un experto en reconocimiento automático de voz (ASR) y en adquisición de inglés como "
    "segunda lengua por niños hispanohablantes de 3 a 6 años. Respondes solo con JSON válido."
)


def build_prompt(words: list[str]) -> str:
    listed = json.dumps(words, ensure_ascii=False)
    return (
        "Para cada palabra en inglés de la lista, da hasta 8 transcripciones ERRÓNEAS pero "
        "probables que un reconocedor de voz en inglés devolvería cuando un niño pequeño "
        "hispanohablante intenta decirla (cambios de vocal, consonantes omitidas, palabras "
        "reales que suenan parecido, grafías fonéticas como 'kat').\n"
        "Reglas: minúsculas, solo letras a-z (se permiten espacio, apóstrofo o guion en medio), "
        "sin repetir la palabra original.\n"
        'Formato exacto: {"palabra": ["alias1", "alias2"], ...}\n'
        f"Palabras: {listed}"
    )


def parse_aliases(raw: str, words: list[str]) -> dict[str, list[str]]:
    """Convierte la respuesta de la IA en un diccionario limpio. Lo que no sirva se descarta."""
    text = raw.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)  # quita ``` si la IA los puso
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError("La respuesta de la IA no es JSON válido") from exc
    if not isinstance(data, dict):
        raise ValueError("Se esperaba un objeto JSON {palabra: [alias]}")

    allowed = {w.lower(): w for w in words}
    result: dict[str, list[str]] = {w: [] for w in words}
    for key, values in data.items():
        original = allowed.get(str(key).strip().lower())
        if original is None or not isinstance(values, list):
            continue  # palabra que no pedimos, o formato raro
        seen: set[str] = set()
        for value in values:
            alias = " ".join(str(value).lower().split())
            if (
                alias
                and alias != original.lower()
                and len(alias) <= 20
                and _ALIAS_RE.match(alias)
                and alias not in seen
                and alias not in allowed  # nunca una palabra del propio vocabulario
            ):
                seen.add(alias)
                result[original].append(alias)
        result[original] = result[original][:MAX_ALIASES]
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Genera alias de pronunciación con Gemini")
    parser.add_argument("words", nargs="*", help="palabras en inglés")
    parser.add_argument("--words-file", help="archivo con una palabra por línea")
    parser.add_argument("--out", default="aliases.json", help="archivo de salida")
    args = parser.parse_args(argv)

    words = list(args.words)
    if args.words_file:
        words += [ln.strip() for ln in Path(args.words_file).read_text(encoding="utf-8").splitlines()]
    words = list(dict.fromkeys(w.strip() for w in words if w.strip()))  # sin vacías ni repetidas
    if not words:
        parser.error("Indica al menos una palabra")

    settings = get_settings()
    generator = GeminiTextGenerator(api_key=settings.google_api_key, model=settings.gemini_model)

    aliases: dict[str, list[str]] = {}
    try:
        for start in range(0, len(words), 15):  # por lotes pequeños: respuestas más fiables
            batch = words[start : start + 15]
            raw = generator.generate(build_prompt(batch), system=SYSTEM)
            aliases.update(parse_aliases(raw, batch))
    except (ProviderError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    Path(args.out).write_text(json.dumps(aliases, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Listo: {len(aliases)} palabras -> {args.out}. REVÍSALO a mano antes de usarlo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
