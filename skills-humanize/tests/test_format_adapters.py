from __future__ import annotations

import json
import unittest

from humanizer_ch_core.formats import FormatAdapterError, JsonAdapter, MarkdownAdapter, TextAdapter


class TextAdapterTests(unittest.TestCase):
    def test_null_edit_is_byte_identical_and_mixed_endings_survive(self) -> None:
        source = "Grüezi\r\nbonjour\nit".encode("utf-8")
        adapter = TextAdapter()
        document = adapter.parse(source)
        self.assertEqual(adapter.rebuild(document, {}), source)
        replacement = {document.editable_spans[1].node_id: "salut"}
        rebuilt = adapter.rebuild(document, replacement)
        self.assertEqual(rebuilt, "Grüezi\r\nsalut\nit".encode("utf-8"))
        self.assertTrue(adapter.verify(document, rebuilt, replacement).valid)

    def test_line_structure_edit_fails_closed(self) -> None:
        document = TextAdapter().parse(b"one line")
        with self.assertRaises(FormatAdapterError):
            TextAdapter().rebuild(document, {document.editable_spans[0].node_id: "two\nlines"})


class MarkdownAdapterTests(unittest.TestCase):
    def test_protects_code_link_destinations_and_html(self) -> None:
        source = b"Hello `x()` [site](https://example.test) <b>raw</b>.\n\n```py\nx = 1\n```\n"
        adapter = MarkdownAdapter()
        document = adapter.parse(source)
        kinds = {span.kind for span in document.protected_spans}
        self.assertTrue({"inline_code", "link_destination", "raw_html", "fenced_code"} <= kinds)
        html = next(span for span in document.protected_spans if span.kind == "raw_html")
        self.assertEqual(html.text, "<b>raw</b>")
        self.assertEqual(adapter.rebuild(document, {}), source)
        self.assertTrue(adapter.verify(document, source, {}).valid)

    def test_link_label_edit_preserves_delimiters_and_destination(self) -> None:
        adapter = MarkdownAdapter()
        document = adapter.parse(b"Read [old label](https://example.test).")
        label = next(span for span in document.editable_spans if "old label" in span.text)
        rebuilt = adapter.rebuild(document, {label.node_id: "new label"})
        self.assertEqual(rebuilt, b"Read [new label](https://example.test).")

    def test_unterminated_constructs_fail_closed(self) -> None:
        adapter = MarkdownAdapter()
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b"Text `not closed")
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b"```\nnot closed\n")
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b"Text <strong")

    def test_edit_cannot_introduce_structure(self) -> None:
        adapter = MarkdownAdapter()
        document = adapter.parse(b"Plain prose")
        with self.assertRaises(FormatAdapterError):
            adapter.rebuild(document, {document.editable_spans[0].node_id: "unsafe `code`"})


class JsonAdapterTests(unittest.TestCase):
    def test_only_explicit_string_pointers_are_editable(self) -> None:
        source = b'{"title":"Old","count":2,"enabled":true,"nested":{"text":"Keep"}}'
        adapter = JsonAdapter()
        document = adapter.parse(source, pointers=["/title"])
        self.assertEqual(len(document.editable_spans), 1)
        rebuilt = adapter.rebuild(document, {document.editable_spans[0].node_id: "New"})
        parsed = json.loads(rebuilt)
        self.assertEqual(parsed, {"title": "New", "count": 2, "enabled": True, "nested": {"text": "Keep"}})
        self.assertTrue(adapter.verify(document, rebuilt, {document.editable_spans[0].node_id: "New"}).valid)

    def test_null_edit_is_byte_identical(self) -> None:
        source = b'{ "value" : "x" }\n'
        document = JsonAdapter().parse(source, pointers=["/value"])
        self.assertEqual(JsonAdapter().rebuild(document, {}), source)

    def test_non_string_missing_and_duplicate_key_fail_closed(self) -> None:
        adapter = JsonAdapter()
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b'{"count":2}', pointers=["/count"])
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b'{"x":"a","x":"b"}', pointers=["/x"])
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b'{"x":"a"}', pointers=["/missing"])

    def test_pointer_escapes_are_supported(self) -> None:
        adapter = JsonAdapter()
        document = adapter.parse(b'{"a/b":{"~key":"old"}}', pointers=["/a~1b/~0key"])
        rebuilt = adapter.rebuild(document, {document.editable_spans[0].node_id: "new"})
        self.assertEqual(json.loads(rebuilt)["a/b"]["~key"], "new")

    def test_root_string_pointer_and_nonstandard_constant(self) -> None:
        adapter = JsonAdapter()
        document = adapter.parse(b'"old"', pointers=[""])
        rebuilt = adapter.rebuild(document, {document.editable_spans[0].node_id: "new"})
        self.assertEqual(json.loads(rebuilt), "new")
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b'{"value":NaN}', pointers=[])
        with self.assertRaises(FormatAdapterError):
            adapter.parse(b'{"n":1e400,"s":"x"}', pointers=["/s"])


if __name__ == "__main__":
    unittest.main()
