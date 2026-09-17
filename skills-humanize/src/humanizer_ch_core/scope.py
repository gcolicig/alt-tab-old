from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256

from .errors import ErrorCode, HumanizerError


def digest_text(text: str) -> str:
    return f"sha256:{sha256(text.encode('utf-8')).hexdigest()}"


@dataclass(frozen=True)
class Document:
    text: str
    revision: str
    segment_id: str = "t00001"
    format_node_id: str = "node-00001"


@dataclass(frozen=True)
class Selection:
    source_revision: str
    segment_id: str
    format_node_id: str
    start: int
    end: int
    source_hash: str
    text: str

    def as_dict(self) -> dict[str, object]:
        return {
            "source_revision": self.source_revision,
            "segment_id": self.segment_id,
            "format_node_id": self.format_node_id,
            "span": {"start": self.start, "end": self.end},
            "source_hash": self.source_hash,
        }


def create_document(text: str) -> Document:
    if not text:
        raise HumanizerError(ErrorCode.INPUT_EMPTY, "Leerer Text kann nicht geprüft werden.", "scope", safe_action="fix_input")
    return Document(text=text, revision=digest_text(text))


def select_span(document: Document, start: int = 0, end: int | None = None) -> Selection:
    actual_end = len(document.text) if end is None else end
    if start < 0 or actual_end <= start or actual_end > len(document.text):
        raise HumanizerError(ErrorCode.INPUT_SCOPE_INVALID, "Auswahl liegt ausserhalb des Textes.", "scope", safe_action="review_scope")
    selected = document.text[start:actual_end]
    return Selection(
        source_revision=document.revision,
        segment_id=document.segment_id,
        format_node_id=document.format_node_id,
        start=start,
        end=actual_end,
        source_hash=digest_text(selected),
        text=selected,
    )


def verify_selection(document: Document, selection: Selection) -> None:
    current = select_span(document, selection.start, selection.end)
    if current.source_revision != selection.source_revision or current.source_hash != selection.source_hash:
        raise HumanizerError(
            ErrorCode.INPUT_REVISION_MISMATCH,
            "Die Auswahl gehört nicht mehr zur aktuellen Dokumentrevision.",
            "scope",
            safe_action="review_scope",
        )
