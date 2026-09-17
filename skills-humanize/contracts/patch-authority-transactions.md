# Patch-Autoritaets- und Transaktionsvertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.patches`

## Zweck

Dieser Vertrag trennt Vorschlag, Policy-Entscheid, Nutzerzustimmung, Anwendung und Verifikation. Ein Modell ist Vorschlagsquelle, nie Entscheidungsautoritaet.

## Zustaende

Jeder Patch fuehrt vier getrennte Zustandsfelder:

| Achse | Werte |
|---|---|
| `proposal_status` | `proposed`, `invalid`, `superseded` |
| `policy_decision` | `auto_approved`, `request_eligible`, `individual_review`, `blocked` |
| `user_decision` | `not_required`, `not_requested`, `approved_by_request`, `pending`, `approved`, `rejected` |
| `application_status` | `not_applied`, `applied`, `verification_failed`, `rolled_back` |

Ein Patch ist effektiv freigegeben, wenn eine der folgenden Kombinationen gilt:

- `auto_approved` und `not_required`;
- `request_eligible` und `approved_by_request`;
- `individual_review` und `approved`.

`blocked` kann nicht durch einen Agenten oder eine normale Nutzerfreigabe ueberschrieben werden. `approved_by_request` gilt nur innerhalb der explizit angeforderten Operation, Eingriffstiefe, Zieldatei und Schutzregeln.

## Entscheidungsautoritaet

| Quelle | Darf vorschlagen | Darf automatisch freigeben | Darf Blocker aufheben |
|---|---:|---:|---:|
| Deterministische Kernregel | ja | nur freigegebene sichere Regelklasse | nein |
| Grammatik- oder Sprachengine | ja | nein | nein |
| Generatives Modell | ja | nein | nein |
| Policy-Engine | nein | nach festem Regelprofil | nein |
| Nutzerin oder Nutzer | nein | durch expliziten Auftrag oder Einzelentscheid | nur nicht-harte Reviewfaelle |

Harte Struktur-, Schutz-, Revisions- und Sicherheitsblocker koennen nicht durch normale Patchfreigabe aufgehoben werden. Dafuer ist ein neuer Auftrag mit geaenderten Schutzregeln erforderlich.

## Consent-Modi

| Modus | Verhalten |
|---|---|
| `preview` | Nichts anwenden; Vorschlaege und Entscheide ausgeben |
| `safe_only` | Nur deterministisch `auto_approved` anwenden |
| `apply_within_request` | `request_eligible`-Patches innerhalb des expliziten Auftrags und der maximalen Eingriffstiefe als `approved_by_request` behandeln; individuelle Reviews und Blocker bleiben bestehen |
| `interactive` | Jeden nicht deterministischen Patch einzeln bestaetigen |

Standards:

- `humanizer audit`: `preview`
- `humanizer rewrite`: `apply_within_request`, aber keine Eingabedatei veraendern
- `humanizer edit-file`: `apply_within_request` mit atomarem Dateiaustausch
- `proofread correct`: `safe_only`
- `proofread edit`: `apply_within_request`
- `translation-qa`: `preview`
- `translate-ch`: Ausgabe in neue Datei; keine Quellueberschreibung

## Transaktionsumfang

| Umfang | Typische Fehler | Wirkung |
|---|---|---|
| Patch | veralteter Span, Policy-Blocker | nur Patch verwerfen |
| Segment | Bedeutungsmanifest oder Segmentinvariante verletzt | alle Patches des Segments zurueckrollen; Originalsegment behalten |
| Dokument | Struktur, Vollstaendigkeit, geschuetzte Tokens oder Rebuild verletzt | gesamte neue Dokumentausgabe verwerfen |
| Batch | einzelnes Dokument fehlgeschlagen | andere Dokumente nicht zurueckrollen; Batch als teilweise fehlgeschlagen melden |

Ein lokaler Patch- oder Segmentfehler darf kein unveraendertes, weiterhin gueltiges Dokument vernichten. Eine partielle Uebersetzung darf jedoch nie als vollstaendige Uebersetzung freigegeben werden.

## Atomare Anwendung

1. Alle effektiv freigegebenen Patches gegen dieselbe Quellrevision sammeln.
2. Konflikte und Ueberlappungen aufloesen oder blockieren.
3. Patches in einer Arbeitskopie anwenden.
4. Patch-, Segment- und Dokumentinvarianten pruefen.
5. Bei Dokumenterfolg atomar in die Zieldatei verschieben.
6. Bei Fehler Arbeitskopie verwerfen und Original unveraendert lassen.

Direktes Ueberschreiben der Eingabedatei erfolgt nur bei `edit-file`, expliziter Nutzerabsicht und erfolgreicher Dokumentverifikation.

## Ergebnisstatus

- Ein Dokument mit verworfenen optionalen Patches kann `completed` und `review_required` sein.
- Ein unveraendertes Dokument nach Null-Edit kann `completed` und `accepted` sein.
- Eine strukturell ungueltige Ausgabe ist `failed` und `rejected`.
- Adapterausfall setzt `adapter_status`, darf aber einen erfolgreichen kernlokalen Workflow nicht umdeuten.
