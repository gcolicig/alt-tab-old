# Pass-, Latenz- und Hardwarevertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.runtime`

## Zweck

Dieser Vertrag begrenzt Modellaufrufe, trennt Kern- von Modelllatenz und macht die erwartete Nutzungsdauer vor Beginn eines langen Laufs sichtbar. Hardwarewerte sind gemessene Profile, keine allgemeinen Modellversprechen.

## Benchmarkgroessen

| Klasse | Umfang |
|---|---|
| `selection` | bis 1 000 ausgewaehlte Quelltokens bei bereits indexierter Dokumentrevision |
| `small` | bis 1 000 Quelltokens |
| `medium` | bis 10 000 Quelltokens |
| `large` | bis 50 000 Quelltokens |

Jeder Benchmark dokumentiert Format, Sprache, Locale, Anzahl Segmente, Aenderungsanteil und geschuetzte Spannen.

## Passbudget

| Modus | Generative Standardpasses |
|---|---|
| `humanizer audit` | ein gebatchter Analysepass; kein Rewrite |
| `critical_text selection` | ein semantischer Auditpass; Eskalation nur fuer markierte kritische Restunsicherheit |
| `humanizer rewrite` | ein gebatchter Proposal-Pass plus hoechstens ein semantischer Recheck fuer geaenderte Segmente |
| `proofread correct` | kein generativer Pass |
| `proofread edit` | hoechstens ein gebatchter Adjudikationspass plus deterministischer Recheck |
| `translation-qa` | harte QA ohne Modell; optional ein gebatchter semantischer Pass fuer mehrdeutige Alignments |
| `translate-ch` | ein Aufruf pro Chunk plus hoechstens ein Retry nur fuer fehlgeschlagene Chunks |

Ein Modellaufruf pro Segment ist unzulaessig, solange Batching innerhalb des Kontextbudgets moeglich ist. Unveraenderte Segmente werden nicht erneut gesendet. Explizite Sprache und Locale ueberspringen automatische Erkennung, sofern kein Konflikt vorliegt.

Bei `scope_mode=selection` zaehlen nur die ausgewaehlten Spannen und der explizit begrenzte, nicht editierbare Kontext zum Modellbudget. Der Volltext darf weder zur Bequemlichkeit geladen noch in den Modellrequest aufgenommen werden. Das Routing und allfaellige Eskalationen folgen `model-routing.md`.

Die `selection`-Messung verwendet eine bereits indexierte, unveraenderte Dokumentrevision. Der Benchmark weist Auswahl-, Kontext- und Volltexttokens separat aus; Volltexttokens im Modellrequest muessen null sein. Der erste strukturelle Parse einer noch nicht indexierten Datei wird separat gemessen und darf nicht als Auswahl-Latenz ausgegeben werden.

## Kernlatenzbudgets

Referenzprofil: vier CPU-Kerne, 8 GB RAM, lokale SSD, warmer Prozess, ohne Grammatik- oder generatives Modell.

| Klasse | P95 fuer Parse Analyse Patch Verify |
|---|---:|
| `selection` | 0.5 Sekunden ohne Modellzeit |
| `small` | 0.5 Sekunden |
| `medium` | 3 Sekunden |
| `large` | 15 Sekunden |

Die Budgets umfassen Formatadapter, deterministische Regeln, Glossarpruefung, Patchanwendung und harte Invarianten. Eine Ueberschreitung blockiert nicht die Textausgabe, blockiert aber das Performance-Release-Gate.

## Modell- und Adapterprofil

Jedes Backend registriert:

```text
backend_id
model_id
model_revision
quantization
context_limit_tokens
max_batch_tokens
available_memory_bytes
cold_load_seconds
warm_ttft_seconds
prefill_tokens_per_second
decode_tokens_per_second
measured_at
hardware_fingerprint
```

Ein Adapter darf keine universelle Geschwindigkeitsklasse allein aus der Modellgroesse ableiten. Vor dem ersten langen Lauf wird ein kurzer lokaler Warm-up-Benchmark ausgefuehrt oder ein noch gueltiges Profil geladen.

Initiale Warnschwellen fuer ein konfiguriertes interaktives Profil:

- warme Time to First Token ueber 10 Sekunden: Hinweis;
- ueber 30 Sekunden: langsames Profil;
- Decode unter 4 Tokens pro Sekunde: langsames Profil;
- geschaetzte Gesamtdauer ueber 120 Sekunden: ETA und explizite Fortschrittsanzeige;
- unzureichender freier Speicher: vor Modellladung abbrechen.

Diese Schwellen sind UX-Klassen, keine Qualitaetswertung und kein allgemeines Releaseversprechen fuer TranslateGemma 27B.

## Kontext- und Chunkbudget

- Das tatsaechliche Modelllimit wird aus dem Adapterprofil gelesen.
- Prompt, Kontrolltokens, Glossar, Kontext und erwartete Ausgabe besitzen getrennte Tokenbudgets.
- Der Adapter reserviert mindestens den konfigurierten Ausgabebedarf und eine Sicherheitsmarge.
- Benachbarte Segmente duerfen als nicht zu uebersetzender Kontext mitgegeben werden.
- Dokumentweite Terminologie wird ausserhalb des Modellkontexts ueber Glossar und Manifest gehalten.
- Uebergrosse Einzelspannen werden kontrolliert geteilt oder abgelehnt.

## Betrieb

- Schwere Modelle laufen als persistenter Dienst; Laden pro Dokument ist kein Standardpfad.
- Fortschritt, Chunkzahl, ETA und Abbruchmoeglichkeit werden angezeigt.
- Caches sind an den vollstaendigen Revisions- und Checkpoint-Schluessel gebunden.
- Kern, Grammatikengine, Host-Modell und Uebersetzungsadapter werden getrennt gemessen.
- Standardmaessig wird nur ein schweres lokales Modell gleichzeitig belastet.

## Release-Gates

- Kernlatenz erfuellt die P95-Budgets auf dem Referenzprofil.
- Kein Modus ueberschreitet sein Passbudget ohne dokumentierte Nutzerfreigabe.
- Performanceberichte enthalten kalte und warme Werte und vermischen keine Backends oder Quantisierungen.
- Eine neue Version verschlechtert den warmen Median eines unveraenderten Profils um hoechstens 10 Prozent oder dokumentiert und genehmigt die Abweichung.
- Fuer `translate-ch` existiert mindestens ein verifiziertes lokales Hardwareprofil; ohne Profil bleibt der Adapter optional und ohne Geschwindigkeitsversprechen.
