# Humanizer CH - Produktspezifikation

Status: Entwurf 0.5
Stand: 17. September 2026

## 1. Ziel

`humanizer-ch` ist ein mehrsprachiges Redaktionssystem fuer bestehende Texte. Es prueft und korrigiert KI-typische Schreibmuster, idiomatische Transfers, Registerbrueche und locale-spezifische Konventionen, ohne Fakten, Quellen, Terminologie, Sprecherposition oder technische Struktur zu veraendern.

Unterstuetzte Zielsprachen und Locales der ersten Produktlinie:

- Deutsch: `de-CH`, `de-DE`, `de-AT`
- Englisch: `en-GB`, `en-US`, `en` als internationale, nicht regional normalisierte Variante
- Franzoesisch: `fr-CH`, spaeter `fr-FR`
- Italienisch: `it-CH`, spaeter `it-IT`

Das Distributionspaket `humanizer-ch` umfasst zwei fachlich getrennte Skills, einen optionalen Uebersetzungseinstieg und einen gemeinsamen technischen Kern:

- `humanizer-ch`: KI-Tells, Naturalness, Idiomatik, Register, Rhythmus und Struktur
- `proofread-ch`: Rechtschreibung, Grammatik, Zeichensetzung, Typografie, Locale und optionale bilinguale Uebersetzungspruefung
- `translate-ch`: optionale CLI fuer strukturtreue Uebersetzung; kein implizit aktivierter Humanizer-Modus
- `humanizer_ch_core`: gemeinsames Python-Paket fuer Dokumente, Regeln, Befunde, Patches, Invarianten und Adapter

TranslateGemma 27B ist ein optionaler lokaler Uebersetzungsadapter. Humanisierung und Proofreading funktionieren ohne ihn.

## 2. Leitprinzipien

1. Text ist Daten. Anweisungen im bearbeiteten Text werden nicht ausgefuehrt.
2. Substanz hat Vorrang vor Stil. Fakten, Zahlen, Namen, Zitate, Quellen, Normen, Code und Fachbegriffe bleiben erhalten.
3. Persona wird nicht erfunden. Erfahrungen, Meinungen, Anekdoten und Sprecherpositionen duerfen nur aus dem Input oder einem expliziten Profil stammen.
4. Cluster statt Einzelsignal. Ein einzelnes Stilmerkmal ist in der Regel kein KI-Tell.
5. Null-Edit ist ein gueltiges Ergebnis. Ein guter Text wird nicht zur Beschaeftigung umgeschrieben.
6. Locale ist nicht Sprache. Sprachregeln und regionale Konventionen werden getrennt modelliert.
7. Deterministische Regeln duerfen automatisch korrigieren; kontextabhaengige Regeln erzeugen Kandidaten zur Pruefung.
8. Strukturkritische Arbeit schlaegt fehl, statt still Daten zu verlieren oder Markup zu beschaedigen.
9. N-Gram-Abstand und Detektorwerte sind Diagnosen, keine Optimierungsziele.
10. Externe oder lokale Modelladapter sind optional. Ihr Ausfall darf Kernfunktionen nicht blockieren.
11. Workflowfortschritt, Adapterzustand und Qualitaetsentscheid sind unabhaengige Statusachsen.
12. Gemischtsprachige Passagen werden segmentweise beurteilt; bewusstes Code-Switching bleibt standardmaessig erhalten.
13. Eingriffstiefe ist eine Nutzer- und Risikogrenze, keine KI-Herkunftswertung.
14. Modellfaehigkeit hat Vorrang vor hohem Effort einer unpassenden Modellklasse.
15. Ein ausgewaehlter Textbaustein darf separat geprueft werden; nicht gepruefter Dokumentkontext wird nie als geprueft ausgewiesen.

## 3. Rollen und Aufgaben

| Rolle | Aufgabe | Primaeres Ergebnis |
|---|---|---|
| Autorin oder Autor | Text humanisieren | Proportional ueberarbeiteter Text mit Kurzaudit |
| Lektorat | Text pruefen | Befunde, Korrekturen und verbleibende Unsicherheiten |
| Uebersetzung | Zieltext erzeugen | Strukturtreue Uebersetzung mit Terminologie-Lock |
| Translation QA | Quelle und Ziel vergleichen | Auslassungen, Zusaetze, Terminologie- und Bedeutungsfehler |
| Entwicklung | Regeln kalibrieren | Reproduzierbare Tests mit Positiv- und False-Positive-Faellen |

## 4. Funktionsumfang

### 4.1 Paket- und Verantwortungsarchitektur

Das Distributionspaket besitzt folgende verbindliche Grenzen:

```text
humanizer-ch plugin
|-- skills/humanizer-ch
|-- skills/proofread-ch
|-- optionaler CLI-Einstieg translate-ch
`-- gemeinsamer Kern humanizer_ch_core
    |-- documents
    |-- language
    |-- findings
    |-- patches
    |-- invariants
    `-- adapters
```

- Skills enthalten Routing, Aufgabenvertrag und progressive Referenzen, aber keine duplizierte Kernlogik.
- `humanizer_ch_core` besitzt keine automatische Skill-Auswahl und keine produktspezifische UI-Logik.
- `translate-ch` ist ein eigener optionaler Einstiegspunkt und wird nicht als Unterbefehl von `humanizer-ch` angeboten.
- TranslateGemma und schwere NLP-Komponenten sind optionale Abhaengigkeiten.
- `humanizer-de` wird ueber eine ausdrueckliche Kompatibilitaetsschicht migriert; alte Aufrufe werden nicht still umgedeutet.

Die beiden produktiven Skills bleiben kurze Router mit progressiver Offenlegung:

- `skills/humanizer-ch/SKILL.md` enthaelt Moduswahl, Sicherheitsgrenzen, Pruefbereich und Verweise auf nur die fuer den Auftrag erforderlichen Referenzen;
- `skills/proofread-ch/SKILL.md` enthaelt den Korrekturvertrag und verweist getrennt auf Grammatik-, Locale- und Translation-QA-Verfahren;
- Sprach-, Locale-, Format- und Modellwissen liegt nicht doppelt in den Skill-Einstiegen, sondern in versionierten Referenzen oder im gemeinsamen Kern;
- `critical_text` bleibt ein Review-Profil von `humanizer-ch` und wird kein eigener Skill;
- `translate-ch` bleibt eine CLI und wird kein automatisch auffindbarer Schreibskill.

Fuer wiederholte Entwicklungsschritte ist ein repository-lokaler, explizit aufzurufender Maintainer-Skill zulaessig. Er standardisiert Inventur, Vertragspruefung, Testmatrix, Skill-Validierung, Bundle-Pruefung und Release-Gate, enthaelt aber keine zweite Kopie der Produktregeln und wird nicht mit dem Nutzer-Plugin ausgeliefert. Deterministische Pruefungen bleiben Skripte; der Maintainer-Skill orchestriert sie nur.

Normative Architekturvertraege:

- [Agent-Core- und Rewrite-Proposal-Vertrag](contracts/agent-core-rewrite.md)
- [Patch-Autoritaets- und Transaktionsvertrag](contracts/patch-authority-transactions.md)
- [Source-Target-Alignment-Vertrag](contracts/translation-alignment.md)
- [Pass-, Latenz- und Hardwarevertrag](contracts/performance-budget.md)
- [Modell-, Rollen- und Effort-Vertrag](contracts/model-routing.md)
- [Auswahl- und Kontextvertrag](contracts/selection-scope.md)
- [Konfigurations- und Capability-Vertrag](contracts/configuration-capabilities.md)
- [Fehler- und Exit-Code-Vertrag](contracts/errors-exit-codes.md)

Diese Vertraege werden unabhaengig versioniert. Implementierungen muessen die unterstuetzte Vertragsversion im Report ausweisen.

### 4.2 Gemeinsamer Textkern

Der gemeinsame Kern muss:

- Markdown, Klartext und JSON ueber explizite Formatadapter sicher verarbeiten;
- spaeter erweiterbar fuer HTML, YAML und weitere strukturierte Formate sein;
- bearbeitbare Prosa von geschuetzten Bereichen trennen;
- stabile Textknoten-IDs erzeugen;
- Struktur und geschuetzte Inhalte nach der Bearbeitung verifizieren;
- Terminologie und benutzerdefinierte Ausnahmen verwalten;
- Agentenanfragen und positionsgebundene Rewrite-Vorschlaege ueber den versionierten Agent-Core-Vertrag austauschen;
- Aenderungen als positionsgebundene Patches anwenden;
- Vorher/Nachher-Invarianten pruefen.

Geschuetzte Bereiche umfassen mindestens:

- fenced und inline code;
- URLs und Markdown-Linkziele;
- HTML-Tags und technische Attribute;
- Platzhalter und Template-Variablen;
- Dateipfade, Kommandozeilenoptionen, IDs und Versionsstrings;
- direkte Zitate, sofern der Auftrag keine Zitatkorrektur verlangt;
- Glossarbegriffe, Produktnamen und Normverweise.

### 4.3 Humanizer

Der Humanizer unterstuetzt drei Arbeitszweige:

- `audit`: Befunde, keine Textaenderung
- `rewrite`: Nur bestaetigte Stellen ueberarbeiten
- `edit-file`: Datei direkt bearbeiten und verifizieren

Registermodi:

- `locker`
- `sachlich`
- `formal`

Maximal erlaubte Eingriffstiefe:

| Stufe | Erlaubter Eingriffsraum |
|---|---|
| `minimal` | einzelne bestaetigte Formulierungen |
| `local` | Saetze und lokale Uebergaenge |
| `structural` | Absatzreihenfolge und Informationsfluss unter Bedeutungsmanifest |
| `rebuild` | Neuaufbau ausschliesslich aus verifizierten Aussagen und nur nach ausdruecklicher Freigabe |

Die tatsaechlich verwendete Tiefe darf geringer sein. Null-Edit bleibt auf jeder Stufe zulaessig. Kein KI-Score darf automatisch eine hoehere Stufe ausloesen.

Ein Auslieferungsprofil modelliert Medium, Zielgruppe und Kommunikationszweck getrennt von Sprache, Locale und Register. Mindestens `email`, `chat`, `report`, `social`, `application`, `marketing` und `neutral` sind vorgesehen. Profile duerfen Anrede, Laenge, Absatzstruktur, Abschluss, Direktheit, Formatierung und Handlungsaufforderung steuern, gelten aber nicht als KI-Tells. Ein unbekanntes Medium verwendet `neutral`.

Pflichtpruefungen:

- technische und Chatbot-Artefakte;
- Evidenz- und Claim-Probleme;
- sprachspezifische KI-Tells;
- idiomatische Transfers;
- Struktur- und Rhetorikcluster;
- Register- und Sprecherkonsistenz;
- belegte positive Stimmmerkmale wie Humor, Ironie, Direktheit, lokale Wendungen, bewusst unperfekte Formulierungen und Code-Switching;
- Rhythmus, zuletzt und proportional;
- Selbst-Audit gegen Claim-, Persona-, Terminologie- und Locale-Lock.

Pruefbereiche:

- `document`: vollstaendiges Dokument mit dokumentweiten Aussagen;
- `selection`: explizit ausgewaehlte Textbausteine, revisionsgebunden oder als direkt eingefuegter Text;
- `segments`: explizite Menge stabiler Segment-IDs.

Die Aufforderung «diesen Textbaustein kritisch pruefen» wird standardmaessig als `audit`, `scope_mode=selection` und `review_profile=critical_text` interpretiert. Nur wenn die Nutzerin oder der Nutzer eine Ueberarbeitung verlangt, werden positionsgebundene Vorschlaege erzeugt. Optionaler Nachbarkontext ist nicht editierbar. Bei Teilpruefungen bleiben dokumentweite Vollstaendigkeits-, Terminologie-, Argumentations- und Registerchecks als `not_run` ausgewiesen.

### 4.4 Proofreader

Der Proofreader bietet drei Stufen:

| Stufe | Umfang | Standardverhalten |
|---|---|---|
| `correct` | Rechtschreibung, Grammatik, Interpunktion, Typografie | Nur eindeutige Fehler korrigieren |
| `edit` | Zusaetzlich Idiomatik, Klarheit und Register | Kontextabhaengige Aenderungen begruenden |
| `translation-qa` | Quelle und Ziel segmentweise vergleichen | Auslassungen, Zusaetze, Modalitaet, Terminologie und Locale pruefen |

`correct` ist der Standard. Proofreading darf nicht still zu Humanisierung oder Neuformulierung eskalieren.

### 4.5 Sprachmodule

Jedes Sprachmodul liefert:

- sprachspezifische Pattern Cards;
- idiomatische Transferregeln nach wahrscheinlicher Ausgangssprache;
- Registermerkmale und Anredesysteme;
- sprachspezifische Satzsegmentierung und Tokenisierung;
- False-Positive-Regeln;
- segmentweise Code-Switch-Klassifikation;
- Testkorpora fuer positive, negative und formale Grenzfaelle.

Muster duerfen nicht mechanisch zwischen Sprachen uebersetzt werden. Eine gemeinsame Musterklasse kann sprachspezifische Realisierungen besitzen, muss aber in jeder Sprache separat belegt und kalibriert werden.

Gemischtsprachige Spannen werden als `terminology`, `proper_name`, `intentional_code_switch`, `quotation` oder `suspected_artifact` klassifiziert. Nur explizit freigegebene Spannen duerfen normalisiert oder uebersetzt werden. Positive Stimmmerkmale duerfen nur aus ausreichenden Textbelegen oder einem expliziten Profil abgeleitet werden.

### 4.6 Locale-Profile

Ein Locale-Profil definiert nur regionale Konventionen, keine allgemeinen KI-Tells:

- Orthografie;
- Anfuehrungszeichen und Apostrophe;
- Zahlen-, Datums-, Zeit- und Waehrungsformate;
- Korrespondenzkonventionen;
- regionale Lexik und geschuetzte Varianten;
- bevorzugte, erlaubte und unzulaessige Formen.

Bei unklarem Locale gilt:

- Audit: Mehrdeutigkeit melden, keine regionale Normalisierung vornehmen.
- Rewrite: bestehende konsistente Konvention bewahren.
- Explizite Normalisierung: das vom Nutzer angegebene Locale anwenden.
- Ein einzelnes Zeichen oder Wort reicht nicht fuer eine automatische Vollkonvertierung.

### 4.7 Terminologie und Glossare

Glossare sind verbindliche Projektprofile mit mindestens:

```json
{
  "source_locale": "en",
  "target_locale": "de-CH",
  "terms": [
    {
      "source": "storage tier",
      "target": "Speicherklasse",
      "case_sensitive": false,
      "allow_inflection": true
    }
  ],
  "protected_terms": ["TranslateGemma", "llama-server"]
}
```

Der Kern muss fehlende Pflichtbegriffe, verbotene Varianten und inkonsistente Uebersetzungen melden. Er darf keine neue Terminologie erfinden, wenn das Glossar oder der Kontext keine Entscheidung traegt.

### 4.8 Formatadapter

Jeder Formatadapter implementiert denselben Vertrag:

```text
detect
parse
extract_editable_spans
protect
rebuild
verify
```

- Klartext bewahrt Zeilenenden, Unicode und den Zustand des abschliessenden Zeilenumbruchs.
- Markdown schuetzt Code, Links, HTML, Tabellen, Zitate, Frontmatter und andere nicht freigegebene Syntax.
- JSON bearbeitet nur explizit ausgewaehlte Stringwerte. Schluessel, Zahlen, Booleans, `null`, Arraystruktur und Datentypen bleiben erhalten.
- JSON-Auswahl erfolgt ueber wiederholbare JSON-Pointer. Ohne Auswahl wird keine beliebige Zeichenkette geraten.
- Adapter deklarieren, ob Rekonstruktion bytegleich oder semantisch aequivalent garantiert wird.
- Nicht unterstuetzte oder mehrdeutige Konstruktionen schlagen fehl, statt still vereinfacht zu werden.

## 5. TranslateGemma-27B-Adapter

### 5.1 Zweck

Der Adapter bindet eine lokal betriebene TranslateGemma-27B-Instanz fuer folgende Aufgaben an:

- strukturtreue Uebersetzung;
- alternative Uebersetzung eines markierten Segments;
- terminologiegebundene Neuuebersetzung eines beanstandeten Segments;
- optionale Referenz fuer `translation-qa`.

Der Adapter ist nicht zustaendig fuer:

- autonome Humanisierung;
- allgemeines Proofreading ohne Ausgangstext;
- KI-Detektor-Optimierung;
- ungepruefte Volltext-Neuuebersetzung als Fehlerkorrektur;
- Quellenpruefung oder Faktenrecherche.

### 5.2 Adaptervertrag

Konzeptionelle Schnittstelle:

```json
{
  "adapter": "translategemma-27b",
  "source_digest": "sha256:...",
  "document_revision": "rev-...",
  "manifest_version": "1",
  "source_locale": "en",
  "target_locale": "de-CH",
  "segments": [
    {"id": "t00001", "source": "..."}
  ],
  "glossary": {},
  "constraints": {
    "preserve_tokens": true,
    "return_only_segments": true,
    "allowed_segment_ids": ["t00001"],
    "temperature": 0
  }
}
```

Antwort:

```json
{
  "segments": [
    {"id": "t00001", "translation": "..."}
  ],
  "model": "translategemma-27b-it",
  "model_revision": "...",
  "backend": "transformers",
  "adapter_status": "ready",
  "warnings": []
}
```

### 5.3 Betriebsregeln

- Standardmaessig deaktiviert; Aktivierung nur durch Konfiguration oder ausdruecklichen Auftrag.
- Lokale Bindung an Loopback oder einen explizit konfigurierten privaten Endpoint.
- Kein stiller Cloud-Fallback.
- Konfigurierbare Zeitlimits und maximal ein normaler Wiederholungsversuch pro fehlgeschlagenem Segment.
- Fehlende, doppelte oder unbekannte Segment-IDs fuehren zum Abbruch des betroffenen Ergebnisses.
- Geschuetzte Tokens muessen in gleicher Anzahl und Form erhalten bleiben.
- Quelle und Ausgabe duerfen nicht dieselbe Datei sein.
- Modelloutput wird vor dem Rebuild durch Struktur-, Token-, Glossar- und Locale-Checks geprueft.
- Als Code-Switching zu bewahrende Spannen werden nicht an den Adapter zur Uebersetzung freigegeben.
- Ein Adapterfehler liefert einen strukturierten Fehler; Humanizer und `proofread correct` bleiben nutzbar.
- Modellaufrufe, Batching und Wiederholungen halten den Pass-, Latenz- und Hardwarevertrag ein.

### 5.4 Chunking

- Tokenbasiert mit dem tatsaechlichen Modell-Tokenizer.
- Segmentgrenzen bevorzugt an Absatz- oder Manifestknoten.
- Kein Split innerhalb geschuetzter Tokens, Tabellenzellen oder Codebereiche.
- Sicherheitsreserve unterhalb des dokumentierten Modelllimits.
- Jeder Chunk ist idempotent und separat wiederholbar.
- Checkpoints sind nur wiederverwendbar, wenn Quell-Digest, Dokumentrevision, Manifestversion, Segment-ID, Quell- und Ziel-Locale, Glossar-Digest, Adapter-ID, Modellrevision und Promptvertragsversion uebereinstimmen.

### 5.5 Statusmodell

Status wird auf drei unabhaengigen Achsen gefuehrt:

| Achse | Werte |
|---|---|
| `workflow_status` | `pending`, `running`, `completed`, `failed`, `cancelled` |
| `adapter_status` | `disabled`, `unavailable`, `ready`, `degraded`, `failed` |
| `quality_disposition` | `not_evaluated`, `accepted`, `review_required`, `rejected` |

Abgeschlossene Pruefungen werden separat als `completed_checks` dokumentiert, beispielsweise `structure`, `protected_content`, `terminology`, `proofread` und `translation_qa`. Ein allfaelliger Gesamtstatus wird ausschliesslich aus diesen Feldern abgeleitet. Ein groesseres Modell oder ein grosser N-Gram-Abstand darf den Qualitaetsentscheid nicht automatisch verbessern.

## 6. Proofread-Engine

### 6.1 Kandidatenquellen

- deterministische Kern- und Locale-Regeln;
- lokal betriebene Grammatik- und Rechtschreib-Engine;
- sprachspezifische regelbasierte Linter;
- Modellurteil nur fuer kontextabhaengige Kandidaten;
- TranslateGemma nur im bilingualen Zweig.

### 6.2 Befundschema

```json
{
  "id": "finding-001",
  "segment_id": "t00001",
  "language": "de",
  "locale": "de-CH",
  "category": "grammar",
  "rule_id": "subject_verb_agreement",
  "severity": "error",
  "confidence": "high",
  "span": {"start": 12, "end": 18},
  "source": "...",
  "replacements": ["..."],
  "auto_apply": false,
  "reason": "..."
}
```

### 6.3 Invarianten- und Patchschema

Eine Invariante enthaelt mindestens `invariant_type`, `scope`, `expected`, `observed`, `comparison_method`, `severity`, `disposition`, `evidence` und `source_revision`. Vorgesehene Typen sind `protected_token`, `structure`, `claim`, `quantity`, `name`, `quotation`, `terminology`, `modality`, `speaker_position` und `locale_format`.

Fuer `structural` und `rebuild` wird pro Segment zusaetzlich ein Bedeutungsmanifest mit kommunikativer Funktion, Kernaussagen, Einschraenkungen, Evidenzankern und Sprecherposition erzeugt. Reine Umordnung wird von semantischer Aenderung unterschieden.

Patch-Entscheidungen fuehren `proposal_status`, `policy_decision`, `user_decision` und `application_status` getrennt. Jeder Entscheid referenziert Quellrevision und Entscheidungsautoritaet und besitzt einen maschinenlesbaren Grund. Patchstatus und `quality_disposition` sind verschiedene Felder.

Die wirksame Entscheidungsautoritaet und der Transaktionsumfang folgen dem Patch-Autoritaets- und Transaktionsvertrag. Ein generatives Modell darf Patches vorschlagen, aber weder harte Blocker aufheben noch sich selbst eine automatische Freigabe erteilen.

### 6.4 Auto-Apply-Grenze

Automatisch anwendbar sind nur nachweislich deterministische Aenderungen, etwa:

- gefaehrliche oder bedeutungslose Hidden-Unicode-Zeichen;
- explizit angeforderte Schweizer Normalisierung in freigegebener Prosa;
- eindeutig falsche, paarweise aufloesbare Anfuehrungszeichen;
- strukturell harmlose Leerraumfehler.

Grammatik, Kommas mit Bedeutungswirkung, Eigennamen, Fachbegriffe, Idiomatik, Register und regionale Lexik brauchen Kontextpruefung.

### 6.5 Source-Target-Alignment

Translation QA verwendet zuerst gemeinsame Manifest-IDs, danach explizite Mappings und erst anschliessend ein strukturelles Fallback. Das Fallback unterstuetzt `one_to_one`, `one_to_many`, `many_to_one`, unalignierte Segmente und reviewpflichtige Neuordnungen. Harte Ankerkonflikte verhindern eine automatische Alignment-Freigabe. Konfidenz, Abdeckung, Methode und Profilversion werden gemaess dem Source-Target-Alignment-Vertrag berichtet.

## 7. Verarbeitungspipeline

1. Einstiegspunkt und Auftrag bestimmen; Uebersetzung nie aus einem Humanizer-Auftrag ableiten.
2. Formatadapter, Pruefbereich, Sprache, Locale, Register, Auslieferungsprofil, Review-Profil und maximal erlaubte Eingriffstiefe bestimmen.
3. Dokumentrevision bilden, nur den erforderlichen Bereich parsen, Manifest erzeugen und geschuetzte Bereiche einfrieren. Bei einer Auswahl optionalen Kontext getrennt als nicht editierbar markieren.
4. Sprache und Code-Switching pro editierbarer Spanne klassifizieren.
5. Deterministische Unicode-, Struktur- und Locale-Pruefungen ausfuehren.
6. Je nach Auftrag Humanizer-, Proofread-, Translation- oder Translation-QA-Module laden und das geltende Passbudget festlegen.
7. Modellkandidaten ausschliesslich ueber den Agent-Core-Vertrag als positionsgebundene Vorschlaege anfordern.
8. Befunde gegen False Positives, Glossar, Claims sowie positive und negative Persona-Locks pruefen.
9. Vorschlag, Policy-Entscheid, Nutzerzustimmung und Anwendung getrennt fuehren; nur effektiv freigegebene, revisionspassende Patches anwenden.
10. Struktur, Bedeutungsmanifest, geschuetzte Tokens, Terminologie, Zahlen, Namen und Quellenanker verifizieren.
11. Sprach-, Locale- und Formatpruefung erneut ausfuehren.
12. Statusachsen, Laufzeitprofil, Routingnachweis, geprueften Bereich, nicht ausgefuehrte dokumentweite Checks, Ergebnis und verbleibende Unsicherheiten ausgeben.

## 8. CLI-Zielbild

```text
humanizer-ch audit FILE --language de --locale de-CH --register sachlich
humanizer-ch audit FILE --select segment:t00017 --review-profile critical_text --locale de-CH
humanizer-ch audit --stdin --review-profile critical_text --locale de-CH
humanizer-ch rewrite FILE --locale de-CH --rewrite-depth local --delivery-profile report --output OUT
proofread-ch correct FILE --locale fr-CH --output OUT
proofread-ch edit FILE --locale en-GB --output OUT
proofread-ch translation-qa SOURCE TARGET --source-locale en --target-locale it-CH
translate-ch run FILE --target-locale de-CH --adapter translategemma-27b --output OUT
```

Wichtige Optionen:

- `--language` und `--locale`
- `--register locker|sachlich|formal`
- `--rewrite-depth minimal|local|structural|rebuild`
- `--delivery-profile neutral|email|chat|report|social|application|marketing`
- `--review-profile standard|critical_text|PATH`
- `--select segment:ID|span:START:END`, wiederholbar
- `--stdin` fuer einen direkt uebergebenen Textbaustein
- `--glossary PATH`
- `--profile PATH`
- `--input-format auto|text|markdown|json`
- `--json-pointer POINTER`, wiederholbar
- `--report-format text|json`
- `--fix-safe`
- `--adapter none|translategemma-27b`
- `--fail-on never|blocker|any`

Standardwerte sind `rewrite-depth=local`, `delivery-profile=neutral`, `adapter=none`, `report-format=text` und `fail-on=blocker`. `audit` verwendet `preview`, `proofread correct` verwendet `safe_only`; `rewrite` veraendert nie die Eingabedatei und `edit-file` schreibt erst nach erfolgreicher Dokumentverifikation atomar.

## 9. Ausgaben

Maschinenlesbare Ausgabe:

- erkannte Sprache und Locale inklusive Sicherheit;
- angewandter Arbeitszweig;
- Befunde mit Segment und Span;
- angewandte und verworfene Aenderungen;
- Patch-Entscheidungen und referenzierte Dokumentrevision;
- Claim-, Persona-, Struktur- und Terminologiepruefung;
- Workflow-, Adapter- und Qualitaetsstatus sowie abgeschlossene Pruefungen;
- verbleibende Unsicherheiten;
- gepruefter Bereich, nur als Kontext gelesene Bereiche und nicht ausgefuehrte dokumentweite Checks;
- Modellrolle, Routingprofil, Modellrevision, Effort und Eskalationsgrund pro generativem Aufruf.

Nutzerorientierte Ausgabe:

1. Modus, Sprache und Locale
2. wichtigste Befunde
3. geaenderte Stellen oder Dateiergebnis
4. Beleg- und Terminologiehinweise
5. Kurzaudit und verbleibende Unsicherheiten

## 10. Nicht-funktionale Anforderungen

- Python 3.10 oder neuer fuer Skripte.
- Kernpfad ohne Netzwerkzugriff funktionsfaehig.
- Reproduzierbare Ergebnisse fuer deterministische Regeln.
- Atomare Dateiausgabe; keine Teilresultate als Erfolg markieren.
- Keine Modifikation der Eingabedatei ohne expliziten Datei-Edit-Auftrag.
- JSON-Ausgaben mit stabilem, versioniertem Schema.
- Grosse Dokumente segmentweise und wiederaufnehmbar verarbeiten.
- Patches und Checkpoints duerfen nur auf exakt passende Dokument- und Vertragsrevisionen angewendet werden.
- Adapter und schwere NLP-Modelle lazy laden.
- Keine Parallelbelastung mehrerer TranslateGemma-Modelle als Standard.
- Kern-, Grammatik-, Host-Modell- und Adapterlatenz getrennt messen.
- Passbudgets, Hardwareprofile, ETA, Fortschritt und Abbruch folgen dem Pass-, Latenz- und Hardwarevertrag.
- Modellrollen, Effort und Eskalationen folgen dem Modell-, Rollen- und Effort-Vertrag.
- Teilpruefungen laden und bearbeiten nur die Auswahl sowie den explizit begrenzten, nicht editierbaren Kontext.
- Konfiguration folgt der festen Prioritaet explizite Aufrufoption, Projektprofil, Nutzerprofil, eingebauter sicherer Standard. Umgebungsvariablen duerfen nur dokumentierte technische Endpoints oder Laufzeitpfade setzen und keine inhaltliche Policy still ueberschreiben.
- CLI, Skills, Kern und Adapter verwenden eine gemeinsame versionierte Fehlerklasse mit stabilem Fehlercode, betroffener Komponente, Wiederholbarkeit und sicherer Nutzerhandlung.

## 11. Tests und Abnahme

Ein kanonischer Test-Harness fuehrt dieselben Stufen lokal und in CI aus:

1. Schema-, Contract- und Referenzintegritaet;
2. Unit- und Formatadaptertests;
3. eingefrorene Baseline sowie Positiv-, Null-Edit- und False-Positive-Korpora;
4. Auswahltests fuer `critical_text` einschliesslich Scope- und Kontextgrenzen;
5. szenariobasierte Verhaltens-Evaluation;
6. optionale, getrennt gekennzeichnete Modellmatrix fuer Routing, Effort, Qualitaet, Latenz und Kosten;
7. Skill-Strukturpruefung, reproduzierbares Bundle und Installations-Smoke-Test.

Der Harness erzeugt einen maschinenlesbaren Ergebnisreport mit Testkorpusrevision, Vertragsversionen, Routingprofil, exakten Modellrevisionen und Umgebung. Nicht konfigurierte optionale Modelltests werden als `skipped`, nicht als bestanden, ausgewiesen.

Jede Sprache und jedes Locale braucht:

- echte Positivfaelle;
- saubere Negativfaelle;
- formale und technische False-Positive-Faelle;
- Code-, Markdown-, HTML- und Platzhalterschutz;
- Terminologie- und Eigennamentests;
- regionale Varianten, die bewusst nicht korrigiert werden;
- Vorher/Nachher-Invarianten;
- mindestens einen langen strukturierten Dokumentfall.
- Auswahlfaelle fuer direkte Textbausteine, Datei-Spans und Segment-IDs inklusive Kontextgrenzen.

Abnahmebedingungen fuer Version 1.0:

- Kern, `humanizer-ch` und `proofread-ch` laufen ohne TranslateGemma.
- de-CH, de-DE, de-AT und en-GB/en-US besitzen getestete Sprach- und Locale-Profile.
- fr-CH und it-CH bestehen definierte Pilotkorpora.
- Klartext-, Markdown- und JSON-Adapter bestehen ihre deklarierte bytegleiche oder semantische Rekonstruktionsgarantie in 100 Prozent der freigegebenen Fixtures.
- Kein Testfall veraendert geschuetzte Tokens oder Faktenanker unbemerkt.
- Kein freigegebenes Ergebnis enthaelt einen offenen Invariant-Blocker.
- Null-Edit-, False-Positive- und bestehende `humanizer-de`-Baseline verschlechtern sich gegenueber der in Phase 0 eingefrorenen Baseline nicht.
- Jede neue Auto-Apply-Regel besteht alle Positiv- und False-Positive-Faelle ihrer freigegebenen Regelklasse.
- Code-Switching, positive Stimmmerkmale, Rewrite-Tiefe und Auslieferungsprofile besitzen beobachtbare End-to-End-Faelle.
- `critical_text` prueft einzelne Textbausteine ohne Volltextlauf und weist dokumentweite Checks korrekt als `not_run` aus.
- Die Routingmatrix ist gegen eingefrorene Qualitaets-, Latenz- und Kostenmetriken evaluiert; billige Hoch-Effort-Varianten werden nicht ungeprueft als gleichwertig angenommen.
- TranslateGemma 27B kann aktiviert, deaktiviert und kontrolliert fehlschlagen.
- Translation QA erkennt definierte Auslassungs-, Zahlen-, Negations- und Terminologiefaelle.
- Keine offenen P0-Defekte; jede verbleibende P1-Abweichung ist dokumentiert und explizit akzeptiert.

## 12. Nicht-Ziele

- Autorschafts- oder KI-Nachweis
- Garantie gegen statistische Wasserzeichen
- Optimierung auf GPTZero oder andere Detektoren
- automatische Faktenrecherche
- freie literarische Neuinterpretation
- vollstaendige maschinelle Uebersetzungsplattform
- automatische regionale Umschreibung ohne explizites Locale
- generisches Chat-Interface fuer TranslateGemma
