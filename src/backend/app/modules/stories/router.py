from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_db
from app.core.deps import get_current_tutor, get_owned_child
from app.models import Historia, Nino, Tutor
from app.modules.stories.schemas import StoryIn, StoryOut
from app.modules.stories.service import create_story, ensure_audio, story_out
from app.providers import get_text_generator, get_text_to_speech
from app.providers.base import TextGenerator, TextToSpeech

router = APIRouter(prefix="/stories", tags=["stories"])


def _get_owned_story(db: Session, tutor: Tutor, historia_id: int) -> Historia:
    historia = db.scalar(
        select(Historia)
        .join(Nino, Historia.nino_id == Nino.id)
        .where(Historia.id == historia_id, Nino.tutor_id == tutor.id)
    )
    if historia is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Historia no encontrada.")
    return historia


@router.post("", response_model=StoryOut, status_code=status.HTTP_201_CREATED)
def create(
    data: StoryIn,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    generator: TextGenerator = Depends(get_text_generator),
):
    nino = get_owned_child(db, tutor, data.nino_id)
    return story_out(create_story(db, tutor, nino, data, generator, settings))


@router.get("", response_model=list[StoryOut])
def list_stories(
    nino_id: int = Query(...),
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    nino = get_owned_child(db, tutor, nino_id)
    rows = db.scalars(
        select(Historia).where(Historia.nino_id == nino.id).order_by(Historia.id.desc())
    ).all()
    return [story_out(h) for h in rows]


@router.get("/{historia_id}", response_model=StoryOut)
def get_story(
    historia_id: int,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    return story_out(_get_owned_story(db, tutor, historia_id))


@router.get("/{historia_id}/audio", response_class=FileResponse)
def get_story_audio(
    historia_id: int,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    tts: TextToSpeech = Depends(get_text_to_speech),
):
    """Narración en mp3. Se genera la primera vez y después se sirve desde la caché."""
    historia = _get_owned_story(db, tutor, historia_id)
    path = ensure_audio(db, historia, tts, settings)
    return FileResponse(path, media_type="audio/mpeg")
