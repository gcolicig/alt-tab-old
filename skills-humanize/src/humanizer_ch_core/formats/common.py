from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Mapping, Protocol


class ReconstructionGuarantee(str, Enum):
    BYTE_IDENTICAL_NULL_EDIT = "byte_identical_null_edit"
    BYTE_PRESERVING_OUTSIDE_EDITS = "byte_preserving_outside_edits"
    SEMANTIC_EQUIVALENCE = "semantic_equivalence"


class FormatAdapterError(ValueError):
    """Raised when an input or edit cannot be handled without guessing."""


@dataclass(frozen=True)
class EditableSpan:
    node_id: str
    start: int | None
    end: int | None
    text: str
    pointer: str | None = None


@dataclass(frozen=True)
class ProtectedSpan:
    start: int
    end: int
    text: str
    kind: str


@dataclass(frozen=True)
class ParsedDocument:
    format: str
    source: bytes
    text: str
    editable_spans: tuple[EditableSpan, ...]
    protected_spans: tuple[ProtectedSpan, ...]
    guarantee: ReconstructionGuarantee
    metadata: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class VerificationResult:
    valid: bool
    guarantee: ReconstructionGuarantee
    errors: tuple[str, ...] = ()


class FormatAdapter(Protocol):
    format: str
    guarantee: ReconstructionGuarantee

    def detect(self, source: bytes) -> bool: ...

    def parse(self, source: bytes, **options: Any) -> ParsedDocument: ...

    def extract_editable_spans(self, document: ParsedDocument) -> tuple[EditableSpan, ...]: ...

    def protect(self, document: ParsedDocument) -> tuple[ProtectedSpan, ...]: ...

    def rebuild(self, document: ParsedDocument, replacements: Mapping[str, str]) -> bytes: ...

    def verify(
        self, document: ParsedDocument, rebuilt: bytes, replacements: Mapping[str, str]
    ) -> VerificationResult: ...


def decode_utf8(source: bytes) -> str:
    try:
        return source.decode("utf-8")
    except UnicodeDecodeError as error:
        raise FormatAdapterError("input is not valid UTF-8") from error


def validate_replacements(document: ParsedDocument, replacements: Mapping[str, str]) -> None:
    known = {span.node_id for span in document.editable_spans}
    unknown = set(replacements) - known
    if unknown:
        raise FormatAdapterError(f"unknown or non-editable nodes: {', '.join(sorted(unknown))}")
    if not all(isinstance(value, str) for value in replacements.values()):
        raise FormatAdapterError("replacement values must be strings")


def splice_text(document: ParsedDocument, replacements: Mapping[str, str]) -> bytes:
    validate_replacements(document, replacements)
    if not replacements:
        return document.source
    if any(span.start is None or span.end is None for span in document.editable_spans):
        raise FormatAdapterError("logical spans cannot be used for byte splicing")
    by_start = sorted(document.editable_spans, key=lambda span: span.start)
    output: list[str] = []
    cursor = 0
    for span in by_start:
        assert span.start is not None and span.end is not None
        output.append(document.text[cursor:span.start])
        output.append(replacements.get(span.node_id, span.text))
        cursor = span.end
    output.append(document.text[cursor:])
    return "".join(output).encode("utf-8")
