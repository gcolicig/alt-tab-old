# ADR-003: Ehrlicher Foundation-Scope

- Status: angenommen
- Datum: 2026-09-17
- Betrifft: erste Implementierungsiteration

## Entscheidung

Version 0.1.0 implementiert zunächst den deterministischen Unterbau: Konfigurationsauflösung, revisionsgebundene Auswahl, strukturierte Fehler, minimale Locale- und Unicode-Befunde, CLI-Grundpfade und Offline-Verifikation. Semantische Humanisierung, vollständiges Proofreading und Übersetzung werden erst als verfügbar ausgewiesen, wenn ihre sprachspezifischen Evals und Adaptergates bestehen.

Ein CLI-`critical_text`-Audit ohne semantischen Modellpfad endet deshalb mit `result=incomplete`, `quality_disposition=not_evaluated` und Exit 12; semantische sowie dokumentweite Checks stehen auf `not_run`. Der agentische Produkt-Skill darf nach tatsächlich ausgeführter semantischer Prüfung `review_required` liefern. `translate-ch` meldet ohne konfigurierten Adapter einen stabilen Adapterfehler.

## Verworfen

### Legacy-Skripte sofort vollständig kopieren

Verworfen wegen monolithischer Imports, deutscher Annahmen und ungeklärter Regelprovenienz.

Reaktivierung: pro Modul nach Inventarentscheid, Lizenznachweis und bestandenen neuen Contract-Tests.

### Semantische Qualität im Foundation-CLI simulieren

Verworfen, weil einfache Regex-Regeln weder KI-Tell-Cluster noch Idiomatik, Register oder Stimmerhalt zuverlässig beurteilen.

Reaktivierung: nach Implementierung des Agent-Core-Proposal-Vertrags und bestandener sprachkundiger Blind-Evaluation.

### TranslateGemma als Pflichtabhängigkeit

Verworfen wegen Modellgrösse, Hardwarebedarf und der Anforderung, dass Kernfunktionen ohne Übersetzungsadapter laufen.

Reaktivierung: nie als Kernpflicht. Eine standardmässige optionale Aktivierung kann geprüft werden, wenn Hardwareprofile, Latenz und Translation-QA-Gates stabil sind.
