# Modell-, Rollen- und Effort-Vertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.orchestration`

## Zweck

Dieser Vertrag macht die Auswahl von Modellrolle und Effort reproduzierbar und testbar. Die Grundregel lautet: Modellfaehigkeit wird vor zusaetzlichem Effort priorisiert. Ein staerkeres Modell mit niedrigem Effort ist fuer semantisch anspruchsvolle Arbeit der Standardpfad; hoher Effort eines guenstigen Modells ist kein Ersatz fuer die passende Modellklasse.

Modellnamen sind versionierte Referenzzuordnungen, keine dauerhafte Produktlogik. Die Laufzeit routet primaer nach Rollen und Faehigkeitsklassen und weist Anbieter, Modellrevision und Effort im Report aus.

## Rollen vor Modellen

| Rolle | Aufgaben | Erforderliche Klasse |
|---|---|---|
| `deterministic_core` | Parsing, Schutzbereiche, Patches, Invarianten, Rekonstruktion | kein generatives Modell |
| `mechanical_support` | Extraktion, Normalisierung strukturierter Reports, eindeutige Klassifikation | kleine Klasse, niedriger Effort |
| `preanalysis` | Sprach- und Locale-Kandidaten, Befundbündelung, Priorisierung | mittlere Klasse, niedriger Effort |
| `semantic_editor` | KI-Tells, Idiomatik, Register, Stimmerhalt, lokales Rewrite, Proofread-Adjudikation | starke Klasse, niedriger Effort |
| `semantic_escalation` | mehrdeutige oder risikoreiche Segmente, strukturelle Eingriffe, juristische Modalitaet | Spitzenklasse, niedriger bis mittlerer Effort |

Eine Aufgabe darf nicht an `mechanical_support` oder `preanalysis` delegiert werden, wenn ihr Ergebnis selbst die semantische Freigabe bestimmt.

## Referenzzuordnung

| Rolle | OpenAI | Anthropic | Effortstandard |
|---|---|---|---|
| `mechanical_support` | Luna | Haiku | `low` |
| `preanalysis` | Terra | Sonnet | `low` |
| `semantic_editor` | Sol | Opus | `low` |
| `semantic_escalation` | Astra | Fable | `low`, bei kritischen Faellen `medium` |

Die Zuordnungen werden als Routingprofil versioniert. Ein Ersatzmodell muss dieselbe Rolle in einer separaten Evaluation bestehen; eine aehnliche Preis- oder Groessenklasse genuegt nicht.

## Standardprofile

### `practical_default`

- deterministische Vorpruefung;
- optional `preanalysis` mit niedrigem Effort bei langen oder heterogenen Eingaben;
- genau ein `semantic_editor`-Pass mit niedrigem Effort;
- deterministische Nachpruefung;
- `semantic_escalation` nur fuer markierte Segmente mit einem maschinenlesbaren Eskalationsgrund.

### `critical_review`

- `semantic_editor` mit niedrigem Effort als Erstpruefung;
- deterministische Nachpruefung;
- `semantic_escalation` mit niedrigem Effort nur fuer mehrdeutige, risikoreiche oder invariantengefaehrdete Stellen;
- mittlerer Effort der Spitzenklasse nur fuer verbleibende kritische Unsicherheit.

`critical_review` bezeichnet strengere Pruefung, nicht maximalen Rewrite und nicht automatisch zwei Modell-Passes. Ein unauffaelliger Text darf nach dem ersten starken Pass als Null-Edit enden.

### `economy_audit`

- deterministische Vorpruefung;
- `preanalysis` mit niedrigem Effort fuer Audit und Kandidatenbildung;
- keine semantische Endfreigabe durch die mittlere oder kleine Klasse;
- bei gewuenschter Endfreigabe auf `semantic_editor` eskalieren.

## Effort- und Eskalationsregeln

1. Standard ist `low` auf der fuer die Aufgabe passenden Modellklasse.
2. Bei ungenuegender Tiefe zuerst innerhalb derselben starken Klasse auf `medium` erhoehen oder auf die Spitzenklasse mit `low` wechseln. Der Router zeichnet den Grund auf.
3. Terra und Sonnet verwenden standardmaessig `low`, hoechstens `medium`; darueber wird die Modellklasse gewechselt.
4. Luna und Haiku verwenden nur `low`. Sobald Schlussfolgern oder semantische Freigabe erforderlich ist, ist die Delegation falsch.
5. Astra und Fable verwenden `low`, bei kritischer Restunsicherheit `medium`.
6. `high`, `xhigh` und `max` sind im Normalbetrieb deaktiviert. Eine spaetere Freigabe braucht eine eigene Evaluation zu Qualitaetsgewinn, Latenz und Kosten.
7. Mehrere billige Hoch-Effort-Aufrufe duerfen nicht als Ersatz fuer einen passenden starken Aufruf geplant werden.
8. Anbieterfamilien sind Alternativen. Ein Text wird nicht standardmaessig durch beide Familien geschickt.

Zulaessige Eskalationsketten:

```text
OpenAI: Sol low -> Sol medium oder Astra low -> Astra medium
Anthropic: Opus low -> Opus medium oder Fable low -> Fable medium
```

Die Wahl zwischen mehr Effort und hoeherer Klasse wird durch Evaluation bestimmt. Ohne belastbare Messung gilt fuer semantisch schwierige Aufgaben der Klassenwechsel mit niedrigem Effort als bevorzugte Hypothese.

## Routingnachweis

Jeder generative Aufruf protokolliert ohne Textinhalt:

```json
{
  "routing_profile": "practical_default@1",
  "model_role": "semantic_editor",
  "provider": "openai",
  "model_id": "sol",
  "model_revision": "...",
  "effort": "low",
  "scope_mode": "selection",
  "escalation_reason": null,
  "input_tokens": 0,
  "output_tokens": 0,
  "latency_ms": 0
}
```

## Testmatrix

Die Evaluation vergleicht mindestens folgende Varianten auf demselben eingefrorenen Korpus:

| Test-ID | Kandidat | Vergleichszweck |
|---|---|---|
| `R1` | Terra oder Sonnet `high` | billigeres Modell mit hohem Effort als Gegenprobe |
| `R2` | Sol oder Opus `low` | Standard fuer semantische Arbeit |
| `R3` | Astra oder Fable `low` | Faehigkeitsgewinn bei niedrigem Effort |
| `R4` | Astra oder Fable `medium` | Zusatznutzen bei kritischen Faellen |

OpenAI- und Anthropic-Reihen werden getrennt ausgewertet; Ergebnisse verschiedener Anbieter werden nicht zu einem gemeinsamen Mittelwert vermischt. Jeder Testlauf fixiert den exakten Modell-Identifier, die Modellrevision, das Routingprofil, den Promptvertrag und die Samplingparameter. Bewegliche Modellaliase allein sind kein reproduzierbarer Testnachweis.

Gemessen werden mindestens:

- Erhalt von Claims, Modalitaet, Sprecherposition und geschuetzten Inhalten;
- Praezision und Recall der bestaetigten sprachlichen Befunde;
- False-Positive- und Null-Edit-Rate;
- idiomatische und registergerechte Qualitaet durch sprachkundige Blindbewertung;
- unnoetige Aenderungstiefe und Patch-Verwerfungen;
- End-to-End-Latenz, Modellaufrufe und normalisierte Kosten;
- Eskalationsquote und Qualitaetsgewinn pro Eskalation.

Ein Profil wird nur Standard, wenn es die harte Invariantenrate der staerkeren Vergleichsprofile erreicht und auf dem Zielkorpus den besten gangbaren Trade-off aus Qualitaet, Latenz und Kosten liefert. Die Bezeichnung `maximale Qualitaet` ist ohne spezifisches Korpus und nachgewiesenen Vorsprung unzulaessig.

## Kompatibilitaet

- Aenderungen an Referenzmodellen oder Schwellen erzeugen eine neue Routingprofilversion.
- Neue optionale Rollen duerfen in einer Minor-Version hinzukommen.
- Geaenderte Freigabeautoritaet, Effortsemantik oder Standard-Eskalationsketten erfordern eine neue Major-Version.
- Reports muessen historische Routingprofile weiterhin eindeutig interpretieren koennen.
