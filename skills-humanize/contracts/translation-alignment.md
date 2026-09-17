# Source-Target-Alignment-Vertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.alignment`

## Zweck

Dieser Vertrag erlaubt Translation QA sowohl fuer systemeigene Uebersetzungen mit gemeinsamen IDs als auch fuer externe Quelle-Ziel-Paare ohne gemeinsames Manifest. Unsichere Zuordnungen werden nie still als sicher behandelt.

## Alignment-Modi

Die Modi werden in dieser Reihenfolge versucht:

1. `shared_id`: gemeinsame, revisionsgueltige Manifest-IDs
2. `explicit_map`: vom Nutzer oder Vorsystem gelieferte Zuordnung
3. `structural`: Zuordnung ueber Dokumentrolle, Reihenfolge und harte Anker
4. `sentence_fallback`: monotones Satzalignment innerhalb bereits zugeordneter Bloecke

Ein semantisches Modell oder Embeddings duerfen Evidenz liefern, aber keine widersprechenden harten Anker ueberschreiben.

## Alignment-Einheit

```json
{
  "alignment_id": "a-0001",
  "source_segment_ids": ["s0001"],
  "target_segment_ids": ["t0001"],
  "relation": "one_to_one",
  "method": "shared_id",
  "confidence": 1.0,
  "status": "accepted",
  "evidence": ["shared_manifest_id"],
  "hard_anchor_conflicts": []
}
```

Erlaubte Relationen sind `one_to_one`, `one_to_many`, `many_to_one`, `unaligned_source`, `unaligned_target` und `reordered`.

Statuswerte:

- `accepted`: automatische QA darf ausgefuehrt werden
- `review_required`: QA darf Befunde erzeugen, aber keine Alignment-abhaengige Auto-Freigabe
- `rejected`: Paar wird nicht semantisch verglichen

## Strukturelles Fallback

Das Fallback arbeitet hierarchisch:

1. Dokumentrollen wie Titel, Heading, Absatz, Listenpunkt, Tabellenzelle und Zitat abgleichen.
2. Eindeutige harte Anker wie Zahlen, Einheiten, URLs, Normen, Namen und geschuetzte Begriffe nutzen.
3. Monotone dynamische Zuordnung mit `one_to_one`, `one_to_many`, `many_to_one` und Skip-Kandidaten berechnen.
4. Laengenverhaeltnis, Position und optionale semantische Aehnlichkeit als weiche Evidenz verwenden.
5. Neuordnungen nur bei eindeutigen Ankern erkennen und immer mindestens als `review_required` markieren.

Harte Konflikte, etwa verschiedene eindeutige Zahlen oder Normreferenzen, verhindern `accepted` unabhaengig vom semantischen Score.

## Konfidenzprofil

Initiale Standardgrenzen, spaeter pro Sprachpaar zu kalibrieren:

| Bedingung | Status |
|---|---|
| gemeinsame gueltige ID ohne Konflikt | `accepted` |
| explizite Map ohne Konflikt | `accepted` |
| Fallback-Konfidenz mindestens 0.90 ohne harten Konflikt | `accepted` |
| Fallback-Konfidenz 0.70 bis unter 0.90 | `review_required` |
| Konfidenz unter 0.70 oder harter Konflikt | `rejected` beziehungsweise unaligned |

Schwellen sind versionierter Bestandteil eines Sprachpaarprofils. Eine Aenderung invalidiert Alignment-Caches.

## Abdeckung und QA

Der Report enthaelt mindestens:

- Wort- und Segmentabdeckung fuer Quelle und Ziel;
- akzeptierte, reviewpflichtige und unalignierte Einheiten;
- erkannte Neuordnungen;
- harte Ankerkonflikte;
- Alignment-Profil und Profilversion.

`quality_disposition=accepted` ist nur zulaessig, wenn die im Profil definierte Mindestabdeckung erreicht ist und keine harten Konflikte oder ungeklaerten Pflichtsegmente bestehen. Globale harte Invarianten duerfen auch bei unvollstaendigem Alignment laufen; semantische Vollstaendigkeitsaussagen duerfen es nicht.

## Performance

- `shared_id` und `explicit_map` muessen linear zur Segmentzahl arbeiten.
- Strukturelles Fallback wird pro Dokumentabschnitt begrenzt und vermeidet eine unbeschraenkte quadratische Vollmatrix.
- Semantische Embeddings werden gebatcht, gecacht und nur bei verbleibender Mehrdeutigkeit berechnet.
