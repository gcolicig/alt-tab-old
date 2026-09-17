# Konfigurations- und Capability-Vertrag

Status: Normativer Entwurf 0.1.0
Verantwortung: `humanizer_ch_core.configuration`

## Zweck

Dieser Vertrag definiert, wie Konfiguration geladen, zusammengefuehrt, validiert und ohne Textinhalte ausgewiesen wird. Er trennt den Nutzerentscheid ueber Verhalten von der technischen Erkennung optionaler Laufzeitfaehigkeiten.

## Konfigurationsquellen und Prioritaet

Fuer jeden Schluessel gilt von niedrigster zu hoechster Prioritaet:

1. eingebaute sichere Standards;
2. Nutzerprofil;
3. Projektprofil;
4. explizite Aufrufoption.

Nur explizit gesetzte Werte ueberschreiben die darunterliegende Quelle. `null`, ein leerer String und ein fehlender Wert sind verschiedene Zustaende und werden nicht still gleichgesetzt. Listen werden vollstaendig ersetzt; Objekte werden schluesselweise zusammengefuehrt, sofern das Schema fuer den betreffenden Schluessel keine atomare Ersetzung verlangt.

Umgebungsvariablen sind keine fuenfte Konfigurationsschicht. Sie duerfen ausschliesslich in einer versionierten Allowlist als Laufzeitbindung referenziert werden, beispielsweise fuer ein Secret, einen privaten Adapter-Endpoint oder ein Cache-Verzeichnis. Eine Bindung fuellt genau das deklarierte Laufzeitfeld und besitzt keine allgemeine Ueberschreibungswirkung.

Die Allowlist der Version 0.1.0 lautet:

| Konfigurationsfeld | Erlaubte Variable |
|---|---|
| `runtime.cache_directory` | `HUMANIZER_CH_CACHE_DIRECTORY` |
| `runtime.private_endpoint` | `HUMANIZER_CH_PRIVATE_ENDPOINT` |
| `runtime.secret` | `HUMANIZER_CH_ADAPTER_SECRET` |

Der aufgeloeste private Endpoint muss Loopback oder einem explizit im Projektprofil freigegebenen privaten Host entsprechen. Die Variable darf keinen Cloud-Fallback einfuehren.

## Unveraenderliche Policy-Grenzen

Umgebungsvariablen, Capability-Probes und Adapterantworten duerfen insbesondere folgende Werte weder setzen noch veraendern:

- Operation, Pruefbereich und Rewrite-Tiefe;
- Consent-Modus und Patch-Autoritaet;
- Quell- und Ziel-Locale;
- Schutz-, Invarianten- und Auto-Apply-Regeln;
- Cloud-Fallback, Textlogging oder Datenweitergabe;
- Modellrolle, Routingprofil oder Eskalationsschwelle.

Ein Versuch wird vor Verarbeitung von Text mit `HC_CONFIG_ENV_FORBIDDEN` abgelehnt. Nicht erlaubte Variablennamen werden nicht generisch importiert und erscheinen weder in der effektiven Konfiguration noch im Report.

## Konfigurationsdokument

Profile entsprechen `schemas/configuration.schema.json`. Jede Datei besitzt `schema_version`; unbekannte Felder sind ungueltig. Teilprofile duerfen Werte auslassen. Nach dem Merge muss die effektive Konfiguration alle fuer die gewaehlte Operation benoetigten Felder besitzen.

Die Implementierung arbeitet in dieser Reihenfolge:

1. Dateien als Daten lesen, ohne Adapter oder Modelle zu initialisieren.
2. Schemaversion und jede Quelle einzeln validieren.
3. Quellen in festgelegter Prioritaet zusammenfuehren und Herkunft pro Blattwert erfassen.
4. erlaubte Laufzeitbindungen aufloesen, Secrets nur als vorhanden oder fehlend erfassen.
5. Kreuzfeldregeln und Operationsanforderungen validieren.
6. normalisierte effektive Konfiguration bilden und deren Digest berechnen.
7. erst danach Text laden und optionale Komponenten initialisieren.

## Kreuzfeldregeln

- `source_locale` und `target_locale` werden getrennt gefuehrt. Eine Uebersetzung braucht beide; Humanisierung und monolinguales Proofreading duerfen kein abweichendes Ziel implizieren.
- `scope_mode=selection` oder `segments` braucht eine passende Auswahlidentitaet gemaess `selection-scope.md`; die Konfiguration selbst enthaelt keinen Text.
- `rewrite_depth=rebuild` ist bei `operation=audit` unzulaessig.
- `cloud_fallback=true` ist in Version 0.1.0 unzulaessig.
- Ein aktivierter optionaler Adapter muss eine deklarierte Capability-Anforderung besitzen. `required=false` erlaubt einen kontrollierten Fallback, `required=true` nicht.
- Widerspruechliche explizite Aufrufoptionen werden nicht durch Profilwerte repariert.

## Herkunftsnachweis

Der Report enthaelt fuer jeden effektiven Blattwert mindestens:

```json
{
  "json_pointer": "/policy/consent_mode",
  "source": "invocation",
  "source_id": "cli",
  "value_state": "plain",
  "value": "preview"
}
```

`source` ist `builtin`, `user_profile`, `project_profile` oder `invocation`. Fuer erlaubte Laufzeitbindungen wird zusaetzlich `binding_source=environment` und nur der Variablenname ausgewiesen. Secretwerte, Text, Prompts und Adapterantworten erscheinen nie. `value_state` ist `plain`, `redacted`, `digest_only` oder `presence_only`.

`effective_config_digest` wird aus der kanonisch normalisierten Konfiguration gebildet. Bei Secrets geht die stabile Referenz, nie der Secretwert, in den Digest ein. Aendert sich der Secretwert bei gleicher Referenz, muss eine davon getrennte `runtime_binding_revision` die Cache-Wiederverwendung verhindern, ohne das Secret offenzulegen.

## Capability-Erkennung

Capability-Erkennung beantwortet nur, ob eine optionale Funktion konfiguriert und voraussichtlich nutzbar ist. Sie veraendert keine Policy und ist kein Qualitaetsurteil.

Erlaubte Probes sind:

- Paketmetadaten oder ein leichtgewichtiger Modul-Spec-Lookup ohne Import schwerer Laufzeiten;
- Existenz und lesbare Metadaten lokaler Modellartefakte ohne Laden von Gewichten;
- statische Adapterkonfiguration und Protokollversion;
- ein explizit angeforderter, textfreier Healthcheck mit kurzem Zeitlimit;
- Ressourcenmetadaten des Backends ohne Modellinitialisierung.

Beim normalen Konfigurations- und `doctor`-Probe verboten sind Modellgewichte laden, GPU-Speicher reservieren, Texte senden, Dateien herunterladen, Cloud-Fallback aktivieren oder einen kostenpflichtigen Modellaufruf ausloesen.

Ein Capability-Eintrag besitzt:

| Feld | Bedeutung |
|---|---|
| `capability_id` | stabiler fachlicher Bezeichner |
| `provider_id` | implementierender Adapter oder lokaler Provider |
| `configured` | explizit konfiguriert |
| `enabled` | fuer diesen Aufruf freigegeben |
| `required` | Fehlen blockiert den Workflow |
| `availability` | `unknown`, `available`, `unavailable`, `degraded` |
| `probe_method` | `metadata`, `artifact_manifest`, `healthcheck`, `backend_metadata`, `not_run` |
| `probe_revision` | Version der Probe-Logik |
| `checked_at` | RFC-3339-Zeitpunkt oder `null` bei `not_run` |
| `reason_code` | stabiler maschinenlesbarer Grund |

`configured=true` bedeutet nicht `available`; `available` bedeutet nicht `enabled`; `enabled` bedeutet nicht erfolgreich ausgefuehrt. Der tatsaechliche Laufstatus bleibt in `adapter_status`, `workflow_status` und `completed_checks` getrennt.

## Fehler- und Fallbackregeln

- Unbekannter Schluessel: `HC_CONFIG_UNKNOWN_OPTION`.
- Unbekannte Major-Schemaversion: `HC_CONFIG_SCHEMA_UNSUPPORTED`.
- Nicht validierbares Profil oder Typfehler: `HC_CONFIG_PROFILE_INVALID`.
- Widerspruechliche Locale-Angaben: `HC_CONFIG_LOCALE_CONFLICT`.
- Verbotene Umgebungsbindung: `HC_CONFIG_ENV_FORBIDDEN`.
- Fehlendes benoetigtes Secret: `HC_CONFIG_SECRET_MISSING`.
- Fehlende erforderliche Capability blockiert vor Textverarbeitung mit der passenden Adapter- oder Modellfehlerklasse.
- Fehlende optionale Capability setzt deren Verfuegbarkeit auf `unavailable`; der Workflow darf nur weiterlaufen, wenn ein im Profil deklarierter, semantisch zulaessiger Fallback existiert.
- Ein Fallback darf Operation, Pruefbereich, Consent oder Rewrite-Tiefe nicht erweitern und wird im Report ausgewiesen.

## Testbare Invarianten

- Dieselben vier Quellen ergeben unabhaengig von Dateireihenfolge und Prozessumgebung dieselbe effektive Konfiguration.
- Ein expliziter Aufrufwert gewinnt immer gegen Projekt-, Nutzer- und Standardwert.
- Eine unbekannte Option schlaegt fehl, statt ignoriert zu werden.
- Kein beliebiger Prozess-Environmentwert kann eine Policy-Aenderung bewirken.
- Ein normaler Capability-Probe initialisiert kein Modell und erzeugt keinen Netzaufruf, ausser ein Healthcheck wurde explizit angefordert.
- Herkunftsreport und Standardfehler enthalten weder Text noch Secretwerte.
- Ein nicht erforderlicher, fehlender Adapter kann einen dokumentierten Fallback ausloesen; ein erforderlicher nicht.
- Aenderungen an Locale, Consent, Schutzregeln oder Capability-Anforderungen aendern den Konfigurationsdigest.

## Kompatibilitaet

Neue optionale Felder und neue Capability-IDs duerfen in einer Minor-Version hinzukommen. Neue Prioritaetsregeln, geaenderte Policy-Grenzen, still akzeptierte unbekannte Felder oder geaenderte Secretsemantik erfordern eine neue Major-Version. Unbekannte Major-Versionen werden abgelehnt.
