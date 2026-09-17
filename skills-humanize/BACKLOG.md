# Humanizer CH - Backlog

Status: Initialer Produktbacklog 0.3
Prioritaeten: P0 blockiert den Produktkern, P1 ist fuer Version 1.0 erforderlich, P2 verbessert Qualitaet oder Betrieb, P3 ist spaeter optional.

## Arbeitsregeln

- Jedes Ticket braucht beobachtbare Abnahmekriterien.
- Neue Sprachregeln brauchen mindestens einen Positiv- und einen False-Positive-Test.
- Automatische Fixes brauchen staerkere Evidenz als reine Audit-Befunde.
- Ein Adapterfehler darf keine Kernfunktion beschaedigen.
- Refactorings duerfen bestehende `humanizer-de`-Faelle nicht still verschlechtern.

## Epic A - Baseline und Migration

### HC-001 - Bestand inventarisieren

- Prioritaet: P0
- Aufgabe: Alle Muster, Referenzen, Skripte, CLI-Optionen und Tests von `humanizer-de` erfassen.
- Ergebnis: Maschinenlesbare Inventarliste mit Quelle, Verantwortlichkeit und Zielmodul.
- Abnahme:
  - jedes der 72 Muster ist klassifiziert;
  - jedes Skript besitzt einen Migrationsentscheid;
  - doppelte oder verwaiste Ressourcen sind markiert.

### HC-002 - Baseline-Korpus einfrieren

- Prioritaet: P0
- Aufgabe: Bestehende Positiv-, Null-Edit- und False-Positive-Faelle versionieren.
- Abhaengigkeiten: HC-001
- Abnahme:
  - aktueller Testlauf ist reproduzierbar;
  - Kennzahlen und erwartete Befundarten sind gespeichert;
  - sensible oder proprietaere Texte sind nicht im Korpus enthalten.

### HC-003 - Kompatibilitaetsvertrag definieren

- Prioritaet: P0
- Aufgabe: Verhalten fuer bisherige Muster-IDs, CLI-Aufrufe und Reports festlegen.
- Abhaengigkeiten: HC-001
- Abnahme:
  - Breaking Changes sind explizit benannt;
  - Deprecation-Pfad ist testbar;
  - keine still umgedeutete Option.

### HC-004 - Plugin- und Paketarchitektur festlegen

- Prioritaet: P0
- Aufgabe: Grenzen zwischen Plugin, Skills, gemeinsamem Python-Kern und optionalen Abhaengigkeiten als Architecture Decision Record festlegen.
- Abhaengigkeiten: HC-001
- Abnahme:
  - `humanizer-ch` und `proofread-ch` sind getrennte, duenne Skill-Einstiege;
  - `humanizer_ch_core` besitzt Dokument-, Sprach-, Befund-, Patch-, Invarianten- und Adapterschichten ohne duplizierte Skilllogik;
  - TranslateGemma und schwere NLP-Komponenten sind optionale Abhaengigkeiten;
  - Ressourcenbesitz, Importgrenzen und Kompatibilitaetsschicht sind dokumentiert.

### HC-005 - Befehls- und Aufgabenverantwortung festlegen

- Prioritaet: P0
- Aufgabe: Humanisierung, Proofreading, Translation QA und Uebersetzung trennscharfen Einstiegen zuordnen.
- Abhaengigkeiten: HC-003, HC-004
- Abnahme:
  - `humanizer-ch` besitzt keinen `translate`-Unterbefehl;
  - `translate-ch` ist ein eigener optionaler CLI-Einstieg;
  - `proofread-ch translation-qa` bleibt ohne TranslateGemma nutzbar;
  - kein Einstieg leitet aus einem Humanizer-Auftrag implizit eine Uebersetzung ab.

### HC-006 - Architektur-Gate freigeben

- Prioritaet: P0
- Aufgabe: Vor Implementierungsbeginn die versionierten Vertrage fuer Statusachsen, Invarianten, Patch-Entscheidungen, Revisionen, Checkpoints, Formatadapter und Qualitaetsgates freigeben.
- Abhaengigkeiten: HC-001, HC-002, HC-003, HC-004, HC-005, HC-007, HC-008, HC-064, HC-076
- Abnahme:
  - jeder Vertrag besitzt verantwortliches Modul, Schema-Version und Abwaertskompatibilitaetsregel;
  - Workflow-, Adapter- und Qualitaetsstatus sind orthogonal;
  - Checkpoint-Identitaet und Patch-Basisrevision sind vollstaendig definiert;
  - Klartext-, Markdown- und JSON-Adapter folgen demselben Protokoll;
  - harte und baseline-abhaengige Release-Gates sind messbar;
  - die erste Implementierungsiteration startet erst nach dokumentierter Freigabe.

### HC-007 - Agent-Core- und Rewrite-Proposal-Vertrag

- Prioritaet: P0
- Aufgabe: Versionierten Request-, Proposal-, Generatorprovenienz-, Batching- und Validierungsvertrag definieren.
- Abhaengigkeiten: HC-004, HC-005
- Ergebnis: `contracts/agent-core-rewrite.md`
- Abnahme:
  - Agent liefert nur positionsgebundene Vorschlaege gegen eine Quellrevision;
  - jeder Vorschlag besitzt Span-Hash, Aenderungstyp, Eingriffstiefe, Befundreferenzen und semantisches Risiko;
  - Agentenkonfidenz besitzt keine Freigabewirkung;
  - Null-Edit und gebatchte Verarbeitung sind explizit erlaubt;
  - unbekannte Major-Versionen werden abgelehnt.

### HC-008 - Patch-Autoritaet und Transaktionsumfang

- Prioritaet: P0
- Aufgabe: Vorschlag, Policy-Entscheid, Nutzerzustimmung, Anwendung sowie Patch-, Segment-, Dokument- und Batchtransaktionen trennen.
- Abhaengigkeiten: HC-005, HC-007
- Ergebnis: `contracts/patch-authority-transactions.md`
- Abnahme:
  - generative Modelle besitzen keine Entscheidungsautoritaet;
  - Consent-Modi und sichere Defaults sind pro Einstieg definiert;
  - lokale Fehler verwerfen nur den kleinstmoeglichen sicheren Transaktionsumfang;
  - Dokumentausgabe und `edit-file` bleiben atomar;
  - harte Blocker koennen nicht durch normale Patchfreigabe aufgehoben werden.

## Epic B - Gemeinsamer Textkern

### HC-010 - Scope-Modell vereinheitlichen

- Prioritaet: P0
- Aufgabe: Ein kanonisches Modell fuer Prosa und geschuetzte Bereiche implementieren.
- Abnahme:
  - Code, URLs, Linkziele, HTML, Platzhalter, Pfade und Optionen werden erkannt;
  - verschachtelte und ueberlappende Bereiche werden deterministisch aufgeloest;
  - alle bisherigen Schutztests laufen gegen dieselbe Implementierung.

### HC-011 - Markdown-Manifest implementieren

- Prioritaet: P0
- Aufgabe: Konzept aus `AutoSetupTranslateGemma/markdown_structure.py` in den gemeinsamen Kern ueberfuehren und haerten.
- Abhaengigkeiten: HC-010, HC-017
- Abnahme:
  - stabile Segment-IDs;
  - Struktur-Hash vorhanden;
  - Headings, Listen, Zitate, Tabellen, Leerzeilen und Codezaeune getestet;
  - komplexe nicht unterstuetzte Konstruktionen werden erkannt statt still veraendert.

### HC-012 - Rebuilder fail-closed machen

- Prioritaet: P0
- Aufgabe: Nur vollstaendige, bekannte und eindeutige Segmentmengen akzeptieren.
- Abhaengigkeiten: HC-011
- Abnahme:
  - fehlende, unbekannte und doppelte IDs schlagen fehl;
  - Tabellen-Trennzeichen und physische Zeilen bleiben gueltig;
  - keine Teilausgabe wird als Erfolg gespeichert.

### HC-013 - Patch-Engine bauen

- Prioritaet: P0
- Aufgabe: Positionsgebundene, konfliktgepruefte Aenderungen atomar anwenden.
- Abhaengigkeiten: HC-010
- Abnahme:
  - ueberlappende Patches werden abgelehnt oder explizit priorisiert;
  - Originalspanne wird vor Anwendung verifiziert;
  - Dry-run und strukturierter Diff verfuegbar;
  - `proposal_status`, `policy_decision`, `user_decision` und `application_status` werden getrennt gefuehrt;
  - jeder Entscheid besitzt Quellrevision, Entscheidungsautoritaet und maschinenlesbaren Grund;
  - ein Patchstatus wird nie als Qualitaetsstatus wiederverwendet.

### HC-014 - Gemeinsames Befundschema versionieren

- Prioritaet: P0
- Aufgabe: JSON-Schema fuer Befunde, Patches, typisierte Invarianten, Reports und getrennte Statusachsen definieren.
- Abnahme:
  - Schema besitzt Versionsfeld;
  - Span- und Segmentsemantik ist dokumentiert;
  - `workflow_status`, `adapter_status`, `quality_disposition` und `completed_checks` sind getrennte Felder;
  - ein Gesamtstatus ist abgeleitet und nicht unabhaengig setzbar;
  - Invarianten besitzen Typ, Scope, Erwartung, Beobachtung, Vergleichsmethode, Schwere, Entscheid, Evidenz und Quellrevision;
  - Patchschema fuehrt Vorschlag, Policy, Nutzerentscheid und Anwendung als getrennte Achsen;
  - ungueltige Reports werden in Tests abgelehnt.

### HC-015 - Glossar- und Terminologie-Lock

- Prioritaet: P1
- Aufgabe: Pflichtbegriffe, verbotene Varianten und geschuetzte Begriffe pruefen.
- Abhaengigkeiten: HC-010, HC-014
- Abnahme:
  - Gross-/Kleinschreibung und Flexion sind konfigurierbar;
  - Inkonsistenzen ueber mehrere Segmente werden erkannt;
  - Glossare koennen pro Projekt geladen werden.

### HC-016 - Invariant-Verifikation

- Prioritaet: P0
- Aufgabe: Claims, Namen, Zahlen, Zitate, Code, Normen und geschuetzte Tokens vor/nach vergleichen. Fuer strukturelle Eingriffe zusaetzlich ein Segmentmanifest mit kommunikativer Funktion, Kernaussagen, Einschraenkungen, Evidenzankern und Sprecherposition erzeugen.
- Abhaengigkeiten: HC-010, HC-013
- Abnahme:
  - entfernte oder veraenderte harte Anker blockieren die Ausgabe;
  - neue konkrete Anker werden gemeldet;
  - akzeptierte Flexions- und Formatvarianten sind explizit definiert;
  - `structural` und `rebuild` pruefen Vollstaendigkeit, Modalitaet und Sprecherposition gegen das Segmentmanifest;
  - reine Umordnung wird von semantischer Aenderung unterschieden.

### HC-017 - Formatadaptervertrag implementieren

- Prioritaet: P0
- Aufgabe: Gemeinsames Protokoll `detect`, `parse`, `extract_editable_spans`, `protect`, `rebuild`, `verify` implementieren.
- Abhaengigkeiten: HC-006, HC-010, HC-014
- Abnahme:
  - jeder Adapter deklariert bytegleiche oder semantische Rekonstruktionsgarantie;
  - nicht unterstuetzte oder mehrdeutige Konstruktionen schlagen kontrolliert fehl;
  - Formatadapter liefern dasselbe Scope-, Segment- und Revisionsmodell;
  - Eingabeformat und Reportformat sind getrennte Optionen.

### HC-018 - Klartextadapter implementieren

- Prioritaet: P0
- Aufgabe: Referenzadapter fuer Klartext als einfachsten vollstaendigen Formatpfad implementieren.
- Abhaengigkeiten: HC-017
- Abnahme:
  - Zeilenenden, Unicode und abschliessender Zeilenumbruch werden kontrolliert bewahrt;
  - Null-Edit rekonstruiert alle freigegebenen Fixtures bytegleich;
  - Spans und Patches referenzieren die korrekte Dokumentrevision.

### HC-019 - JSON-Adapter implementieren

- Prioritaet: P1
- Aufgabe: Nur explizit ausgewaehlte JSON-Stringwerte ueber wiederholbare JSON-Pointer bearbeiten.
- Abhaengigkeiten: HC-017
- Abnahme:
  - Schluessel, Zahlen, Booleans, `null`, Arrays und Datentypen bleiben erhalten;
  - ohne Auswahl werden keine beliebigen Strings bearbeitet;
  - Schluesselreihenfolge und Formatierung folgen einer dokumentierten Rekonstruktionsgarantie;
  - ungueltige Pointer und Typkonflikte schlagen fehl.

## Epic C - Sprache und Locale

### HC-020 - Sprach- und Locale-Router

- Prioritaet: P0
- Aufgabe: `language`, `locale`, Sicherheit, Konflikte und Code-Switching getrennt modellieren. Sprachgrenzen werden pro Textspanne erfasst.
- Abnahme:
  - explizite Nutzerangabe hat Vorrang;
  - unsicheres Locale loest keine automatische Vollnormalisierung aus;
  - gemischtsprachige Spannen werden als `terminology`, `proper_name`, `intentional_code_switch`, `quotation` oder `suspected_artifact` klassifiziert;
  - bewusstes Code-Switching bleibt standardmaessig erhalten;
  - Normalisierung oder Uebersetzung erfolgt nur fuer explizit freigegebene Spannen;
  - TranslateGemma erhaelt keine zu bewahrenden fremdsprachigen Spannen.

### HC-021 - Locale-Profilformat

- Prioritaet: P0
- Aufgabe: Schema fuer Orthografie, Typografie, Zahlen, Datum, Waehrung, Korrespondenz und regionale Lexik definieren.
- Abhaengigkeiten: HC-020
- Abnahme:
  - Profile sind deklarativ und validierbar;
  - Determinismus und Auto-Apply-Erlaubnis stehen pro Regel fest;
  - Sprachregeln werden nicht im Locale-Profil dupliziert.

### HC-022 - Deutsches Sprachmodul extrahieren

- Prioritaet: P0
- Aufgabe: Deutsche Lexik und Syntax aus dem bisherigen Kern isolieren.
- Abhaengigkeiten: HC-001, HC-010
- Abnahme:
  - keine deutsche Markerlexik im gemeinsamen Kern;
  - bestehende deutsche Baseline bleibt stabil;
  - alte Aufrufe funktionieren ueber Kompatibilitaetsschicht.

### HC-023 - de-CH-Profil

- Prioritaet: P0
- Aufgabe: Schweizer Orthografie, Guillemets, Zahlen, CHF, Korrespondenz und Helvetismen abbilden.
- Abhaengigkeiten: HC-021, HC-022
- Abnahme:
  - U+00DF wird nur in freigegebener Prosa deterministisch normalisiert;
  - Code, URLs, HTML, Linkziele und Platzhalter bleiben unveraendert;
  - Helvetismen im CH-Kontext werden nicht als Fehler markiert.

### HC-024 - de-DE-Profil

- Prioritaet: P1
- Aufgabe: Deutsche Typografie, Zahlen-, Datums- und Korrespondenzkonventionen abbilden.
- Abhaengigkeiten: HC-021, HC-022
- Abnahme:
  - de-CH-Formen werden ohne expliziten Normalisierungsauftrag nur markiert;
  - technische und zitierte Inhalte sind geschuetzt.

### HC-025 - de-AT-Profil

- Prioritaet: P1
- Aufgabe: Oesterreichische Lexik, Typografie und Registerkonventionen abbilden.
- Abhaengigkeiten: HC-021, HC-022
- Abnahme:
  - Austriazismen besitzen False-Positive-Tests;
  - formales Amtsdeutsch wird nicht pauschal geglaettet.

### HC-026 - Englisches Sprachmodul

- Prioritaet: P1
- Aufgabe: Englische KI-Tells, Idiomatik, Register und False Positives implementieren.
- Abhaengigkeiten: HC-010, HC-020
- Abnahme:
  - eigenes Korpus vorhanden;
  - keine Uebersetzung deutscher Pattern Cards ohne sprachliche Validierung;
  - technische und formale Null-Edit-Faelle bestehen.

### HC-027 - en-GB und en-US

- Prioritaet: P1
- Aufgabe: Variantenprofile fuer Orthografie, Datum, Interpunktion und Lexik.
- Abhaengigkeiten: HC-021, HC-026
- Abnahme:
  - Variantenmischung wird erkannt;
  - Contractions werden nicht pauschal erzwungen;
  - neutrales `en` normalisiert keine regionalen Varianten.

### HC-028 - Franzoesisches Sprachmodul und fr-CH

- Prioritaet: P1
- Aufgabe: Franzoesische Pattern Cards, Idiomatik, Register und Schweizer Locale-Regeln.
- Abhaengigkeiten: HC-010, HC-020, HC-021
- Abnahme:
  - `tu`/`vous`, Accord und typografische Abstaende werden kontextuell behandelt;
  - `septante` und `nonante` werden nicht blind erzwungen;
  - CH-Verwaltungsterminologie ist per Glossar pruefbar.

### HC-029 - Italienisches Sprachmodul und it-CH

- Prioritaet: P1
- Aufgabe: Italienische Pattern Cards, Idiomatik, Register und Schweizer Locale-Regeln.
- Abhaengigkeiten: HC-010, HC-020, HC-021
- Abnahme:
  - `tu`/`Lei`, Kongruenz und regionale Terminologie besitzen Tests;
  - explizite Subjektpronomen werden nur im Kontext bewertet;
  - keine blinde regionale Lexikersetzung.

## Epic D - Humanizer

### HC-030 - Humanizer-Router und Arbeitszweige

- Prioritaet: P0
- Aufgabe: `audit`, `rewrite` und `edit-file` mit klaren Seiteneffekten implementieren.
- Abhaengigkeiten: HC-014, HC-020
- Abnahme:
  - Audit veraendert keine Datei;
  - Rewrite liefert nur bestaetigte Patches;
  - Datei-Edit ist atomar und verifiziert.

### HC-031 - Gemeinsame Pattern Cards

- Prioritaet: P1
- Aufgabe: Sprachneutrale Artefakt-, Evidenz-, Struktur- und Persona-Muster extrahieren. Neben verbotenen Erfindungen auch belegte positive Stimmmerkmale schuetzen.
- Abhaengigkeiten: HC-001, HC-022
- Abnahme:
  - jede Karte beschreibt Signal, schlechten Reflex, sicheren Eingriff und Carve-outs;
  - keine sprachspezifische Beispiellexik im gemeinsamen Entscheid;
  - Humor, Ironie, Direktheit, lokale Wendungen, bewusst unperfekte Formulierungen und Code-Switching koennen als zu erhaltende Merkmale erfasst werden;
  - positive Stimmmerkmale werden nur aus ausreichenden Textbelegen oder einem expliziten Profil abgeleitet.

### HC-032 - Rhythmus pro Sprache kalibrieren

- Prioritaet: P1
- Aufgabe: Satzsegmentierung, Metriken und Schwellen sprachspezifisch kalibrieren.
- Abhaengigkeiten: HC-026, HC-028, HC-029
- Abnahme:
  - keine gemeinsame starre Satzlaengenschwelle fuer alle Sprachen;
  - formale Texte besitzen eigene Carve-outs;
  - Metriken bleiben Diagnose und kein Herkunftsnachweis.

### HC-033 - N-Gram-Diagnose

- Prioritaet: P2
- Aufgabe: Zweiwort- und Vierwortueberlappung sowie Aenderungstiefe berichten.
- Abhaengigkeiten: HC-013
- Abnahme:
  - keine automatische Mindestdistanz;
  - Report trennt N-Gram-Abstand von Qualitaet und Semantik;
  - grosse Aenderungstiefe erzeugt nur einen Review-Hinweis.

### HC-034 - Rewrite-Depth-Policy

- Prioritaet: P1
- Aufgabe: Den maximal erlaubten Eingriffsraum mit `minimal`, `local`, `structural` und `rebuild` explizit steuern, ohne daraus eine KI-Herkunftswertung abzuleiten.
- Abhaengigkeiten: HC-013, HC-016, HC-030
- Abnahme:
  - die tatsaechlich verwendete Tiefe darf unter dem erlaubten Maximum bleiben;
  - Null-Edit bleibt in jeder Stufe zulaessig;
  - `structural` darf Absatzreihenfolge und Informationsfluss aendern, muss aber das Segmentmanifest bestehen;
  - `rebuild` wird nur bei ausdruecklicher Freigabe verwendet und uebernimmt ausschliesslich verifizierte Aussagen;
  - kein numerischer KI-Score loest automatisch eine hoehere Eingriffstiefe aus.

### HC-035 - Auslieferungsprofile

- Prioritaet: P1
- Aufgabe: Medium, Zielgruppe und Kommunikationszweck getrennt von Sprache, Locale und Register modellieren.
- Abhaengigkeiten: HC-020, HC-030
- Abnahme:
  - mindestens E-Mail, Chat, Bericht, Social Media, Bewerbung und Marketing sind als deklarative Profile darstellbar;
  - Profile koennen Anrede, Laenge, Absatzstruktur, Abschluss, Direktheit, Formatierung und Handlungsaufforderung steuern;
  - Mediumsmerkmale gelten nicht automatisch als KI-Tells oder universelle Natuerlichkeitsregeln;
  - Bewerbungs- und Marketingprofile duerfen keine unbelegten Eigenschaften oder Claims erzeugen;
  - ein unbekanntes Medium fuehrt zu einem neutralen Profil statt zu einer geratenen Plattformkonvention.

## Epic E - Proofread

### HC-040 - Skill `proofread-ch` anlegen

- Prioritaet: P0
- Aufgabe: Trennscharfe Skillbeschreibung, Modi und Outputvertrag erstellen.
- Abhaengigkeiten: HC-014, HC-020
- Abnahme:
  - automatische Auffindbarkeit verwechselt Proofread nicht mit Humanisierung;
  - `correct` ist Standard;
  - Uebersetzung ist kein impliziter Bestandteil.

### HC-041 - Deterministische Korrekturschicht

- Prioritaet: P0
- Aufgabe: Unicode-, Typografie-, Leerraum- und sichere Locale-Fixes implementieren.
- Abhaengigkeiten: HC-010, HC-021
- Abnahme:
  - jede Auto-Apply-Regel ist einzeln freigegeben;
  - Vorher/Nachher-Invarianten laufen nach jeder Dateioperation;
  - technische Syntax bleibt unangetastet.

### HC-042 - Lokale Grammatik-Engine anbinden

- Prioritaet: P1
- Aufgabe: Versionierte lokale Engine als optionale Kandidatenquelle integrieren.
- Abhaengigkeiten: HC-014, HC-020
- Abnahme:
  - Engine-Version erscheint im Report;
  - Ausfall fuehrt zu kontrollierter Degradation;
  - Markup und geschuetzte Bereiche werden nicht als Prosa gesendet;
  - Regeln und Kategorien sind deaktivierbar.

### HC-043 - Kandidaten-Adjudikation

- Prioritaet: P1
- Aufgabe: Engine-Funde gegen Locale, Glossar, Textsorte und False Positives pruefen.
- Abhaengigkeiten: HC-015, HC-042
- Abnahme:
  - Eigennamen und Fachwoerter werden nicht allein aufgrund eines Woerterbuchfunds ersetzt;
  - jeder verworfene Blocker besitzt einen Grund;
  - Modellurteile duerfen keine neuen Fakten einfuehren.

### HC-044 - Proofread-Recheck

- Prioritaet: P1
- Aufgabe: Nach Aenderungen erneut pruefen und Oszillation verhindern.
- Abhaengigkeiten: HC-013, HC-041, HC-043
- Abnahme:
  - neu eingefuehrte Fehler werden erkannt;
  - wiederholtes Hin-und-her derselben Spanne stoppt mit Warnung;
  - maximal definierte Iterationszahl.

## Epic F - TranslateGemma 27B

### HC-050 - Adapterinterface definieren

- Prioritaet: P0
- Aufgabe: Request-, Response-, Fehler- und Capability-Vertrag festlegen.
- Abhaengigkeiten: HC-014, HC-015
- Abnahme:
  - Adapter ist austauschbar;
  - Modell, Backend und Locale werden explizit uebergeben;
  - deaktivierter Adapter ist ein normaler Zustand;
  - `adapter_status` wird getrennt von Workflow und Qualitaet gemeldet;
  - Request und Response referenzieren Dokumentrevision, Manifestversion und freigegebene Segment-IDs.

### HC-051 - Transformers-27B-Adapter implementieren

- Prioritaet: P1
- Aufgabe: Lokalen TranslateGemma-27B-Pfad anbinden.
- Abhaengigkeiten: HC-050
- Abnahme:
  - offizielles Modelltemplate beziehungsweise kompatibler strukturierter Request;
  - Temperatureinstellung deterministisch;
  - kein Cloud-Fallback;
  - Endpoint und Modell sind konfigurierbar.

### HC-052 - Tokenbasiertes Chunking

- Prioritaet: P1
- Aufgabe: Manifestsegmente mit realem Tokenizer paketieren.
- Abhaengigkeiten: HC-011, HC-051
- Abnahme:
  - kein Split in geschuetzten Bereichen;
  - Sicherheitsreserve konfigurierbar;
  - uebergrosse Einzelknoten werden kontrolliert abgelehnt oder nach dokumentierter Strategie geteilt.

### HC-053 - Adapter-Invarianten

- Prioritaet: P0
- Aufgabe: IDs, Tokens, Glossar, Struktur und Vollstaendigkeit vor Rebuild pruefen.
- Abhaengigkeiten: HC-012, HC-015, HC-051
- Abnahme:
  - jeder definierte Blocker fuehrt zu `rejected`;
  - Anzahl und Form geschuetzter Tokens bleiben erhalten;
  - keine Teiluebersetzung wird als vollstaendig markiert.

### HC-054 - Retry, Timeout und Resume

- Prioritaet: P1
- Aufgabe: Begrenzte Wiederholung und Checkpoints pro Segment implementieren.
- Abhaengigkeiten: HC-051, HC-052, HC-057
- Abnahme:
  - maximal ein normaler Retry je Segment;
  - abgeschlossene Segmente muessen nicht neu uebersetzt werden;
  - Abbruch hinterlaesst keinen scheinbar fertigen Output;
  - Checkpoints verschiedener Dokument- oder Vertragsrevisionen werden nie gemischt.

### HC-055 - Mock-Adapter fuer CI

- Prioritaet: P0
- Aufgabe: Adaptervertrag ohne Modellgewichte testen.
- Abhaengigkeiten: HC-050
- Abnahme:
  - Erfolgs-, Timeout-, Tokenverlust-, ID- und Strukturfehler simulierbar;
  - CI benoetigt kein Modell und keinen Netzwerkzugriff.

### HC-056 - Lokaler End-to-End-Test

- Prioritaet: P1
- Aufgabe: Konfigurierbaren Smoke-Test gegen eine vorhandene 27B-Instanz bereitstellen.
- Abhaengigkeiten: HC-051, HC-053, HC-054
- Abnahme:
  - Test wird ohne konfigurierte Instanz sauber uebersprungen;
  - Testdokument enthaelt Code, Links, Tabellen, Zahlen und Glossarbegriffe;
  - Report dokumentiert Modell und Laufzeit.

### HC-057 - Revisions- und Checkpoint-Identitaet

- Prioritaet: P0
- Aufgabe: Identitaet fuer Dokumentrevisionen, Patches, Adapterrequests und wiederverwendbare Segment-Checkpoints implementieren.
- Abhaengigkeiten: HC-006, HC-011, HC-014, HC-050
- Abnahme:
  - Checkpoint-Schluessel enthaelt Quell-Digest, Dokumentrevision, Manifestversion, Segment-ID, Quell- und Ziel-Locale, Glossar-Digest, Adapter-ID, Modellrevision und Promptvertragsversion;
  - Quell-, Glossar-, Modell- oder Promptaenderungen invalidieren betroffene Checkpoints;
  - Patches koennen nicht auf eine andere Basisrevision angewendet werden;
  - Checkpoints speichern keine unnoetigen Klartextinhalte.

## Epic G - Translation QA

### HC-060 - Source-target Alignment

- Prioritaet: P1
- Aufgabe: Quell- und Zielsegmente zuerst ueber gemeinsame IDs oder explizite Maps und danach ueber ein kontrolliertes strukturelles Fallback ausrichten.
- Abhaengigkeiten: HC-011, HC-064
- Abnahme:
  - fehlende und zusaetzliche Segmente erkannt;
  - Neuordnung ist explizit statt still toleriert;
  - Alignment funktioniert ohne TranslateGemma;
  - `one_to_one`, `one_to_many`, `many_to_one` und unalignierte Einheiten sind darstellbar;
  - unsichere Alignments verhindern keine harten globalen Checks, aber semantische Vollstaendigkeitsaussagen.

### HC-061 - Harte bilinguale Invarianten

- Prioritaet: P1
- Aufgabe: Zahlen, Einheiten, Namen, URLs, Normen, Negationen und Modalitaet vergleichen.
- Abhaengigkeiten: HC-060, HC-016
- Abnahme:
  - definierte Fehlerfaelle werden als Blocker erkannt;
  - locale-bedingte Formatwechsel werden nicht als Claim-Aenderung fehlklassifiziert;
  - Unsicherheit wird markiert statt erfunden aufgeloest.

### HC-062 - Dokumentweite Terminologiekonsistenz

- Prioritaet: P1
- Aufgabe: Quellbegriffe und Zielvarianten ueber alle Segmente pruefen.
- Abhaengigkeiten: HC-015, HC-060
- Abnahme:
  - Pflichtbegriffe und verbotene Varianten erkannt;
  - kontextabhaengige Mehrfachuebersetzungen koennen freigegeben werden;
  - Report zeigt konkrete Segmente.

### HC-063 - Segmentalternative ueber TranslateGemma

- Prioritaet: P2
- Aufgabe: Nur beanstandete Segmente optional neu uebersetzen lassen.
- Abhaengigkeiten: HC-053, HC-061
- Abnahme:
  - Volltext wird nicht unaufgefordert neu uebersetzt;
  - Alternative durchlaeuft alle Invarianten und Proofread-Checks;
  - Original bleibt bis zur erfolgreichen Abnahme erhalten.

### HC-064 - Alignment-Fallback-Vertrag

- Prioritaet: P0
- Aufgabe: Hierarchie, Outputschema, Konfidenz, Abdeckung und Sicherheitsgrenzen fuer externe Quelle-Ziel-Paare ohne gemeinsame IDs definieren.
- Abhaengigkeiten: HC-004
- Ergebnis: `contracts/translation-alignment.md`
- Abnahme:
  - Reihenfolge `shared_id`, `explicit_map`, `structural`, `sentence_fallback` ist normativ;
  - harte Ankerkonflikte verhindern automatische Freigabe;
  - Schwellen und Profilversion invalidieren Caches bei Aenderung;
  - Report weist Abdeckung, Neuordnungen und unalignierte Einheiten aus;
  - Fallback vermeidet eine unbeschraenkte quadratische Vollmatrix.

## Epic H - Qualitaet, Betrieb und Release

### HC-070 - Sprachkorpora und False-Positive-Suites

- Prioritaet: P0
- Aufgabe: Pro Sprache und Locale kuratierte Testfaelle pflegen.
- Abnahme:
  - Positiv-, Negativ-, Formal-, Technik- und Regionalfaelle vorhanden;
  - Korpusprovenienz dokumentiert;
  - Regressionen pro Regel sichtbar;
  - eingefrorene Baseline misst Null-Edit-Stabilitaet, False Positives, Claim-Erhalt und unnoetige Aenderungen;
  - Code-Switching, positive Stimmmerkmale, Rewrite-Tiefe und Auslieferungsprofile besitzen End-to-End-Faelle.

### HC-071 - Performance-Benchmarks

- Prioritaet: P1
- Aufgabe: Kern, Grammatik-Engine und Adapter getrennt messen.
- Abhaengigkeiten: HC-076
- Abnahme:
  - kalte Ladezeit, warme TTFT, Prefill, Decode, End-to-End-Zeit, Peak-Memory, Dokumentgroesse, Pass- und Chunkzahl erfasst;
  - Backend- und Modellwerte werden nicht unzulaessig miteinander vermischt;
  - definierte Warnschwellen statt harter Marketingwerte;
  - ETA und Fortschritt erscheinen bei geschaetzten Laeufen ueber 120 Sekunden;
  - Regressionen gegen ein unveraendertes Profil werden ausgewiesen.

### HC-072 - Datenschutz und Logs

- Prioritaet: P1
- Aufgabe: Logs ohne Textinhalte und sichere lokale Defaults definieren.
- Abnahme:
  - keine Textsegmente, Prompts oder Glossare in Standardlogs;
  - Loopback als Adapterdefault;
  - Remote-Endpoint erfordert explizite Konfiguration.

### HC-073 - Packaging und Installation

- Prioritaet: P1
- Aufgabe: Skills, gemeinsame Ressourcen und optionale Abhaengigkeiten paketieren.
- Abhaengigkeiten: HC-004, HC-005
- Abnahme:
  - Kerninstallation ohne TranslateGemma und schwere NLP-Modelle moeglich;
  - optionale Komponenten werden diagnostiziert;
  - Bundle enthaelt keine Platzhalter oder Entwicklungsartefakte.

### HC-074 - Verhaltens-Evaluation

- Prioritaet: P1
- Aufgabe: Realistische End-to-End-Anfragen unabhaengig pruefen.
- Abhaengigkeiten: HC-004, HC-005, HC-030, HC-040, HC-056, HC-061
- Abnahme:
  - Humanizer-, Proofread- und Translation-QA-Aufgaben getrennt evaluiert;
  - Null-Edit, technische Texte und regionale Varianten enthalten;
  - beobachtete Fehler fuehren nur zu gezielten Regelkorrekturen.

### HC-075 - Version-1.0-Release-Gate

- Prioritaet: P0
- Aufgabe: Alle Spezifikationskriterien und bekannten Blocker pruefen.
- Abhaengigkeiten: alle fuer Version 1.0 markierten P0/P1-Tickets
- Abnahme:
  - keine offenen P0-Defekte;
  - bekannte P1-Abweichungen explizit akzeptiert oder behoben;
  - Installations-, Integritaets- und Regressionstests erfolgreich;
  - Supportmatrix und Migrationshinweise vollstaendig;
  - alle freigegebenen Klartext-, Markdown- und JSON-Fixtures bestehen ihre deklarierte Rekonstruktionsgarantie;
  - kein freigegebenes Ergebnis enthaelt einen offenen Invariant-Blocker;
  - Null-Edit-, False-Positive- und bestehende `humanizer-de`-Baseline sind nicht verschlechtert;
  - jede neue Auto-Apply-Regel besteht alle Positiv- und False-Positive-Faelle ihrer freigegebenen Regelklasse.

### HC-076 - Pass-, Latenz- und Hardwarevertrag

- Prioritaet: P0
- Aufgabe: Modellpassgrenzen, Benchmarkgroessen, Kernlatenzbudgets, Hardwareprofil, Kontextbudget und Betriebsregeln festlegen.
- Abhaengigkeiten: HC-004, HC-005
- Ergebnis: `contracts/performance-budget.md`
- Abnahme:
  - jeder Modus besitzt ein Standard-Passbudget;
  - Kern-P95 ist fuer kleine, mittlere und grosse Dokumente definiert;
  - kalte und warme Modellwerte werden getrennt;
  - Adapter pruefen Speicher und Kontextlimit vor langen Laeufen;
  - persistenter Modelldienst, Caching, ETA, Fortschritt und Abbruch sind festgelegt;
  - Performance-Gates trennen Backend, Modellrevision und Quantisierung.

## Architektur-Gate vor der ersten Implementierungsiteration

1. HC-001 Bestand inventarisieren
2. HC-002 Baseline-Korpus einfrieren
3. HC-003 Kompatibilitaetsvertrag definieren
4. HC-004 Plugin- und Paketarchitektur festlegen
5. HC-005 Befehls- und Aufgabenverantwortung festlegen
6. HC-007 Agent-Core- und Rewrite-Proposal-Vertrag
7. HC-008 Patch-Autoritaet und Transaktionsumfang
8. HC-064 Alignment-Fallback-Vertrag
9. HC-076 Pass-, Latenz- und Hardwarevertrag
10. HC-006 Architektur-Gate freigeben

HC-001 und HC-002 duerfen sofort beginnen. Produktiver Implementierungscode startet erst nach HC-006.

## Vorgeschlagene erste Implementierungsiteration

1. Paketgeruest fuer Plugin, Skills und gemeinsamen Kern aus HC-004
2. HC-014 Befund-, Invarianten-, Patch- und Statusschema versionieren
3. HC-010 Scope-Modell vereinheitlichen
4. HC-017 Formatadaptervertrag implementieren
5. HC-018 Klartextadapter implementieren
6. HC-011 Markdown-Manifest implementieren
7. HC-013 Patch-Engine bauen
8. HC-012 Rebuilder fail-closed machen
9. HC-016 Invariant-Verifikation und Bedeutungsmanifest
10. HC-020 Sprach-, Locale- und Code-Switch-Router
11. HC-022 Deutsches Sprachmodul extrahieren
12. HC-023 de-CH-Profil

HC-019 fuer JSON folgt nach dem validierten Referenz- und Markdownpfad. HC-034 und HC-035 bauen auf dem stabilen Humanizer-Router auf. TranslateGemma-Arbeit beginnt erst nach dem stabilen Kern mit HC-050, HC-055 und HC-057. Dadurch wird der Adaptervertrag ohne Modellgewichte testbar und Checkpoint-Wiederverwendung bleibt revisionssicher.
