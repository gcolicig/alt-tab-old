# Agent-Core- und Rewrite-Proposal-Vertrag

Status: Normativer Entwurf 0.2.0
Verantwortung: `humanizer_ch_core.orchestration`

## Zweck

Dieser Vertrag trennt sprachliche Generierung vom deterministischen Dokumentkern. Der Agent darf Aenderungen vorschlagen, aber weder Quellrevisionen umgehen noch Patches anwenden oder Qualitaetsstatus setzen.

## Ablauf

1. Der Kern parst das Dokument und erzeugt Revision, Manifest, Schutzbereiche und Befunde.
2. Der Orchestrator baut genau einen `rewrite_request` pro Modellbatch.
3. Der Agent antwortet ausschliesslich mit einem `rewrite_proposal_set`.
4. Der Kern validiert Schema, Revision, Spans, Schutzbereiche, Eingriffstiefe und Invarianten.
5. Die Entscheidungslogik aus `patch-authority-transactions.md` bestimmt, welche Vorschlaege anwendbar sind.

## Rewrite Request

Pflichtfelder:

| Feld | Typ | Bedeutung |
|---|---|---|
| `contract_version` | String | Semantische Vertragsversion |
| `request_id` | String | Eindeutige Anfrage-ID |
| `operation` | Enum | `humanize` oder `proofread_edit` |
| `source_revision` | String | Unveraenderliche Basisrevision |
| `document_format` | Enum | `text`, `markdown` oder `json` |
| `scope_mode` | Enum | `document`, `selection` oder `segments` |
| `scope` | Objekt | Editierbare Segment-IDs oder revisionsgebundene Spannen |
| `review_profile` | String | `standard`, `critical_text` oder versioniertes Projektprofil |
| `language` | String | BCP-47-Sprache oder `und` |
| `locale` | String oder null | BCP-47-Locale |
| `register` | Enum | `locker`, `sachlich`, `formal` |
| `delivery_profile` | String | Deklariertes Auslieferungsprofil |
| `max_rewrite_depth` | Enum | `minimal`, `local`, `structural`, `rebuild` |
| `consent_mode` | Enum | `preview`, `safe_only`, `apply_within_request`, `interactive` |
| `segments` | Array | Editierbare Segmente mit stabilen IDs |
| `findings` | Array | Befunde, die der Agent bearbeiten darf |
| `protected_items` | Array | Unveraenderliche Tokens, Claims und Strukturen |
| `glossary` | Objekt | Pflichtbegriffe und verbotene Varianten |
| `voice_profile` | Objekt | Belegte positive und negative Persona-Locks |

Jedes Segment enthaelt `segment_id`, `source`, `source_hash`, `language`, `locale`, `editable_ranges`, `protected_ranges` und bei `structural` oder `rebuild` ein eingefrorenes Bedeutungsmanifest.

Der Agent erhaelt nur Segmente, die fuer die angeforderte Operation erforderlich sind. Nicht editierbare Dokumentteile werden als Hash, Referenz oder knapper Kontext uebergeben, nicht als bearbeitbarer Text.

## Pruefbereich und einzelne Textbausteine

Auswahlidentitaet, Kontextgrenzen, Statussemantik und Wiederverwendung folgen `selection-scope.md`.

`scope_mode=selection` prueft einen oder mehrere explizit ausgewaehlte Textbausteine, ohne das gesamte Dokument an das Modell zu senden oder erneut zu analysieren. Eine Auswahl aus einer Datei muss `source_revision`, Segment-ID, Span, Quell-Hash und Formatknoten referenzieren. Direkt eingefuegter Text wird als synthetisches Ein-Segment-Dokument mit eigener Revision behandelt.

Bei einer unveraenderten Datei wird das vorhandene Manifest wiederverwendet. Fehlt ein Manifest, darf der Formatadapter die Datei einmal strukturell parsen, aber keine sprachliche Volltextanalyse ausloesen. Wiederholte Pruefungen derselben Revision arbeiten ueber den Index der stabilen Segment-IDs.

Optionaler Kontext wird als `context_before` und `context_after` uebergeben, ist nicht editierbar und wird nicht als geprueft ausgewiesen. Standardmaessig wird hoechstens der unmittelbar benachbarte Absatz je Seite geladen. Mehr Kontext braucht einen expliziten Auftrag oder einen dokumentierten strukturellen Grund.

Das Profil `critical_text` bedeutet:

- Arbeitszweig `audit`, sofern keine Ueberarbeitung verlangt wurde;
- strengere Pruefung von Claims, Modalitaet, Logik, Idiomatik, Register, KI-Tell-Clustern und Stimmerhalt;
- keine automatische Erhoehung der Rewrite-Tiefe;
- keine Behauptung ueber dokumentweite Vollstaendigkeit, Terminologiekonsistenz, Argumentationsstruktur oder Registerkonsistenz.

Im Report stehen `evaluated_scope`, `context_scope`, `scope_limitations` und die wirklich abgeschlossenen Pruefungen. Dokumentweite Checks bleiben `not_run`, sofern nicht das vollstaendige Dokument geprueft wurde.

## Rewrite Proposal Set

Pflichtfelder:

| Feld | Typ | Bedeutung |
|---|---|---|
| `contract_version` | String | Muss mit der Anfrage kompatibel sein |
| `request_id` | String | Referenz auf die Anfrage |
| `source_revision` | String | Muss exakt uebereinstimmen |
| `generator` | Objekt | Anbieter, Modell, Modellrevision und Promptvertragsversion |
| `proposals` | Array | Null oder mehr Aenderungsvorschlaege |
| `warnings` | Array | Unsicherheiten ohne Statuswirkung |

Jeder Vorschlag enthaelt:

```json
{
  "proposal_id": "p-0001",
  "segment_id": "t00001",
  "source_span": {"start": 12, "end": 38},
  "source_hash": "sha256:...",
  "replacement": "...",
  "change_type": "idiom|register|clarity|rhythm|structure|proofread",
  "rewrite_depth": "minimal|local|structural|rebuild",
  "finding_ids": ["finding-001"],
  "rationale_code": "idiomatic_transfer",
  "confidence": 0.0,
  "semantic_risk": "low|medium|high",
  "requires_review": true
}
```

`confidence` ist eine Agentenselbsteinschaetzung und keine Freigabe. Freitextbegruendungen sind optional; `rationale_code` ist Pflicht.

## Validierungsregeln

Ein Vorschlag ist schemaungueltig oder blockiert, wenn mindestens eine Bedingung zutrifft:

- Anfrage-ID oder Quellrevision stimmt nicht ueberein;
- Segment, Span oder Quell-Hash existiert nicht mehr;
- Ersatz ueberschreibt einen geschuetzten Bereich;
- angegebene Eingriffstiefe ueberschreitet `max_rewrite_depth`;
- ein neuer harter Anker, eine neue Behauptung oder eine neue Persona-Eigenschaft entsteht;
- `structural` oder `rebuild` besitzt kein Bedeutungsmanifest;
- mehrere Vorschlaege ueberlappen ohne explizite Konfliktgruppe;
- der Agent liefert kompletten Dokumenttext statt positionsgebundener Vorschlaege, sofern der Vertrag dies nicht fuer `rebuild` explizit erlaubt.

## Batching und Kontext

- Vorschlaege werden pro Dokument moeglichst in einem Batch erzeugt.
- Segmentweises N-plus-eins-Aufrufen ist unzulaessig, wenn die Segmente gemeinsam in das Kontextbudget passen.
- Kontextsegmente werden als nicht editierbar markiert.
- Unveraenderte Segmente werden nicht erneut generiert.
- Bei `selection` werden nur ausgewaehlte Spannen editiert; Kontext und nicht ausgewaehlte Teile bleiben unveraendert.
- Ein leerer Vorschlagssatz ist ein gueltiges Null-Edit-Ergebnis.

## Kompatibilitaet

- Patch-Versionen duerfen nur optionale Felder und Enumwerte ergaenzen.
- Neue Pflichtfelder oder geaenderte Semantik erfordern eine neue Major-Version.
- Unbekannte Major-Versionen werden abgelehnt.
