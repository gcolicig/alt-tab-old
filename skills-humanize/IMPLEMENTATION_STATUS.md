# Implementierungsstatus

Stand: 17. September 2026

## Umgesetzt

- Plugin-Geruest `humanizer-ch` mit validem Manifestgrundriss.
- Kurze Produkt-Skills `humanizer-ch` und `proofread-ch` mit progressiver Offenlegung.
- Repository-lokaler, expliziter Maintainer-Skill ausserhalb des Nutzer-Plugins.
- Normative Contracts fuer Agent-Core, Patch-Autoritaet, Alignment, Performance, Modell-Routing, Auswahl, Konfiguration und Fehler.
- JSON-Schemas fuer Auswahlrequest, Konfiguration, Fehlerreport und Verifikationsreport.
- Kontrolliertes Legacy-Inventar mit Digests und Migrationsentscheiden.
- Deterministischer Python-Grundkern fuer Konfiguration, Auswahlidentitaet, Fehler und minimale Locale-/Unicode-Befunde.
- CLI-Grundpfade `humanizer-ch`, `proofread-ch`, `translate-ch` und `humanizer-ch-verify`.
- Kanonischer Offline-Harness fuer Contracts, Links, JSON, Schemas, Skill-Struktur und Auswahl-Invarianten.

## Teilweise umgesetzt

- HC-001/HC-002: Inventar und Snapshot sind vorhanden; Korpora wurden noch nicht physisch und lizenzspezifisch migriert.
- HC-073: Plugin und Allowlist-Prinzip sind angelegt; finales Release-Bundle und Installations-Smoke-Test fehlen.
- HC-078: Beide Produkt-Skills sind angelegt; sprachspezifische Verhaltens-Evals und vollständige Kernintegration fehlen.
- HC-079: Deterministischer Harness läuft; Modellmatrix und sprachkundige Blindbewertung fehlen.
- HC-080: Maintainer-Skill ist angelegt; offizieller Skill-Creator-Validator ist mangels PyYAML noch übersprungen.
- HC-081: Direkter Text und Spans funktionieren im Foundation-Kern; Markdown-/JSON-Manifest, Cache und Segment-ID-Auswahl fehlen.
- HC-082/HC-083: Contracts und Schemas sind vorhanden; der Foundation-Kern implementiert nur einen Teil des vollständigen Katalogs.

## Noch nicht umgesetzt

- Vollständige Formatadapter und atomare Patch-Engine.
- Sprachmodule, Locale-Packs und migrierte Pattern Cards.
- Semantischer Agent-Core und Modell-Routing zur Laufzeit.
- Vollständiges Proofreading und optionale Grammatik-Engine.
- TranslateGemma-27B-Adapter und Translation QA.
- Modell-, Performance-, Installations- und Release-Gates.

## Validierungsblocker

Die offiziellen Validatoren von Skill-Creator und Plugin-Creator benötigen PyYAML. Die aktuelle Python-Umgebung enthält das Modul nicht. Auch `setuptools` für den isolierten Python-Installations-Smoke-Test fehlt. Der repository-eigene Harness weist beides als `skipped` statt als bestanden aus. Installation wird nicht automatisch vorgenommen, weil sie eine zusätzliche Abhängigkeits- beziehungsweise Netzwerkentscheidung wäre. Das deterministische Plugin-ZIP wird ohne diese Abhängigkeiten gebaut und getestet.
