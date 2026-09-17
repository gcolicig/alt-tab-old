# Fehler- und Exit-Code-Vertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.errors`

## Zweck

Dieser Vertrag definiert eine gemeinsame, datensparsame Fehlertaxonomie fuer Kern, Skills, CLI, Adapter und JSON-Reports. Fachliche Qualitaet, Workflowzustand und technische Fehler bleiben getrennte Achsen.

## Fehlerobjekt

Jeder Fehler entspricht `schemas/error-report.schema.json` und enthaelt mindestens:

| Feld | Bedeutung |
|---|---|
| `code` | stabiler Code aus dem Katalog |
| `category` | Fehlerklasse |
| `component` | meldende Komponente |
| `severity` | `warning`, `error` oder `fatal` |
| `retryability` | Bedingung fuer eine sichere Wiederholung |
| `safe_action` | maschinenlesbare naechste Nutzerhandlung |
| `message_key` | lokalisierbarer Meldungsschluessel, kein Rohtext |
| `correlation_id` | lauflokale Korrelation ohne Textinhalt |

Optionale Diagnostik darf IDs, Versionen, Optionsnamen, JSON-Pointer, Zaehler und einen stabilen Exception-Fingerprint enthalten. Textauszuege, Prompts, Secretwerte, Stacktraces und ungefilterte Adapterantworten sind im Standardreport verboten.

## Kategorien und stabile Codes

Codes werden nach Veroeffentlichung nicht umgedeutet oder wiederverwendet. Neue Codes duerfen innerhalb einer bestehenden Kategorie ergaenzt werden.

| Kategorie | Codes der Version 0.1.0 |
|---|---|
| `input` | `HC_INPUT_EMPTY`, `HC_INPUT_ENCODING`, `HC_INPUT_SCOPE_INVALID`, `HC_INPUT_REVISION_MISMATCH` |
| `configuration` | `HC_CONFIG_UNKNOWN_OPTION`, `HC_CONFIG_SCHEMA_UNSUPPORTED`, `HC_CONFIG_PROFILE_INVALID`, `HC_CONFIG_LOCALE_CONFLICT`, `HC_CONFIG_ENV_FORBIDDEN`, `HC_CONFIG_SECRET_MISSING` |
| `structure` | `HC_STRUCTURE_PARSE_FAILED`, `HC_STRUCTURE_UNSUPPORTED`, `HC_STRUCTURE_REBUILD_FAILED` |
| `invariant` | `HC_INVARIANT_PROTECTED_CONTENT`, `HC_INVARIANT_CLAIM`, `HC_INVARIANT_STRUCTURE`, `HC_INVARIANT_REVISION` |
| `adapter` | `HC_ADAPTER_UNAVAILABLE`, `HC_ADAPTER_TIMEOUT`, `HC_ADAPTER_PROTOCOL`, `HC_ADAPTER_OUTPUT_INVALID` |
| `model` | `HC_MODEL_UNAVAILABLE`, `HC_MODEL_TIMEOUT`, `HC_MODEL_OUTPUT_INVALID`, `HC_MODEL_BUDGET_EXCEEDED` |
| `consent` | `HC_CONSENT_REQUIRED`, `HC_CONSENT_SCOPE_EXCEEDED`, `HC_CONSENT_BLOCKED` |
| `io` | `HC_IO_READ`, `HC_IO_WRITE`, `HC_IO_TARGET_EXISTS`, `HC_IO_ATOMIC_REPLACE` |
| `check` | `HC_CHECK_REQUIRED_NOT_RUN`, `HC_CHECK_CONTRACT_MISMATCH` |
| `internal` | `HC_INTERNAL_UNEXPECTED`, `HC_INTERNAL_CONTRACT` |

Eine Invariantenverletzung beschreibt eine validierte Ausgabe, die eine Schutzregel verletzt. Ein Parser- oder Rebuild-Defekt ist ein Strukturfehler. Ein ungueltiger externer Adapteroutput ist ein Adapterfehler, bis der Kern daraus eine konkrete Invariantenverletzung nachweist. Unbekannte Exceptions werden ausschliesslich `HC_INTERNAL_UNEXPECTED` zugeordnet.

## Wiederholbarkeit und sichere Handlung

`retryability` ist einer der Werte:

- `never`: derselbe Aufruf darf nicht unveraendert wiederholt werden;
- `after_input_change`;
- `after_config_change`;
- `after_user_action`;
- `transient`: begrenzte Wiederholung nach Backoff erlaubt;
- `unknown`: keine automatische Wiederholung.

`safe_action` ist `none`, `fix_input`, `fix_configuration`, `review_scope`, `request_consent`, `retry_later`, `choose_adapter`, `choose_output`, `inspect_report` oder `report_defect`. Nur `transient` erlaubt eine automatische Wiederholung, und auch dann gelten Adapter- und Performancevertrag. Ein interner Fehler wird nie automatisch in einer unbeschraenkten Schleife wiederholt.

Die Standardmetadaten der Version 0.1.0 sind normativ:

| Codes | `retryability` | `safe_action` |
|---|---|---|
| `HC_INPUT_EMPTY`, `HC_INPUT_ENCODING` | `after_input_change` | `fix_input` |
| `HC_INPUT_SCOPE_INVALID`, `HC_INPUT_REVISION_MISMATCH` | `after_input_change` | `review_scope` |
| `HC_CONFIG_UNKNOWN_OPTION`, `HC_CONFIG_SCHEMA_UNSUPPORTED`, `HC_CONFIG_PROFILE_INVALID`, `HC_CONFIG_LOCALE_CONFLICT`, `HC_CONFIG_ENV_FORBIDDEN`, `HC_CONFIG_SECRET_MISSING` | `after_config_change` | `fix_configuration` |
| `HC_STRUCTURE_PARSE_FAILED`, `HC_STRUCTURE_UNSUPPORTED` | `after_input_change` | `fix_input` |
| `HC_STRUCTURE_REBUILD_FAILED` | `unknown` | `inspect_report` |
| `HC_INVARIANT_PROTECTED_CONTENT`, `HC_INVARIANT_CLAIM`, `HC_INVARIANT_STRUCTURE`, `HC_INVARIANT_REVISION` | `after_input_change` | `review_scope` |
| `HC_ADAPTER_UNAVAILABLE`, `HC_ADAPTER_PROTOCOL`, `HC_ADAPTER_OUTPUT_INVALID` | `after_config_change` | `choose_adapter` |
| `HC_ADAPTER_TIMEOUT` | `transient` | `retry_later` |
| `HC_MODEL_UNAVAILABLE`, `HC_MODEL_OUTPUT_INVALID` | `after_config_change` | `choose_adapter` |
| `HC_MODEL_TIMEOUT` | `transient` | `retry_later` |
| `HC_MODEL_BUDGET_EXCEEDED` | `after_config_change` | `fix_configuration` |
| `HC_CONSENT_REQUIRED`, `HC_CONSENT_SCOPE_EXCEEDED`, `HC_CONSENT_BLOCKED` | `after_user_action` | `request_consent` |
| `HC_IO_READ` | `after_user_action` | `fix_input` |
| `HC_IO_WRITE`, `HC_IO_TARGET_EXISTS`, `HC_IO_ATOMIC_REPLACE` | `after_user_action` | `choose_output` |
| `HC_CHECK_REQUIRED_NOT_RUN` | `after_config_change` | `inspect_report` |
| `HC_CHECK_CONTRACT_MISMATCH`, `HC_INTERNAL_CONTRACT` | `never` | `report_defect` |
| `HC_INTERNAL_UNEXPECTED` | `unknown` | `report_defect` |

## Ergebnisachsen

Der Ergebnisreport fuehrt unabhaengig:

- `workflow_status`: `pending`, `running`, `completed`, `failed`, `cancelled`;
- `adapter_status`: `disabled`, `unavailable`, `ready`, `degraded`, `failed`;
- `quality_disposition`: `not_evaluated`, `accepted`, `review_required`, `rejected`;
- `result`: `success`, `quality_rejected`, `partial_failure`, `incomplete`, `failed`, `cancelled`;
- `completed_checks` beziehungsweise einzelne Checkzustaende.

`quality_rejected` ist ein fachlich erfolgreich ausgefuehrtes negatives Ergebnis, kein Fehlerobjekt. Ein optionaler Adapterausfall kann bei gueltigem Fallback als Warnung mit `adapter_status=degraded` und `result=success` enden. Ein erforderlicher Adapterausfall ergibt `workflow_status=failed`. `review_required` ist bei Audit- und Preview-Operationen ein regulaerer Erfolg.

## Checkzustaende

Jeder deklarierte Check besitzt `status=passed`, `failed`, `not_run`, `skipped_optional` oder `blocked`. `skipped_optional` ist nur zulaessig, wenn der Check im effektiven Profil nicht erforderlich war, und zaehlt nie als bestanden. Ein erforderlicher `not_run`, `skipped_optional` oder `blocked` Check ergibt mindestens `result=incomplete` und `HC_CHECK_REQUIRED_NOT_RUN`.

## CLI-Exit-Codes

| Exit | Bedeutung |
|---:|---|
| 0 | regulaerer Erfolg, einschliesslich `accepted` oder `review_required` |
| 2 | Eingabefehler |
| 3 | Konfigurationsfehler |
| 4 | Strukturfehler |
| 5 | Invariantenverletzung |
| 6 | erforderlicher Adapterfehler |
| 7 | Modellfehler |
| 8 | fehlende Zustimmung oder ueberschrittener Consent-Scope |
| 9 | I/O-Fehler |
| 10 | interner Defekt oder Vertragsverletzung |
| 11 | partieller Batchfehler |
| 12 | erforderlicher Check nicht abgeschlossen |
| 13 | kontrollierter Abbruch |
| 20 | abgeschlossene fachliche Qualitaetsablehnung |

Skills und Bibliotheksaufrufe geben keinen Prozesscode vor, muessen aber `result`, Statusachsen und dieselbe Fehlerliste liefern. Eine CLI bildet diesen Report ohne Neuinterpretation auf den Exit-Code ab.

## Deterministische Exit-Auswahl

Fuer einen Einzeldokumentlauf gilt:

1. `cancelled` ergibt 13.
2. Ein technischer Fehler waehlt die Kategorie des primaeren fatalen oder fehlerhaften Eintrags.
3. Ohne technischen Fehler ergibt ein nicht abgeschlossener erforderlicher Check 12.
4. Ohne technischen Fehler und bei `quality_disposition=rejected` ergibt der Lauf 20.
5. Sonst ergibt der Lauf 0.

Bei mehreren technischen Fehlern wird der primaere Fehler nach folgender festen Rangfolge bestimmt: `internal`, `io`, `configuration`, `input`, `structure`, `invariant`, `consent`, `adapter`, `model`, `check`. Alle Fehler bleiben im Report erhalten; die Rangfolge veraendert ihre fachliche Ursache nicht.

Ein Batch mit mindestens einem erfolgreichen und mindestens einem fehlgeschlagenen oder unvollstaendigen Element ergibt 11. Sind alle Elemente auf dieselbe Weise fehlgeschlagen, gilt deren regulaerer Exit-Code. Sind alle Elemente fachlich abgelehnt und technisch abgeschlossen, gilt 20. Das Batchsummary weist Zaehler pro `result` und Exit-Code aus.

## Partielle Ergebnisse und Transaktionen

- Ein fehlgeschlagener Patch oder ein Segmentrollback wird gemaess Patchvertrag lokal behandelt und muss nicht den Dokumentworkflow scheitern lassen.
- Ein Dokument mit verbleibendem individuellen Review kann `completed`, `review_required` und Exit 0 sein.
- Eine unvollstaendige Uebersetzung oder ein fehlender erforderlicher Check darf nie `result=success` erhalten.
- Bereits erfolgreiche Batchelemente werden durch andere fehlerhafte Elemente nicht zurueckgerollt.
- Ein Teilreport besitzt dieselbe Contract-Version und eine eigene Scope-ID; Aggregation darf Fehler nicht verwerfen.

## Sichere Darstellung

Der Standardreport und die Standard-CLI-Ausgabe zeigen lokalisierten Meldungstext aus `message_key`, Code, Komponente, sichere Handlung und zulaessige Diagnostik. Ein Stacktrace ist nur in einem expliziten lokalen Debugmodus zulaessig, wird separat gespeichert und nie Teil des standardisierten Reports. Debugmodus darf weiterhin keine Secrets oder vollstaendigen Texte protokollieren.

## Testbare Invarianten

- Derselbe strukturierte Report ergibt in Skill, CLI und JSON dieselbe Fehlerklasse und denselben CLI-Exit-Code.
- `quality_disposition=rejected` erzeugt ohne technischen Fehler kein Fehlerobjekt und Exit 20.
- Ein optional uebersprungener Check wird nie als `passed` gezaehlt.
- Ein erforderlicher nicht ausgefuehrter Check kann weder Exit 0 noch `result=success` ergeben.
- Ein optionaler Adapterausfall mit gueltigem Fallback bleibt von einem erforderlichen Adapterfehler unterscheidbar.
- Ein gemischter Batch ergibt Exit 11 und behaelt alle elementbezogenen Fehler.
- `HC_INTERNAL_UNEXPECTED` enthaelt im Standardreport weder Exceptiontext noch Stacktrace noch Textinhalt.
- Jeder Fehlercode besitzt genau eine Kategorie, einen Standardwert fuer Wiederholbarkeit und eine sichere Handlung.

## Kompatibilitaet

Neue Fehlercodes und optionale Diagnostikfelder duerfen in einer Minor-Version hinzukommen. Die Umdeutung oder Entfernung eines Codes, eine geaenderte Exit-Zuordnung oder eine geaenderte Aggregationsregel erfordert eine neue Major-Version. Unbekannte Fehlercodes einer bekannten Major-Version werden erhalten und als nicht automatisch wiederholbar behandelt.
