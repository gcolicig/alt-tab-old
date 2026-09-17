from __future__ import annotations

from dataclasses import dataclass


HIDDEN_UNICODE = {"\u200b", "\u200c", "\u200d", "\ufeff"}


@dataclass(frozen=True)
class Finding:
    rule_id: str
    category: str
    severity: str
    start: int
    end: int
    source: str
    auto_apply: bool
    reason: str

    def as_dict(self) -> dict[str, object]:
        return self.__dict__.copy()


def deterministic_findings(text: str, locale: str | None) -> list[Finding]:
    findings: list[Finding] = []
    for index, character in enumerate(text):
        if character in HIDDEN_UNICODE:
            findings.append(Finding("hidden_unicode", "unicode", "error", index, index + 1, character, False, "Kandidat; Schutzbereich muss vor Anwendung geprüft werden."))
        if locale == "de-CH" and character == "\u00df":
            findings.append(Finding("de_ch_eszett", "locale", "error", index, index + 1, character, False, "Kandidat; nur in bestätigter freigegebener Prosa anwenden."))
    return findings
