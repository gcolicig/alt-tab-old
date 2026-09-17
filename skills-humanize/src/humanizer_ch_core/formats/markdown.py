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


_FENCE = re.compile(r"(?m)^[ \t]{0,3}(`{3,}|~{3,})[^\r\n]*(?:\r\n|\r|\n)")
_RAW_HTML = re.compile(
    r"<!--[\s\S]*?-->|<([A-Za-z][\w:-]*)(?:\s[^>]*)?>[\s\S]*?</\1\s*>|</?[A-Za-z][^>]*>",
    re.IGNORECASE,
)
_LINK_DESTINATION = re.compile(r"\]\((?:[^()\\]|\\.|\([^()]*\))*\)")
_LINK_OPEN = re.compile(r"\[(?=[^\]\r\n]*\]\()")
_REFERENCE_DEFINITION = re.compile(r"(?m)^[ \t]{0,3}\[[^\]\r\n]+\]:[^\r\n]*(?:\r\n|\r|\n|$)")
_BLOCK_PROTECTED = re.compile(r"(?m)^(?:[ \t]*>|[ \t]*\|.*\|[ \t]*$|[ \t]*[-:| ]{3,}[ \t]*$).*(?:\r\n|\r|\n|$)")
_MARKDOWN_SYNTAX = re.compile(r"[#*_~\[\]>]+|^[ \t]*(?:[-+] |\d+\. )", re.MULTILINE)


class MarkdownAdapter:
    format = "markdown"
    guarantee = ReconstructionGuarantee.BYTE_PRESERVING_OUTSIDE_EDITS

    def detect(self, source: bytes) -> bool:
        try:
            text = decode_utf8(source)
        except FormatAdapterError:
            return False
        return bool(
            re.search(
                r"(?m)^(?:#{1,6}\s|[-*+]\s|```|~~~)|\[[^\]]+\]\(|`[^`]+`|<[/A-Za-z!]|(?:\*\*|__|~~).+?(?:\*\*|__|~~)",
                text,
            )
        )

    def parse(self, source: bytes, **_: object) -> ParsedDocument:
        text = decode_utf8(source)
        protected = self._protected_ranges(text)
        editable = self._editable_ranges(text, protected)
        return ParsedDocument(self.format, source, text, editable, protected, self.guarantee)

    def extract_editable_spans(self, document: ParsedDocument) -> tuple[EditableSpan, ...]:
        return document.editable_spans

    def protect(self, document: ParsedDocument) -> tuple[ProtectedSpan, ...]:
        return document.protected_spans

    def rebuild(self, document: ParsedDocument, replacements: Mapping[str, str]) -> bytes:
        validate_replacements(document, replacements)
        for replacement in replacements.values():
            if any(token in replacement for token in ("\r", "\n", "`", "<", ">", "](")):
                raise FormatAdapterError("replacement introduces unsupported Markdown structure")
        rebuilt = splice_text(document, replacements)
        verification = self.verify(document, rebuilt, replacements, _skip_expected=True)
        if not verification.valid:
            raise FormatAdapterError("; ".join(verification.errors))
        return rebuilt

    def verify(
        self,
        document: ParsedDocument,
        rebuilt: bytes,
        replacements: Mapping[str, str],
        _skip_expected: bool = False,
    ) -> VerificationResult:
        errors: list[str] = []
        try:
            current = self.parse(rebuilt)
            if not _skip_expected and rebuilt != splice_text(document, replacements):
                errors.append("rebuilt bytes differ from the declared replacements")
        except FormatAdapterError as error:
            return VerificationResult(False, self.guarantee, (str(error),))
        before = tuple((span.kind, span.text) for span in document.protected_spans)
        after = tuple((span.kind, span.text) for span in current.protected_spans)
        if before != after:
            errors.append("protected Markdown structure changed")
        return VerificationResult(not errors, self.guarantee, tuple(errors))

    def _protected_ranges(self, text: str) -> tuple[ProtectedSpan, ...]:
        if re.search(r"(?m)<(?:[A-Za-z!/])[^>\r\n]*$", text):
            raise FormatAdapterError("unterminated raw HTML")
        if re.search(r"(?m)\[[^\]\r\n]*\]\([^\)\r\n]*$", text):
            raise FormatAdapterError("unterminated inline link")
        ranges: list[ProtectedSpan] = []
        ranges.extend(self._frontmatter(text))
        ranges.extend(self._fenced_code(text))
        for pattern, kind in (
            (_RAW_HTML, "raw_html"),
            (_LINK_DESTINATION, "link_destination"),
            (_LINK_OPEN, "link_delimiter"),
            (_REFERENCE_DEFINITION, "reference_definition"),
            (_BLOCK_PROTECTED, "protected_block"),
            (_MARKDOWN_SYNTAX, "markdown_syntax"),
        ):
            for match in pattern.finditer(text):
                ranges.append(ProtectedSpan(match.start(), match.end(), match.group(), kind))
        ranges.extend(self._inline_code(text, ranges))
        return self._merge_and_validate(ranges)

    def _frontmatter(self, text: str) -> list[ProtectedSpan]:
        opening = re.match(r"^---[ \t]*(?:\r\n|\r|\n)", text)
        if not opening:
            return []
        match = re.search(r"(?m)^---[ \t]*(?:\r\n|\r|\n)", text[opening.end():])
        if not match:
            raise FormatAdapterError("unterminated frontmatter")
        finish = opening.end() + match.end()
        return [ProtectedSpan(0, finish, text[:finish], "frontmatter")]

    def _fenced_code(self, text: str) -> list[ProtectedSpan]:
        spans: list[ProtectedSpan] = []
        cursor = 0
        while True:
            opening = _FENCE.search(text, cursor)
            if not opening:
                break
            marker = opening.group(1)
            close = re.compile(rf"(?m)^[ \t]{{0,3}}{re.escape(marker[0])}{{{len(marker)},}}[ \t]*(?:\r\n|\r|\n|$)").search(text, opening.end())
            if not close:
                raise FormatAdapterError("unterminated fenced code block")
            spans.append(ProtectedSpan(opening.start(), close.end(), text[opening.start():close.end()], "fenced_code"))
            cursor = close.end()
        return spans

    def _inline_code(self, text: str, existing: list[ProtectedSpan]) -> list[ProtectedSpan]:
        spans: list[ProtectedSpan] = []
        occupied = [(span.start, span.end) for span in existing]
        cursor = 0
        while cursor < len(text):
            match = re.search(r"`+", text[cursor:])
            if not match:
                break
            start = cursor + match.start()
            marker = match.group()
            if any(left <= start < right for left, right in occupied):
                cursor = start + len(marker)
                continue
            finish = text.find(marker, start + len(marker))
            if finish < 0:
                raise FormatAdapterError("unterminated inline code")
            finish += len(marker)
            if "\n" in text[start:finish] or "\r" in text[start:finish]:
                raise FormatAdapterError("multiline inline code is unsupported")
            spans.append(ProtectedSpan(start, finish, text[start:finish], "inline_code"))
            cursor = finish
        return spans

    def _merge_and_validate(self, ranges: list[ProtectedSpan]) -> tuple[ProtectedSpan, ...]:
        ordered = sorted(ranges, key=lambda span: (span.start, -span.end))
        result: list[ProtectedSpan] = []
        for span in ordered:
            if result and span.start < result[-1].end:
                if span.end <= result[-1].end:
                    continue
                raise FormatAdapterError("overlapping Markdown constructs are ambiguous")
            result.append(span)
        return tuple(result)

    def _editable_ranges(self, text: str, protected: tuple[ProtectedSpan, ...]) -> tuple[EditableSpan, ...]:
        editable: list[EditableSpan] = []
        cursor = 0
        node = 1
        for protected_span in (*protected, ProtectedSpan(len(text), len(text), "", "sentinel")):
            for match in re.finditer(r"[^\r\n]+", text[cursor:protected_span.start]):
                start = cursor + match.start()
                end = cursor + match.end()
                value = text[start:end]
                if value.strip() and not re.fullmatch(r"[\s#*_~\[\]()+.!-]+", value):
                    editable.append(EditableSpan(f"md-{node:05d}", start, end, value))
                    node += 1
            cursor = protected_span.end
        return tuple(editable)
