# ADR-001: Kontrollierter Import von humanizer-de 5.27.3

- Status: angenommen
- Datum: 2026-09-17
- Entscheider: humanizer-ch Projekt
- Betrifft: HC-001, HC-002
- Inventar: `migration/legacy-inventory.json`

## Kontext

`humanizer-ch` soll Deutschvarianten, Englisch, Französisch und Italienisch unterstützen. Der installierte Legacy-Skill `humanizer-de` 5.27.3 enthält erprobte deutsche Regeln, Sicherheitslogik, Prüfskripte und Tests, ist aber als deutschsprachiger monolithischer Skill organisiert. Eine direkte Kopie würde Sprachregeln, Hostintegration, Ablaufsteuerung und technische Implementierung erneut koppeln.

Die installierte Kopie enthält keine Git-Metadaten. Ihre angegebene Version 5.27.3 ist in sechs unabhängigen Dateien belegt. Der vollständige Inhalt wird deshalb über einen reproduzierbaren SHA-256-Baum-Hash fixiert. Das Inventar kategorisiert alle 185 regulären Dateien ohne Überlappung.

Das Material hat eine gemischte Lizenzlage: Software und originäres Material stehen grundsätzlich unter MIT. Teile des Musterkatalogs und korrespondierende Beschreibungen sind aus Wikipedia adaptiert und stehen unter CC-BY-SA-4.0. Der pauschale Import ganzer Markdown-Dateien würde diese Grenze verschleiern.

## Entscheidung

Wir führen keinen Quellbaum-Fork und keinen pauschalen Dateiimport durch. Die Migration erfolgt kontrolliert und nach Zielverantwortung:

1. Rechtliche Hinweise werden als verpflichtender Provenienzinput übernommen.
2. Testszenarien, False-Positive-Fälle, Null-Edit-Fälle und Sicherheitsinvarianten werden priorisiert migriert und auf die neuen Verträge abgebildet.
3. Gemeinsam nutzbare Konzepte wie Evidence Locks, Scope-Erkennung, Verifikation und `doctor` werden in den neuen Kern adaptiert.
4. Deutsche Marker, Idiome, Registerwerte und Schwellen werden ausschliesslich in Locale-Packs migriert. Sie gelten weder automatisch für de-CH und de-AT noch für Englisch, Französisch oder Italienisch.
5. Plugin-Manifeste, Skill-Router, Dokumentation, Buildsystem und Abhängigkeitsmodell werden neu erzeugt.
6. Jeder migrierte Regel- oder Testdatensatz erhält mindestens `provenance_id`, `source_path`, `source_version`, `source_sha256`, `source_license` und `adaptation_note`.
7. Eine Regel wird erst aktiv, wenn ein positiver Fall, ein Grenzfall und ein False-Positive-Fall vorhanden sind. Unkalibrierte Regeln dürfen höchstens beratend melden.
8. Die Legacy-Quelle bleibt read-only. Automatische Synchronisation mit einer installierten Skill-Kopie ist ausgeschlossen.

## Zielzuordnung

| Legacy-Bereich | Entscheidung | Zielverantwortung |
|---|---|---|
| Manifeste und Agent-Metadaten | ersetzen | Plugin-Shell und Host-Manifeste |
| Beide `SKILL.md` | ersetzen | kurze Router `humanizer-ch` und `proofread-ch` |
| Evidence, QGIR, Entscheidungstabellen | adaptieren | gemeinsamer Policy-Kern |
| Deutsche Muster und Naturalness-Regeln | adaptieren | Locale-Pack de-DE, danach separat kalibrierte Varianten |
| Runtime-Skripte | selektiv adaptieren | `humanizer_ch_core` und dünne CLI-Adapter |
| Korpora, Szenarien und Tests | adaptieren | Legacy-de-Regressionssuite und Eval-Harness |
| Lizenz und Notice | wiederverwenden | Root-Lizenzen und Provenienz-Ledger |
| Dokumentation, Build und CI | ersetzen | neue Projektquellen |
| Markenbilder und alter Changelog | ausschliessen | kein produktives Ziel |

## Verworfen

### Vollständiger Fork des Legacy-Repositories

Verworfen, weil die deutsche Monolithstruktur und Hostannahmen zum neuen Mehrsprachen- und Adaptermodell werden würden. Ausserdem erschwert ein Fork die Trennung von MIT- und CC-BY-SA-Material.

Reaktivierung: nur wenn die Zielarchitektur aufgegeben und vollständige Rückwärtskompatibilität mit `humanizer-de` zum primären Produktziel erklärt wird.

### Direkte Kopie aller Regeln in einen gemeinsamen Katalog

Verworfen, weil KI-Tells, idiomatische Transfers, Registerfehler, Anrede und Interpunktion sprach- und localespezifisch sind. Ein gemeinsamer aktiver Katalog würde systematische Fehlalarme erzeugen.

Reaktivierung: nur für nachweislich sprachunabhängige Strukturregeln mit mehrsprachigen positiven, negativen und Grenzfall-Evals.

### Wiederverwendung des monolithischen Skill-Prompts

Verworfen, weil er Routing, Fachregeln, Ausgabeform und Werkzeugausführung koppelt und als zweite Kopie vorliegt. Die neuen normativen Contracts würden dadurch umgangen.

Reaktivierung: nur als nicht produktive Vergleichsbaseline in einem abgeschotteten Eval-Lauf.

### Übernahme der Legacy-CI und Repository-Governance

Verworfen, solange Paketgrenzen, Python-Matrix, Harness und Release-Gates nicht implementiert sind. Frühe Übernahme würde Scheinsicherheit erzeugen.

Reaktivierung: sobald der kanonische Harness lokal stabil läuft und die unterstützten Plattformen als verbindliche Matrix beschlossen sind.

### Wiederverwendung der Markenassets

Verworfen, weil Name, Zielgruppe und Sprachumfang wechseln. Die Assets könnten eine Kontinuität oder Freigabe suggerieren, die nicht beschlossen ist.

Reaktivierung: nur für klar bezeichnete historische Dokumentation nach Asset-spezifischer Rechte- und Markenprüfung.

### Übernahme des vollständigen Changelogs

Verworfen, weil `humanizer-ch` eine eigene Versionsgeschichte beginnt. Das Inventar und der Upstream-Link reichen für die Migrationstraceability.

Reaktivierung: wenn eine Audit- oder Compliance-Anforderung eine lokale, unveränderliche Historienkopie verlangt.

## Folgen

### Positiv

- Die funktional wertvollsten Legacy-Elemente werden testgetrieben übernommen.
- Sprach- und Localelogik bleibt von gemeinsamem Patch-, Evidence- und Statusverhalten getrennt.
- Lizenzpflichten können pro Regel und Fixture geprüft werden.
- Der Baum-Hash macht die installierte Ausgangsbasis trotz fehlender Commit-ID reproduzierbar identifizierbar.

### Negativ

- Die Migration braucht eine Provenienzschicht und manuelle Klassifikation gemischter Inhalte.
- Legacy-Ergebnisse sind nicht automatisch bitgenau reproduzierbar.
- de-CH und de-AT benötigen eigene Kalibrierungsdaten; die Umbenennung allein erzeugt keine valide Locale-Unterstützung.

## Risiken und Kontrollen

| Risiko | Kontrolle |
|---|---|
| Fehlende Commit-ID des installierten Snapshots | Vollständiger Baum-Hash, Versionsbelege und kritische Einzeldatei-Hashes |
| Unbemerkte CC-BY-SA-Übernahme | Provenienzfelder pro Regel und Fixture; Import-Gate prüft Lizenz und Adaptionsnotiz |
| Deutsche Regeln werden als universell behandelt | Locale-Pack-Grenze; Aktivierung nur nach localespezifischen Evals |
| Tests bestätigen nur das alte Verhalten | Legacy-Suite getrennt von neuen Contract-, Locale- und Qualitäts-Evals auswerten |
| Ungeprüfte optionale Abhängigkeiten | Capability-Erkennung und eigene Lizenz-/Sicherheitsprüfung vor Aufnahme in `pyproject.toml` |
| Drift zwischen installierter Quelle und Inventar | Import bricht bei abweichendem Baum- oder Kategorie-Hash ab |

## Reaktivierungsprozess

Eine verworfene oder ausgeschlossene Option darf nur über eine neue ADR reaktiviert werden. Sie muss den oben genannten Auslöser belegen, Lizenz- und Qualitätsauswirkungen nennen, den betroffenen Kategorie-Hash referenzieren und neue Release-Gates definieren. Eine blosse Implementierungsvereinfachung ist kein Reaktivierungsgrund.
