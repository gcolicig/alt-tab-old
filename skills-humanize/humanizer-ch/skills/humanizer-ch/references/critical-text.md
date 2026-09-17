# Kritische Prüfung einzelner Textbausteine

Verwende `operation=audit`, `scope_mode=selection` und `review_profile=critical_text`, sofern keine Änderung verlangt wurde.

Prüfe den ausgewählten Baustein auf:

- Claims, Modalität und lokale logische Brüche;
- sprachspezifische KI-Tell-Cluster und technische Artefakte;
- Idiomatik und wahrscheinliche Transfers aus einer anderen Sprache;
- Register, Anrede und Sprecherposition;
- belegte positive Stimmmerkmale, die erhalten bleiben müssen;
- lokale Präzision, Rhythmus und unnötige Abstraktion.

Nutze höchstens den unmittelbar benachbarten Absatz je Seite als nicht editierbaren Kontext. Weise `evaluated_scope`, `context_scope`, `scope_limitations` und `completed_checks` aus. Dokumentweite Vollständigkeit, Terminologie, Argumentationsstruktur und Registerkonsistenz bleiben `not_run`.

`critical_text` erhöht weder Rewrite-Tiefe noch Modellklasse, Effort oder Passzahl automatisch. Ein starker Low-Effort-Pass ist der Ausgangspunkt; nur konkret markierte Restunsicherheit darf eskalieren.
