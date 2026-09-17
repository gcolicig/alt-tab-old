from __future__ import annotations

import re
from typing import Mapping

from .common import (
    EditableSpan,
    FormatAdapterError,
    ParsedDocument,
    ProtectedSpan,
    ReconstructionGuarantee,
    VerificationResult,
    decode_utf8,
    splice_text,
    validate_replacements,
)


class TextAdapter:
    format = "text"
    guarantee = ReconstructionGuarantee.BYTE_PRESERVING_OUTSIDE_EDITS

    def detect(self, source: bytes) -> bool:
        try:
            decode_utf8(source)
            return True
        except FormatAdapterError:
            return False

    def parse(self, source: bytes, **_: object) -> ParsedDocument:
        text = decode_utf8(source)
        editable: list[EditableSpan] = []
        protected: list[ProtectedSpan] = []
        cursor = 0
        node = 1
        for match in re.finditer(r"\r\n|\r|\n", text):
            if match.start() > cursor:
                editable.append(EditableSpan(f"text-{node:05d}", cursor, match.start(), text[cursor:match.start()]))
                node += 1
            protected.append(ProtectedSpan(match.start(), match.end(), match.group(), "line_ending"))
            cursor = match.end()
        if cursor < len(text):
            editable.append(EditableSpan(f"text-{node:05d}", cursor, len(text), text[cursor:]))
        return ParsedDocument(self.format, source, text, tuple(editable), tuple(protected), self.guarantee)

    def extract_editable_spans(self, document: ParsedDocument) -> tuple[EditableSpan, ...]:
        return document.editable_spans

    def protect(self, document: ParsedDocument) -> tuple[ProtectedSpan, ...]:
        return document.protected_spans

    def rebuild(self, document: ParsedDocument, replacements: Mapping[str, str]) -> bytes:
        validate_replacements(document, replacements)
        for replacement in replacements.values():
            if "\n" in replacement or "\r" in replacement:
                raise FormatAdapterError("text replacements cannot change line structure")
        return splice_text(document, replacements)

    def verify(
        self, document: ParsedDocument, rebuilt: bytes, replacements: Mapping[str, str]
    ) -> VerificationResult:
        try:
            expected = self.rebuild(document, replacements)
            current = self.parse(rebuilt)
        except FormatAdapterError as error:
            return VerificationResult(False, self.guarantee, (str(error),))
        errors: list[str] = []
        if rebuilt != expected:
            errors.append("rebuilt bytes differ from the declared replacements")
        original_endings = tuple(span.text for span in document.protected_spans)
        current_endings = tuple(span.text for span in current.protected_spans)
        if current_endings != original_endings:
            errors.append("line endings changed")
        return VerificationResult(not errors, self.guarantee, tuple(errors))
