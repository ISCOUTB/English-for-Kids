from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_db
from app.core.deps import get_current_tutor, get_owned_child
from app.models import Tutor
from app.core.ratelimit import RateLimiter
from app.modules.family.consent import has_consent
from app.modules.speech.schemas import JudgeIn, JudgeOut, SpeechCheckOut
from app.modules.speech.service import is_match
from app.providers import get_judge_limiter, get_pronunciation_judge, get_speech_to_text
from app.providers.base import PronunciationJudge, SpeechToText

router = APIRouter(prefix="/speech", tags=["speech"])


@router.post("/judge", response_model=JudgeOut)
def judge_pronunciation(
    data: JudgeIn,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
    judge: PronunciationJudge = Depends(get_pronunciation_judge),
    limiter: RateLimiter = Depends(get_judge_limiter),
):
    """Segunda opinión con IA, para cuando las reglas locales de la app no aceptaron el intento.

    Recibe SOLO el texto que reconoció el teléfono (nunca audio). Sirve para inglés y español
    (`idioma`). Primero repite la comprobación local, que es gratis e instantánea; la IA solo
    se consulta si esa comprobación falla. Los niños de 3-4 años reciben más indulgencia.
    """
    child = get_owned_child(db, tutor, data.nino_id)

    if not has_consent(db, tutor.id, "voz"):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "El tutor debe dar su consentimiento antes de usar el micrófono.",
        )

    lenient = child.rango_edad == "3-4"  # a menor edad, más indulgencia
    if any(is_match(data.palabra, heard, lenient) for heard in data.escuchado):
        return JudgeOut(resultado="acierto")
    if not data.escuchado:  # el teléfono no entendió nada: no hay nada que juzgar
        return JudgeOut(resultado="intentar_de_nuevo")

    limiter.check(tutor.id)  # solo cuenta cuando realmente se va a gastar IA
    ok = judge.judge(data.palabra, data.escuchado, data.idioma, child.rango_edad)
    return JudgeOut(resultado="acierto" if ok else "intentar_de_nuevo")


@router.post("/check", response_model=SpeechCheckOut)
def check_pronunciation(
    nino_id: int = Form(...),
    palabra: str = Form(..., min_length=1, max_length=40, description="Palabra que el niño intentó decir"),
    audio: UploadFile = File(..., description="Grabación del intento"),
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    stt: SpeechToText = Depends(get_speech_to_text),
):
    """Transcribe el intento del niño y dice si coincide con la palabra.

    El audio se procesa en memoria y NO se guarda (privacidad de menores).
    """
    get_owned_child(db, tutor, nino_id)

    if not has_consent(db, tutor.id, "voz"):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "El tutor debe dar su consentimiento antes de usar el micrófono.",
        )

    data = audio.file.read(settings.max_audio_bytes + 1)
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "El audio llegó vacío.")
    if len(data) > settings.max_audio_bytes:
        raise HTTPException(status.HTTP_413_CONTENT_TOO_LARGE, "El audio es demasiado largo.")

    transcript = stt.transcribe(data, audio.content_type)
    return SpeechCheckOut(
        resultado="acierto" if is_match(palabra, transcript) else "intentar_de_nuevo",
        transcripcion=transcript,
    )
