# Humanizer CH - Roadmap

Status: Planungsentwurf 0.5
Planungsprinzip: Jede Phase liefert einen nutzbaren, verifizierbaren Stand. Sprachbreite wird erst nach stabilem Kern erweitert.

## Zielbild

Das Plugin `humanizer-ch` enthaelt die getrennten Skills `humanizer-ch` und `proofread-ch`, den gemeinsamen Python-Kern `humanizer_ch_core` sowie den optionalen CLI-Einstieg `translate-ch`. TranslateGemma 27B ist ein austauschbarer Adapter dieses Kerns. Humanisierung und Proofreading bleiben lokal und ohne Uebersetzungsadapter funktionsfaehig.

## Phase 0 - Baseline und Architektur-Gate

Ziel: Bestehendes `humanizer-de` reproduzierbar erfassen und alle bindenden Produkt-, Paket- und Datenvertraege vor der Implementierung festlegen.

Lieferumfang:

- aktuelle Muster, Linter, Tests und CLI-Vertraege inventarisieren;
- reproduzierbaren Baseline-Import aus dem bestehenden `humanizer-de` mit Quelle, Version, Lizenz, Dateidigest und Migrationsentscheid erzeugen;
- bestehende 72 Muster nach `core`, `language:de` und `locale` klassifizieren;
- Kompatibilitaetsvertrag fuer bestehende Muster-IDs und Aufrufe definieren;
- repräsentative Baseline-Korpora und aktuelle False-Positive-Raten einfrieren;
- Lizenz- und Herkunftsnachweise fuer uebernommene Dateien dokumentieren.
- Plugin-, Skill-, Python-Paket- und optionale Abhaengigkeitsgrenzen als Architecture Decision Record festlegen;
- Befehlsverantwortung fuer `humanizer-ch`, `proofread-ch` und `translate-ch` festlegen;
- Workflow-, Adapter- und Qualitaetsstatus als getrennte Achsen versionieren;
- typisierte Invarianten, Patch-Entscheidungen und Dokumentrevisionen spezifizieren;
- vollstaendigen Checkpoint-Schluessel fuer wiederaufnehmbare Arbeit definieren;
- Formatadaptervertrag fuer Klartext, Markdown und JSON spezifizieren;
- Agent-Core- und Rewrite-Proposal-Vertrag versionieren;
- Patch-Autoritaet, Consent-Modi und Transaktionsumfang versionieren;
- Alignment-Fallback fuer externe Quelle-Ziel-Paare versionieren;
- Pass-, Latenz- und Hardwarebudgets versionieren;
- Modellrollen, Standardprofile, Effortgrenzen und Eskalationsketten versionieren;
- Auswahlvertrag fuer einzelne Textbausteine und das Review-Profil `critical_text` versionieren;
- Konfigurationsprioritaet, Capability-Erkennung und sichere Defaults versionieren;
- gemeinsame Fehlerklassen, Exit Codes, Wiederholbarkeit und Degradationspfade versionieren;
- messbare Baseline-, Qualitaets- und Release-Gates einfrieren.
- Zielstruktur fuer zwei kurze Produkt-Skills sowie einen nicht ausgelieferten Maintainer-Skill festlegen;
- kanonische Reihenfolge und Ergebnisformat des gemeinsamen Test-Harness festlegen.

Exit-Kriterien:

- alle bestehenden Tests laufen unveraendert;
- jede bestehende Regel besitzt eine Zielklasse und einen Migrationsentscheid;
- keine offene Entscheidung blockiert die Kernarchitektur;
- `humanizer-ch` besitzt keinen Uebersetzungs-Unterbefehl;
- Status-, Invarianten-, Patch-, Revisions-, Checkpoint- und Formatvertraege sind versioniert;
- Konfigurations- und Fehlervertraege sind versioniert und besitzen keine widerspruechlichen Defaults zwischen Skill, CLI und Kern;
- alle normativen Vertraege sind widerspruchsfrei in Spezifikation und Backlog verlinkt;
- die erste Implementierungsiteration ist gegen diese Vertraege auf Abhaengigkeiten geprueft.
- der Baseline-Import ist aus dem Workspace reproduzierbar und benoetigt keine still veraenderliche installierte Skill-Kopie.

## Phase 1 - Gemeinsamer Textkern

Ziel: Struktur, Schutzbereiche und Aenderungsverifikation aus der Sprachlogik herausloesen.

Lieferumfang:

- einheitliches Scope-Modell fuer Prosa, Code, URLs, HTML, Zitate und Platzhalter;
- gemeinsames Formatadapterprotokoll `detect`, `parse`, `extract_editable_spans`, `protect`, `rebuild`, `verify`;
- Klartext-Referenzadapter;
- Markdown-Manifest mit stabilen Segment-IDs;
- JSON-Adapter mit expliziter Auswahl von Stringwerten ueber JSON-Pointer;
- deterministischer Rebuilder mit Vollstaendigkeitspruefung;
- gemeinsamer Glossar- und Terminologie-Lock;
- Patch-Engine mit atomarer Ausgabe;
- Agent-Core-Orchestrierung mit gebatchten, positionsgebundenen Rewrite-Vorschlaegen;
- getrennte Zustandsachsen fuer Vorschlag, Policy, Nutzerentscheid und Anwendung;
- versioniertes JSON-Schema fuer Befunde, typisierte Invarianten, Patch-Entscheidungen, Statusachsen und Reports.
- Pruefbereiche `document`, `selection` und `segments` mit revisionsgebundenen Spans und nicht editierbarem Kontext;
- kanonischer lokaler und CI-faehiger Test-Harness fuer Contracts, Unit-Tests, Korpora und Skill-Struktur;

Exit-Kriterien:

- Klartext-, Markdown- und JSON-Fixtures werden ohne Textaenderung gemaess deklarierter Garantie bytegleich oder semantisch gleich rekonstruiert;
- fehlende, doppelte und unbekannte IDs werden abgelehnt;
- geschuetzte Tokens bleiben in allen Testfaellen unveraendert;
- Kernmodule enthalten keine deutsche Lexik.
- Kernlatenz und Modellpasszahl halten die freigegebenen Budgets ein.
- direkte Textbausteine und ausgewaehlte Datei-Spans koennen ohne Volltextlauf geprueft werden; dokumentweite Checks erscheinen dabei als `not_run`.
- derselbe Harness liefert lokal und in CI dasselbe maschinenlesbare Ergebnis fuer deterministische Tests.

## Phase 2 - Deutscher Sprachkern und DACH-Locales

Ziel: Bestehende Deutschqualitaet erhalten und regional korrekt aufteilen.

Lieferumfang:

- `de`-Sprachmodul aus `german_pattern_lint` und relevanten Pattern Cards;
- Locale-Profile `de-CH`, `de-DE`, `de-AT`;
- segmentweiser Sprach- und Code-Switch-Router;
- positive Persona-Locks fuer belegten Humor, Ironie, Direktheit, lokale Wendungen und bewusste Unregelmaessigkeiten;
- Rewrite-Tiefen `minimal`, `local`, `structural` und `rebuild`;
- deklarative Auslieferungsprofile fuer Medium, Zielgruppe und Kommunikationszweck;
- Review-Profil `critical_text` fuer strenge Audits einzelner Textbausteine ohne automatische Rewrite-Eskalation;
- Schweizer Orthografie und Typografie als sichere Locale-Transformation;
- DACH-False-Positive-Korpus fuer Helvetismen, Austriazismen und deutsche Varianten;
- CLI mit explizitem `--language` und `--locale`;
- Kompatibilitaetsschicht fuer bisherige `humanizer-de`-Aufrufe.

Exit-Kriterien:

- bestehende deutsche Baseline bleibt mindestens gleich gut;
- ein de-CH-Text wird nicht auf de-DE normalisiert und umgekehrt;
- Locale-Mehrdeutigkeit fuehrt ohne Nutzerauftrag zu keiner Vollkonvertierung;
- formale, technische und juristische Null-Edit-Faelle bleiben stabil.
- bewusstes Code-Switching bleibt erhalten und nur bestaetigte Artefakte werden normalisiert;
- `structural` und `rebuild` bestehen das Bedeutungsmanifest;
- ein unbekanntes Medium verwendet das neutrale Auslieferungsprofil.
- `critical_text` liefert bei guten Texten ein gueltiges Null-Edit und behauptet keine dokumentweite Abdeckung.

## Phase 3 - Proofread CH Minimum Viable Product

Ziel: Fehlerkorrektur fachlich von Humanisierung trennen.

Lieferumfang:

- eigener Skill `proofread-ch`;
- mit dem Skill-Creator erzeugte kurze Einstiege fuer `humanizer-ch` und `proofread-ch` mit progressiv geladenen Referenzen und konsistenten UI-Metadaten;
- Modi `correct` und `edit`;
- lokale Grammatik-Engine als optionale Kandidatenquelle;
- deterministische Typografie- und Locale-Pruefungen;
- Befundfilter fuer Code, Zitate, Eigennamen und Glossarbegriffe;
- erneute Pruefung und Invariant-Check nach jeder Dateiaenderung.

Exit-Kriterien:

- `correct` veraendert keine stilistisch bloss alternativen Formulierungen;
- Grammatik-Engine-Ausfall degradiert kontrolliert auf Kernregeln;
- jede automatische Aenderung ist einer freigegebenen sicheren Regelklasse zugeordnet;
- Nutzer koennen Regeln oder Kategorien deaktivieren.
- beide Skill-Einstiege bestehen Struktur-, Trigger- und Nicht-Trigger-Tests und duplizieren keine gemeinsame Sprach- oder Kernlogik.

## Phase 4 - Englisches Sprachmodul

Ziel: Humanisierung und Proofreading fuer Englisch mit Variantenkontrolle.

Lieferumfang:

- Pattern Cards und Linter fuer Englisch;
- Profile `en-GB`, `en-US` und neutrales `en`;
- US-/UK-Mischpruefung ohne automatische Vollkonvertierung bei unklarem Locale;
- englische Register-, Idiomatik- und False-Positive-Korpora;
- Cross-Language-Transferregeln `en -> de` und `de -> en`.

Exit-Kriterien:

- formales und technisches Englisch wird nicht kuenstlich informell gemacht;
- Contractions werden nicht pauschal erzwungen;
- US- und UK-Konventionen bleiben jeweils konsistent;
- Transferbefunde brauchen Kontext oder Cluster, nicht nur einzelne Lehnwoerter.

## Phase 5 - TranslateGemma-27B-Adapter

Ziel: Lokale, optionale Uebersetzung mit denselben Struktur- und Schutzgarantien anbinden.

Lieferumfang:

- Adapterinterface und Konfigurationsschema;
- Unterstuetzung fuer lokalen Transformers-27B-Pfad;
- tokenbasiertes Chunking und wiederaufnehmbare Segmentverarbeitung;
- Manifest-basierte Ein- und Ausgabe;
- Glossarbindung und Protected-Token-Checks;
- strukturierte Fehler und deaktivierter Standardzustand;
- End-to-End-Test gegen eine konfigurierbare lokale Testinstanz;
- Mock-Adapter fuer CI ohne Modellgewicht.
- eigener optionaler CLI-Einstieg `translate-ch`;
- Checkpoints mit Quell-Digest, Dokumentrevision, Manifestversion, Segment-ID, Locales, Glossar-Digest, Adapter-ID, Modellrevision und Promptvertragsversion.

Exit-Kriterien:

- Kernfunktionen laufen bei deaktiviertem oder nicht erreichbarem Adapter weiter;
- kein unbekanntes, fehlendes oder dupliziertes Segment wird akzeptiert;
- Ausgabe wird bei Struktur- oder Terminologieblockern verworfen;
- Adapter fuehrt keinen stillen Cloud-Fallback aus;
- Modell und Backend erscheinen im Ergebnisreport.
- Checkpoints verschiedener Dokument- oder Vertragsrevisionen werden nie gemischt.

## Phase 6 - Translation QA

Ziel: Bilinguale Qualitaetspruefung auf Basis ausgerichteter Segmente.

Lieferumfang:

- Modus `translation-qa`;
- source-target Mapping ueber Manifest-IDs;
- explizite Mapping-Dateien und strukturelles Fallback fuer externe Dokumentpaare;
- Regeln fuer Zahlen, Einheiten, Namen, Negationen, Modalitaet und Auslassungen;
- Terminologiekonsistenz ueber das ganze Dokument;
- TranslateGemma-Alternativen nur fuer beanstandete Segmente;
- getrennte Statusachsen `workflow_status`, `adapter_status`, `quality_disposition` und `completed_checks`.

Exit-Kriterien:

- definierte Auslassungs-, Zusatz-, Zahlen- und Negationsfehler werden erkannt;
- alternative Modellvorschlaege werden nie ungeprueft uebernommen;
- Translation QA funktioniert auch ohne TranslateGemma mit eingeschraenktem Funktionsumfang.
- ein Adapterfehler kann den Workflowstatus oder Qualitaetsentscheid nicht still ueberschreiben.
- unsichere Alignments werden als reviewpflichtig oder unaligniert ausgewiesen und nie still akzeptiert.

## Phase 7 - Franzoesisch und Italienisch fuer die Schweiz

Ziel: `fr-CH` und `it-CH` als eigenstaendige Sprach- und Locale-Kombinationen liefern.

Lieferumfang:

- Sprachmodule `fr` und `it`;
- Locale-Profile `fr-CH` und `it-CH`;
- Anrede-, Register-, Typografie- und Idiomatikregeln;
- Transferregeln aus Englisch und Deutsch;
- kuratierte Positiv- und False-Positive-Korpora;
- Glossare fuer haeufige Schweizer Verwaltungs- und Wirtschaftsterminologie.

Exit-Kriterien:

- regionale Varianten werden nicht blind ersetzt;
- formale Schweizer Texte bestehen Null-Edit- und Terminologietests;
- jede automatische Locale-Korrektur ist deterministisch und getestet;
- muttersprachliche Review-Stichprobe ohne offene Blocker.

## Phase 8 - Produktionshaertung und Version 1.0

Ziel: Reproduzierbarer, wartbarer Betrieb fuer reale Dokumente.

Lieferumfang:

- Performance- und Speichertests;
- getrennte Messung von kaltem Start, warmem TTFT, Prefill, Decode und End-to-End-Dokumentzeit;
- Resume und Checkpoints fuer lange Dokumente;
- Fehlertelemetrie ohne Textinhalte;
- Migrationsleitfaden von `humanizer-de`;
- dokumentierte Supportmatrix fuer Formate, Sprachen, Locales und Adapter;
- Release-Bundle und Installationspruefung;
- unabhaengige Verhaltens-Evaluation mit realistischen Aufgaben.
- A/B-Evaluation der Rollen- und Effortprofile einschliesslich starkem Modell mit niedrigem Effort gegen guenstiges Modell mit hohem Effort;
- repository-lokaler Maintainer-Skill fuer wiederholbare Inventur-, Eval-, Bundle- und Releaseablaeufe;
- messbare Release-Matrix fuer Rekonstruktion, harte Invarianten, Baseline-Regressionsfreiheit, Auto-Apply-Regeln und P0/P1-Defekte.

Exit-Kriterien:

- alle Abnahmekriterien der Spezifikation sind erfuellt;
- keine bekannten Datenverlust- oder Strukturblocker;
- dokumentierte Degradationspfade fuer fehlende optionale Abhaengigkeiten;
- Release-Artefakt besteht Struktur- und Integritaetspruefung.
- alle freigegebenen Format-Fixtures bestehen ihre deklarierte Rekonstruktionsgarantie;
- kein freigegebenes Ergebnis enthaelt offene Invariant-Blocker;
- Null-Edit-, False-Positive- und `humanizer-de`-Baseline sind nicht verschlechtert;
- keine offenen P0-Defekte und nur explizit akzeptierte P1-Abweichungen.
- das freigegebene Routingprofil erfuellt harte Invarianten und den dokumentierten Trade-off aus Qualitaet, Latenz und Kosten.
- der Maintainer-Skill ist explizit aufzurufen, verweist auf den kanonischen Harness und fehlt im ausgelieferten Nutzer-Bundle.

## Spaetere Optionen

- `fr-FR` und `it-IT`
- HTML-AST und kommentartreues YAML
- Translation Memory
- kundenspezifische Styleguides
- inkrementelle Glossarvorschlaege mit expliziter Freigabe
- weitere lokale Uebersetzungsadapter hinter demselben Vertrag

Diese Optionen sind nicht Teil von Version 1.0, solange Kernqualitaet und False-Positive-Kontrolle nicht stabil sind.
