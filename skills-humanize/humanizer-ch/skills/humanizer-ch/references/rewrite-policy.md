# Rewrite-Policy

## Eingriffstiefe

- `minimal`: einzelne bestätigte Formulierungen.
- `local`: Sätze und lokale Übergänge.
- `structural`: Absatzreihenfolge und Informationsfluss unter Bedeutungsmanifest.
- `rebuild`: Neuaufbau ausschliesslich aus verifizierten Aussagen und nach ausdrücklicher Freigabe.

Die tatsächliche Tiefe darf geringer sein. Null-Edit bleibt gültig.

## Freigabe

Ein Vorschlag referenziert Quellrevision, Segment, Span und Quell-Hash. Prüfe Schutzbereiche und harte Invarianten vor jeder Anwendung. Ein Modellurteil oder Konfidenzwert ist keine Freigabe. Bei Dateiänderungen atomar schreiben und anschliessend Struktur, Claims, Terminologie und Locale erneut prüfen.

## Auslieferung

Medium, Zielgruppe und Kommunikationszweck werden getrennt von Sprache, Locale und Register behandelt. Ein unbekanntes Medium verwendet `neutral`. Mediumsmerkmale sind keine KI-Tells.
