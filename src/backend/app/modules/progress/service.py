"""Cálculo del progreso a partir de los intentos guardados (ADR-010)."""

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from app.models import Intento
from app.modules.progress.schemas import (
    DayStats,
    LangStats,
    ProgressSummary,
    WordProgress,
)

# Una palabra se considera dominada con 3 aciertos en inglés SIN ayuda.
MASTERY_SUCCESSES = 3
# "Por reforzar": al menos 3 intentos y menos del 40 % de aciertos sin ayuda.
STRUGGLE_MIN_ATTEMPTS = 3
STRUGGLE_RATIO = 0.4

MAX_PAST_DAYS = 30  # un intento en cola sin conexión no puede ser más viejo que esto
FUTURE_TOLERANCE = timedelta(minutes=5)


def normalize_attempt_time(value: datetime | None, now: datetime) -> datetime:
    """Usa la hora enviada por la app solo si es razonable; si no, la del servidor."""
    if value is None:
        return now
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    if value > now + FUTURE_TOLERANCE or value < now - timedelta(days=MAX_PAST_DAYS):
        return now
    return value


def _local_date(moment: datetime, offset: timedelta) -> date:
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return (moment.astimezone(timezone.utc) + offset).date()


def build_summary(
    nino_id: int,
    attempts: list[Intento],
    now: datetime,
    tz_offset_minutes: int = 0,
    days: int = 7,
) -> ProgressSummary:
    offset = timedelta(minutes=tz_offset_minutes)
    today = _local_date(now, offset)

    per_word: dict[str, dict] = defaultdict(
        lambda: {
            "intentos": 0,
            "aciertos": 0,
            "asistidos": 0,
            "en_asistidos": 0,
            "en": LangStats(),
            "es": LangStats(),
            "ultima": None,
        }
    )
    per_day: dict[date, list[int]] = defaultdict(lambda: [0, 0])
    total_ok = total_assisted = 0

    for a in attempts:
        w = per_word[a.palabra]
        w["intentos"] += 1
        lang: LangStats = w[a.idioma] if a.idioma in ("en", "es") else w["en"]
        lang.intentos += 1
        if a.acierto:
            w["aciertos"] += 1
            lang.aciertos += 1
            total_ok += 1
            if a.asistido:
                w["asistidos"] += 1
                total_assisted += 1
                if a.idioma == "en":
                    w["en_asistidos"] += 1
        moment = a.fecha if a.fecha.tzinfo else a.fecha.replace(tzinfo=timezone.utc)
        if w["ultima"] is None or moment > w["ultima"]:
            w["ultima"] = moment

        d = _local_date(a.fecha, offset)
        per_day[d][0] += 1
        per_day[d][1] += 1 if a.acierto else 0

    # --- por palabra ---------------------------------------------------------------------
    words: list[WordProgress] = []
    for palabra, w in per_word.items():
        en_unassisted = w["en"].aciertos - w["en_asistidos"]
        unassisted = w["aciertos"] - w["asistidos"]

        if en_unassisted >= MASTERY_SUCCESSES:
            estado = "dominada"
        elif w["intentos"] >= STRUGGLE_MIN_ATTEMPTS and unassisted / w["intentos"] < STRUGGLE_RATIO:
            estado = "reforzar"
        else:
            estado = "practicando"

        words.append(
            WordProgress(
                palabra=palabra,
                estado=estado,
                intentos=w["intentos"],
                aciertos=w["aciertos"],
                asistidos=w["asistidos"],
                en=w["en"],
                es=w["es"],
                ultima_practica=w["ultima"],
            )
        )
    words.sort(key=lambda x: x.ultima_practica, reverse=True)

    # --- por día -------------------------------------------------------------------------
    last_days = [today - timedelta(days=i) for i in range(days - 1, -1, -1)]
    daily = [
        DayStats(fecha=d, intentos=per_day[d][0] if d in per_day else 0, aciertos=per_day[d][1] if d in per_day else 0)
        for d in last_days
    ]
    active_days = sum(1 for d in daily if d.intentos > 0)

    # Racha: días seguidos con práctica, contando desde hoy (o desde ayer si hoy aún no practicó).
    streak = 0
    cursor = today if today in per_day else today - timedelta(days=1)
    while cursor in per_day:
        streak += 1
        cursor -= timedelta(days=1)

    return ProgressSummary(
        nino_id=nino_id,
        total_intentos=len(attempts),
        total_aciertos=total_ok,
        aciertos_asistidos=total_assisted,
        palabras_practicadas=len(words),
        palabras_dominadas=sum(1 for x in words if x.estado == "dominada"),
        palabras_por_reforzar=sum(1 for x in words if x.estado == "reforzar"),
        dias_activos_semana=active_days,
        racha_dias=streak,
        ultimos_dias=daily,
        palabras=words,
    )
