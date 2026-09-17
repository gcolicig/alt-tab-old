# Auswahl- und Kontextvertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.documents`

## Zweck

Dieser Vertrag erlaubt die gezielte Pruefung einzelner Textbausteine, ohne daraus eine dokumentweite Pruefung abzuleiten oder das ganze Dokument an ein Modell zu senden.

## Pruefbereiche

| Modus | Editierbarer Bereich | Zulaessige Aussage |
|---|---|---|
| `document` | alle freigegebenen Dokumentsegmente | lokale und dokumentweite Checks gemaess `completed_checks` |
| `selection` | explizite revisionsgebundene Spannen | nur Auswahl und tatsaechlich ausgefuehrte lokale Checks |
| `segments` | explizite stabile Segment-IDs | ausgewaehlte Segmente und explizit ausgefuehrte segmentuebergreifende Checks |

Direkt eingefuegter Text wird als synthetisches Ein-Segment-Dokument mit eigener Revision behandelt.

## Auswahlidentitaet

Eine Dateiauswahl enthaelt mindestens:

```json
{
  "source_revision": "rev-...",
  "segment_id": "t00017",
  "format_node_id": "node-...",
  "span": {"start": 0, "end": 120},
  "source_hash": "sha256:..."
}
```

Eine Auswahl ist ungueltig, wenn Revision, Segment, Formatknoten, Span oder Quell-Hash nicht mehr uebereinstimmen. Der Kern darf sie nicht still auf aehnlichen Text verschieben.

## Kontext

- `context_before` und `context_after` sind optional und nicht editierbar.
- Standard ist hoechstens der unmittelbar benachbarte Absatz je Seite.
- Mehr Kontext braucht einen expliziten Nutzerauftrag oder einen maschinenlesbaren strukturellen Grund.
- Kontext wird weder als geprueft noch als freigegeben ausgewiesen.
- Der Modellrequest enthaelt keine nicht erforderlichen Volltextsegmente.

## Manifest und Wiederverwendung

Bei unveraenderter Dokumentrevision wird das vorhandene Manifest samt Segmentindex wiederverwendet. Fehlt es, darf der Formatadapter die Datei einmal strukturell parsen, aber keine sprachliche Volltextanalyse ausloesen. Der erste Parse und die warme Auswahlpruefung werden getrennt gemessen.

## Review-Profil `critical_text`

Die Formulierungen «diesen Textbaustein kritisch pruefen» und «kritischen Text pruefen» routen standardmaessig zu:

```text
operation=audit
scope_mode=selection
review_profile=critical_text
```

Das Profil prueft Claims, Modalitaet, lokale Logik, Idiomatik, Register, KI-Tell-Cluster und Stimmerhalt strenger. Es erhoeht weder Rewrite-Tiefe, Modellklasse, Effort noch Passzahl automatisch. Eine Ueberarbeitung oder Dateiaenderung braucht einen entsprechenden Auftrag.

## Status und Report

Der Report enthaelt:

- `evaluated_scope`;
- `context_scope`;
- `scope_limitations`;
- `completed_checks`;
- dokumentweite Checks mit dem Zustand `not_run`.

Ein Ergebnis darf `quality_disposition=accepted` fuer die Auswahl besitzen, waehrend dokumentweite Qualitaet `not_evaluated` bleibt. Beide Aussagen duerfen nicht zu einem globalen Gesamturteil zusammengezogen werden.

## Harte Invarianten

- Patches duerfen nur innerhalb der Auswahl liegen.
- Nicht ausgewaehlter Text und Kontext bleiben bytegleich oder gemaess Adaptergarantie semantisch unveraendert.
- Dokumentstruktur und geschuetzte Inhalte werden auch bei lokaler Bearbeitung verifiziert.
- Dokumentweite Vollstaendigkeit, Terminologiekonsistenz, Argumentationsstruktur und Registerkonsistenz werden ohne Volltextpruefung nie als abgeschlossen markiert.

## Performance- und Datenschutznachweis

Auswahl-, Kontext- und Volltexttokens werden separat berichtet. Bei einer Auswahl muessen Volltexttokens im Modellrequest null sein. Logs enthalten keine Textinhalte. Die Latenzbudgets folgen `performance-budget.md`, das Modell-Routing `model-routing.md`.

## Kompatibilitaet

- Neue optionale Reportfelder duerfen in einer Minor-Version hinzukommen.
- Geaenderte Auswahlidentitaet, Kontextgrenzen oder globale Freigabesemantik erfordern eine neue Major-Version.
- Unbekannte Major-Versionen werden abgelehnt.
