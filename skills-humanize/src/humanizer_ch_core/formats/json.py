from __future__ import annotations

from copy import deepcopy
import json
import math
from typing import Any, Mapping, Sequence

from .common import (
    EditableSpan,
    FormatAdapterError,
    ParsedDocument,
    ProtectedSpan,
    ReconstructionGuarantee,
    VerificationResult,
    decode_utf8,
    validate_replacements,
)


class JsonAdapter:
    """JSON adapter with exact null edits and semantic reconstruction after edits."""

    format = "json"
    guarantee = ReconstructionGuarantee.SEMANTIC_EQUIVALENCE

    def detect(self, source: bytes) -> bool:
        try:
            self._load(decode_utf8(source))
            return True
        except (FormatAdapterError, json.JSONDecodeError):
            return False

    def parse(self, source: bytes, **options: object) -> ParsedDocument:
        text = decode_utf8(source)
        try:
            value = self._load(text)
        except (json.JSONDecodeError, FormatAdapterError) as error:
            raise FormatAdapterError(f"invalid or ambiguous JSON: {error}") from error
        pointers = options.get("pointers", ())
        if isinstance(pointers, str) or not isinstance(pointers, Sequence):
            raise FormatAdapterError("pointers must be a sequence")
        editable: list[EditableSpan] = []
        seen: set[str] = set()
        for index, pointer in enumerate(pointers, 1):
            if not isinstance(pointer, str) or pointer in seen:
                raise FormatAdapterError("JSON pointers must be unique strings")
            seen.add(pointer)
            selected = self._resolve(value, pointer)
            if not isinstance(selected, str):
                raise FormatAdapterError(f"JSON pointer does not select a string: {pointer}")
            editable.append(EditableSpan(f"json-{index:05d}", None, None, selected, pointer))
        metadata = {"value": value, "pointers": tuple(pointers)}
        return ParsedDocument(self.format, source, text, tuple(editable), (), self.guarantee, metadata)

    def extract_editable_spans(self, document: ParsedDocument) -> tuple[EditableSpan, ...]:
        return document.editable_spans

    def protect(self, document: ParsedDocument) -> tuple[ProtectedSpan, ...]:
        return ()

    def rebuild(self, document: ParsedDocument, replacements: Mapping[str, str]) -> bytes:
        validate_replacements(document, replacements)
        if not replacements:
            return document.source
        value = deepcopy(document.metadata["value"])
        for span in document.editable_spans:
            if span.node_id in replacements:
                if span.pointer == "":
                    value = replacements[span.node_id]
                else:
                    self._assign(value, span.pointer or "", replacements[span.node_id])
        return (json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")

    def verify(
        self, document: ParsedDocument, rebuilt: bytes, replacements: Mapping[str, str]
    ) -> VerificationResult:
        errors: list[str] = []
        try:
            validate_replacements(document, replacements)
            current = self._load(decode_utf8(rebuilt))
        except (FormatAdapterError, json.JSONDecodeError) as error:
            return VerificationResult(False, self.guarantee, (str(error),))
        expected = deepcopy(document.metadata["value"])
        for span in document.editable_spans:
            if span.node_id in replacements:
                if span.pointer == "":
                    expected = replacements[span.node_id]
                else:
                    self._assign(expected, span.pointer or "", replacements[span.node_id])
        if not self._same_types_and_values(expected, current):
            errors.append("JSON structure, data type, or non-selected value changed")
        if not replacements and rebuilt != document.source:
            errors.append("null edit is not byte-identical")
        return VerificationResult(not errors, self.guarantee, tuple(errors))

    def _load(self, text: str) -> Any:
        def object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
            result: dict[str, Any] = {}
            for key, value in pairs:
                if key in result:
                    raise FormatAdapterError(f"duplicate object key: {key}")
                result[key] = value
            return result

        def reject_constant(value: str) -> None:
            raise FormatAdapterError(f"non-standard JSON constant: {value}")

        def finite_float(value: str) -> float:
            parsed = float(value)
            if not math.isfinite(parsed):
                raise FormatAdapterError(f"non-finite JSON number: {value}")
            return parsed

        return json.loads(text, object_pairs_hook=object_pairs, parse_constant=reject_constant, parse_float=finite_float)

    def _tokens(self, pointer: str) -> list[str]:
        if pointer == "":
            return []
        if not pointer.startswith("/"):
            raise FormatAdapterError(f"invalid JSON pointer: {pointer}")
        tokens = pointer[1:].split("/")
        result: list[str] = []
        for token in tokens:
            index = 0
            decoded = ""
            while index < len(token):
                if token[index] != "~":
                    decoded += token[index]
                    index += 1
                    continue
                if index + 1 >= len(token) or token[index + 1] not in "01":
                    raise FormatAdapterError(f"invalid JSON pointer escape: {pointer}")
                decoded += "~" if token[index + 1] == "0" else "/"
                index += 2
            result.append(decoded)
        return result

    def _resolve(self, value: Any, pointer: str) -> Any:
        current = value
        for token in self._tokens(pointer):
            if isinstance(current, dict) and token in current:
                current = current[token]
            elif isinstance(current, list) and token.isdigit() and str(int(token)) == token and int(token) < len(current):
                current = current[int(token)]
            else:
                raise FormatAdapterError(f"JSON pointer does not exist: {pointer}")
        return current

    def _assign(self, value: Any, pointer: str, replacement: str) -> None:
        tokens = self._tokens(pointer)
        if not tokens:
            raise FormatAdapterError("replacing the JSON document root is unsupported")
        parent = value
        for token in tokens[:-1]:
            parent = parent[int(token)] if isinstance(parent, list) else parent[token]
        final = tokens[-1]
        if isinstance(parent, list):
            parent[int(final)] = replacement
        else:
            parent[final] = replacement

    def _same_types_and_values(self, expected: Any, current: Any) -> bool:
        if type(expected) is not type(current):
            return False
        if isinstance(expected, dict):
            return expected.keys() == current.keys() and all(
                self._same_types_and_values(expected[key], current[key]) for key in expected
            )
        if isinstance(expected, list):
            return len(expected) == len(current) and all(
                self._same_types_and_values(left, right) for left, right in zip(expected, current)
            )
        return expected == current
