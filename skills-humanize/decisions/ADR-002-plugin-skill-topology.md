# ADR-002: Plugin- und Skill-Topologie

- Status: angenommen
- Datum: 2026-09-17
- Betrifft: HC-004, HC-005, HC-073, HC-078, HC-080

## Entscheidung

Das Repository enthält das auslieferbare Plugin im Unterverzeichnis `humanizer-ch/`, weil Plugin-Ordner und Manifestname identisch sein müssen, der Repository-Ordner aber `skills-humanize` heisst.

Das Plugin liefert genau zwei automatisch auffindbare Skills:

- `humanizer-ch` für Audit, kritische Auswahlprüfung und belegtreuen Rewrite;
- `proofread-ch` für Korrektur, Edit und Translation QA.

`critical_text` bleibt ein Profil. `translate-ch` bleibt eine optionale CLI. Der Maintainer-Skill liegt unter `maintenance/skills/`, ist explizit aufzurufen und wird nicht ausgeliefert. Produkt-Skills sind kurze Router; bedingte Verfahren liegen in Referenzen, deterministische Logik im Python-Kern.

## Verworfen

### Ein monolithischer Mehrzweck-Skill

Verworfen wegen schlechter Auffindbarkeit, unnötigem Kontextverbrauch und vermischter Änderungsautorität.

Reaktivierung: nur wenn Trigger-Evals zeigen, dass zwei Skills häufiger falsch routen als ein gemeinsamer Einstieg und der gemeinsame Einstieg ohne Regelduplikation kurz bleibt.

### Eigener Skill `critical-text`

Verworfen, weil er dieselben Sicherheits-, Sprach- und Auditregeln wie `humanizer-ch` benötigt und nur Scope und Review-Profil ändert.

Reaktivierung: wenn Nutzungsmessungen eine eigenständige Zielgruppe mit abweichendem Outputvertrag und stabiler, trennscharfer Auffindbarkeit belegen.

### Übersetzung als Skill

Verworfen, weil TranslateGemma ein optionaler technischer Adapter ist und Humanisierung keine Übersetzung implizieren darf.

Reaktivierung: wenn mehrere austauschbare Übersetzungsadapter und ein eigenständiger, evaluierten Nutzerworkflow vorliegen.

### Frühe Marketplace-Installation

Verworfen während der Entwicklung, damit unvollständige Skills nicht als installiertes Produkt erscheinen und keine Nutzerkonfiguration verändert wird.

Reaktivierung: sobald Plugin-, Skill-, Installations- und Bundle-Gates bestanden sind und eine explizite Installationsentscheidung vorliegt.
