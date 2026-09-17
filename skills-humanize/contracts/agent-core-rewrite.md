# Agent-Core- und Rewrite-Proposal-Vertrag

Status: Normativer Entwurf 0.1.0
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
- Ein leerer Vorschlagssatz ist ein gueltiges Null-Edit-Ergebnis.

## Kompatibilitaet

- Patch-Versionen duerfen nur optionale Felder und Enumwerte ergaenzen.
- Neue Pflichtfelder oder geaenderte Semantik erfordern eine neue Major-Version.
- Unbekannte Major-Versionen werden abgelehnt.
