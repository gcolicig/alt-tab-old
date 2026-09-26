# Spezifikation: Tipp-Stummschaltung

Stand: 2026-09-26

Ergaenzende Spezifikation zu `backlog.md`. Sie erweitert die Systemaktionen rund um das Mikrofon
(`AudioMute.swift`, `MicMuteIndicator.swift`, `TeamsMuteSync.swift`) und aendert keine bestehende Phase.
Die Querschnittsanforderungen `Q-01` bis `Q-12` gelten.

## Leitidee

In Calls hoeren alle anderen das Klackern der Tastatur, sobald jemand mitschreibt. Unclack loest das,
indem es das Mikrofon waehrend des Tippens kurz stummschaltet und danach sofort wieder freigibt. AltTab+
hat mit dem Keyboard-Tap und `AudioMute` bereits beide Haelften; die Funktion verbindet sie.

Grundsatz: **fail-unmuted fuer die eigene Stummschaltung, nie fuer die des Nutzers.** Eine
Tipp-Stummschaltung, die haengen bleibt, ist der schwerste Fehler: der Nutzer spricht und niemand hoert
ihn. Umgekehrt darf die Funktion ein Mikrofon, das der Nutzer selbst stummgeschaltet hat, nie freigeben.

## Status und Prioritaet

Status: Spezifiziert, nicht begonnen
Prioritaet: Mittel. Klein, nutzt bestehenden Tap und bestehende CoreAudio-Pfade.

## Plattform und Einbindung

- Deployment Target 13.1 genuegt; alle verwendeten CoreAudio-Properties existieren seit langem.
- Ort: `src/logic/system-actions/TypingMute.swift` (Zustand, Timer, CoreAudio-Ownership) und
  `TypingMuteTestable.swift` (reine Zustandsmaschine, siehe [Zustandsmodell](#zustandsmodell)).
- **Kein eigener Event-Tap.** Der bestehende Tap in `KeyboardEvents.swift` sieht bereits `keyDown`,
  `keyUp` und `flagsChanged`. Er meldet Tastenereignisse an `TypingMute.keyActivity(...)`; die Meldung
  ist ein Zeitstempel-Schreibzugriff, keine Arbeit im Callback (Q-02).
- Settings: neuer Schalter auf der Seite Systemaktionen, unterhalb von `teamsMuteSync`.
- Neue Dateien muessen von Hand in `alt-tab-macos.xcodeproj/project.pbxproj` eingetragen werden.

## Leitplanken

| ID | Anforderung | Grund |
|---|---|---|
| TM-01 | Vorgabe aus; Import, Migration und Creator's Settings schalten es nie ein | Q-08; die Funktion greift in Calls ein |
| TM-02 | Funktion aus oder kein Mikrofon in Benutzung: kein Timer, keine CoreAudio-Schreibzugriffe | Q-10 |
| TM-03 | Im Tap-Callback nur Zeitstempel und Flag setzen; CoreAudio-Aufrufe auf eigener serieller Queue | Q-02; `AudioObjectSetPropertyData` kann bei USB-Geraeten blockieren |
| TM-04 | Die Funktion gibt nur Geraete frei, die sie selbst stummgeschaltet hat und die sie noch besitzt | Manuelle Stummschaltung des Nutzers hat Vorrang |
| TM-05 | Eine Tipp-Stummschaltung loest nie `TeamsMuteSync` aus, weder direkt noch ueber den 10-s-Abgleich | Sonst drueckt AltTab+ in Teams bei jedem Wort den Mute-Knopf, und ohne `allowUnmute` bleibt Teams danach stumm |
| TM-09 | `AudioMute.isMuted(input:)` wertet Geraete in der TypingMute-Ownership als **nicht stumm** (nicht: ausgelassen) | Siehe [Teams](#teams); Auslassen kippt die Auswertung, wenn nur eigene Geraete uebrig bleiben |
| TM-10 | Die Ownership ist threadsicher lesbar (Lock oder atomarer Snapshot) | `TeamsMuteSync` liest `isMuted` auf `accessibilityCommandsQueue` mit bis zu 4 parallelen Operationen |
| TM-06 | Panic-Kill-Switch (Q-01), Beenden und Safe Mode geben alle eigenen Stummschaltungen sofort frei | Ein Weg, der garantiert das Mikrofon zurueckbringt |
| TM-07 | Absturzsicherheit: eigene Stummschaltungen werden vor dem Schreiben persistiert und beim naechsten Start freigegeben | `kill -9` darf kein stummes Mikrofon hinterlassen |
| TM-08 | Keine Tastencodes, Zeichen oder Tipp-Frequenzen im Log oder Ringbuffer, nur Zustandswechsel | Der Tap sieht alles, was der Nutzer tippt |

## Verhalten

### Aktivierung

Die Funktion ist scharf, wenn alle Bedingungen gelten:

1. `typingMuteEnabled` ist an und Safe Mode ist aus.
2. Mindestens ein Eingabegeraet meldet `kAudioDevicePropertyDeviceIsRunningSomewhere == 1`, also nimmt
   irgendeine App gerade vom Mikrofon auf (Call, Aufnahme, Diktat).
3. Das Mikrofon ist nicht bereits vollstaendig vom Nutzer stummgeschaltet.

Bedingung 2 wird ueber einen CoreAudio-Listener auf `kAudioDevicePropertyDeviceIsRunningSomewhere`
verfolgt. Der Listener existiert nur, solange `typingMuteEnabled` an ist. Ohne laufendes Mikrofon
ignoriert `keyActivity` jede Meldung sofort; es entsteht kein Timer.

### Ablauf

```text
keyDown (kein Autorepeat) ──► idle? ──ja──► mute(eigene Geraete) ──► holding
                                           │
keyDown / keyUp waehrend holding ──────────┴──► Frist verlaengern
                                                        │
Frist abgelaufen (letzte Taste + holdMs) ───────────────► release(eigene Geraete) ──► idle
```

- **Ausloeser:** nur `keyDown` ohne Autorepeat. Gehaltene Tasten klicken nicht. `flagsChanged` allein
  (Modifier druecken) loest nicht aus, verlaengert aber eine laufende Frist.
- **Frist:** `holdMs` nach dem letzten `keyDown` oder `keyUp`. Default 400 ms, Bereich 150 bis 1500 ms.
  Der `keyUp` zaehlt mit, weil das Loslassen ebenfalls klickt.
- **Ein Timer:** Ein einzelner `DispatchSourceTimer` auf der TypingMute-Queue wird bei jeder Taste neu
  gesetzt, nicht neu erzeugt. Er existiert nur im Zustand `holding` (Q-10).
- **Ausnahmen:** Tasten, die Teil eines von AltTab+ konsumierten Shortcuts oder einer Leader-Session
  sind, loesen nicht aus. Leertaste und Enter loesen aus wie jede andere Taste.

### Welche Geraete

- Standard: nur Eingabegeraete, die gerade laufen (`IsRunningSomewhere`). Ein unbenutztes USB-Mikrofon
  wird nicht angefasst.
- **Standardweg ist die Eingangslautstaerke**, wie in `AudioMute.simulateInputMute`: Wert merken, auf
  0 setzen, spaeter zuruecksetzen. Grund: Teams zeigt bei gesetzter `kAudioDevicePropertyMute` den
  Hinweis „Dein Mikrofon ist stumm“ (beobachtet 2026-09-26). Die Mute-Property ist nur Rueckfall fuer
  Geraete ohne settable `kAudioDevicePropertyVolumeScalar`; auf diesen Geraeten erscheint der Hinweis
  weiterhin, das UI sagt es beim Einschalten.
- Der gemerkte Lautstaerkewert gehoert der TypingMute-Ownership, nicht `AudioMute.simulatedInputMutes`,
  bis `surrenderOwnership` ihn uebergibt.
- Ein Geraet, das beim Ausloesen bereits stumm ist oder Lautstaerke 0 hat, gehoert **nicht** zur
  Ownership und wird beim Freigeben nicht angefasst (TM-04).
- Aendert jemand anders die Lautstaerke eines eigenen Geraets waehrend `holding` (Nutzer im
  Kontrollzentrum, automatische Mikrofonempfindlichkeit einer Call-App), faellt das Geraet aus der
  Ownership. Die neue Lautstaerke bleibt; TypingMute ueberschreibt sie beim Freigeben nicht.

### Vorbereiteter Schreibplan

Ein Tastendruck darf nur noch die eigentlichen Schreibzugriffe kosten. Jede CoreAudio-Abfrage ist ein
IPC-Aufruf an `coreaudiod`; `AudioMute.inputDevices()` allein braucht pro Geraet mehrere davon.

- TypingMute haelt einen **Plan**: je laufendem Eingabegeraet die `AudioObjectID`, den Weg (Lautstaerke
  oder Mute), die fertige `AudioObjectPropertyAddress` und die aktuelle Lautstaerke.
- Der Plan wird ausserhalb des Tippens neu gebaut: bei Aenderung der Geraeteliste, von
  `IsRunningSomewhere` und von Lautstaerke oder Mute (Listener, solange die Funktion an ist).
- `keyDown` im Zustand `idle` fuehrt pro Geraet genau einen `AudioObjectSetPropertyData` aus, das
  meistgenutzte Geraet zuerst (Default-Input vor weiteren). Kein Lesen, keine Enumeration.
- Die Uebergabe vom Tap an die TypingMute-Queue kostet Mikrosekunden und bleibt (TM-03).

## Zustandsmodell

Die Logik ist eine reine Zustandsmaschine in `TypingMuteTestable.swift`, analog `LeaderSession` und
`HyperKeyStateMachine`. Sie kennt keine CoreAudio- oder Tap-Typen und liefert nur Entscheidungen.

| Zustand | Ereignis | Folgezustand | Entscheidung |
|---|---|---|---|
| idle | keyDown, scharf | holding | `mute(devices)`, Frist setzen |
| idle | keyDown, nicht scharf | idle | keine |
| holding | keyDown / keyUp / flagsChanged | holding | Frist verlaengern |
| holding | Frist abgelaufen | idle | `release(owned)` |
| holding | manuelle Aktion (`AudioMute.toggle`, Mikrofontaste, Menueleisten-Klick) | idle | Ownership verwerfen, **nichts** schreiben |
| holding | externe Mute-Aenderung an einem eigenen Geraet | holding | Geraet aus Ownership entfernen |
| holding | Geraet verschwindet | holding | Geraet aus Ownership entfernen |
| holding | Mikrofon nicht mehr in Benutzung | idle | `release(owned)` |
| beliebig | Panic, Safe Mode, Beenden, Funktion aus | idle | `release(owned)` synchron |

### Manueller Eingriff waehrend `holding`

Der Nutzer drueckt die Mikrofontaste, waehrend AltTab+ wegen Tippens stummgeschaltet hat. Das
Mikrofon ist technisch stumm, der Nutzer meint aber seinen eigenen Zustand. Festgelegt:

- `AudioMute.toggle(input: true)` liest den Ausgangszustand **vor** der Uebergabe. Nach TM-09 gelten
  eigene Geraete dabei als nicht stumm, der Toggle will also stummschalten.
- Danach ruft er `TypingMute.surrenderOwnership()`. Das stoppt den Timer, loescht den Absturz-Marker und
  uebergibt jedes eigene Geraet an `AudioMute`:
  - Stumm ueber Mute-Property: Geraet bleibt stumm, `AudioMute` schreibt nichts.
  - Stumm ueber Lautstaerke: die gemerkte Ursprungslautstaerke wandert nach
    `AudioMute.simulatedInputMutes`. **Ohne diese Uebergabe koennte der Nutzer die Lautstaerke spaeter
    nicht wiederherstellen; das Mikrofon bliebe dauerhaft auf 0.**
- Fuer die uebrigen Geraete laeuft der Toggle normal. Am Ende ruft er wie heute
  `TeamsMuteSync.microphoneToggled()` auf; das ist ein manueller Pfad und darf Teams stummschalten.
- Damit fuehrt ein Druck auf die Mikrofontaste immer zu dem Zustand, den der Nutzer erwartet, und die
  Frist gibt spaeter nichts frei.

### Externe Aenderungen

Eigene Schreibzugriffe loesen dieselben Property-Listener aus wie fremde. Unterscheidung: TypingMute
merkt sich pro Geraet den zuletzt selbst geschriebenen Wert. Ein Listener-Ereignis mit abweichendem
Wert gilt als extern und entfernt das Geraet aus der Ownership.

## Zusammenspiel mit bestehenden Funktionen

| Funktion | Verhalten |
|---|---|
| `MicMuteIndicator` | Zeigt Tipp-Stummschaltung **nicht** als stummes Mikrofon; sonst flackert das Icon bei jedem Wort. `AudioMute.isMuted(input:)` ignoriert Geraete in der TypingMute-Ownership. Optional eigenes dezentes Icon, siehe [Offene Fragen](#offene-fragen) |
| `TeamsMuteSync` | Siehe [Teams](#teams) |
| `MicKey` | Unveraendert; die Taste landet ueber `KeyboardEvents` in `AudioMute.toggle` und damit in `surrenderOwnership` |
| Systemaktion „Mikrofon stumm“ | `isOn` nutzt `AudioMute.isMuted` und zeigt dank TM-09 den Zustand des Nutzers, nicht den der Tipp-Phase |
| `MicMuteIndicator.unmute` | Waehrend einer Tipp-Phase ohne manuelle Stummschaltung ist kein Icon sichtbar; ein Klick ist also nicht moeglich |
| `AudioMute.restoreOnQuit` | Ruft zusaetzlich `TypingMute.releaseAll()` auf |
| Panic-Kill-Switch | `disableInputModulesForSafety` ruft `TypingMute.releaseAll()` auf |

### Teams

`TeamsMuteSync` synchronisiert heute nur in eine Richtung: vom Systemzustand nach Teams, per AXPress auf
„Mute mic“ oder „Unmute mic“. Es hat zwei Einstiege, und beide lesen `AudioMute.isMuted(input: true)`:

| Einstieg | Heute | Risiko ohne Anpassung | Festlegung |
|---|---|---|---|
| 10-s-Timer, `allowUnmute: false` | Schaltet Teams stumm, wenn das System stumm ist | Faellt der Tick in eine Tipp-Phase, schaltet AltTab+ Teams stumm. Nach dem Tippen ist das Mikrofon offen, aber Teams bleibt stumm, weil der Timer nie freigibt. Bei laengerem Tippen ist das fast sicher | TM-09: eigene Geraete zaehlen als offen, der Tick sieht „nicht stumm“ und tut nichts |
| `microphoneToggled()`, `allowUnmute: true` | Nur aus `AudioMute.toggle` | TypingMute koennte denselben Pfad nutzen, wenn es `toggle` verwendet | TypingMute schreibt ueber eigene Funktionen, nie ueber `toggle` (TM-05) |
| Doppelpruefung nach 200 ms | Vergleicht `isMuted` mit dem ersten Wert | Beginnt oder endet dazwischen eine Tipp-Phase, koennte der Vergleich kippen | Durch TM-09 aendert eine Tipp-Phase `isMuted` nicht; der Vergleich bleibt stabil |

Warum „als offen werten“ statt „auslassen“: `isMuted` verlangt, dass die Liste nicht leer ist **und**
alle Geraete stumm sind. Laesst man eigene Geraete aus und ist ein zweites, unbenutztes Mikrofon vom
Nutzer stumm, ergibt die Restliste „alle stumm“, und Teams wuerde stummgeschaltet.

Weitere Festlegungen:

- `AudioMute.isMuted` wird auf `accessibilityCommandsQueue` parallel gelesen. Die Ownership braucht
  deshalb TM-10. `AudioMute.simulatedInputMutes` ist schon heute nicht threadsicher; die Uebergabe in
  `surrenderOwnership` laeuft auf dem Main Thread, wie `toggle` selbst.
- **Hinweis „Dein Mikrofon ist stumm“:** erscheint bei gesetzter Mute-Property (beobachtet
  2026-09-26). Deshalb ist die Eingangslautstaerke der Standardweg, siehe [Welche Geraete](#welche-geraete).
  Ob Teams auch auf Lautstaerke 0 reagiert, ist offen.
- **Helper-Prozesse:** Teams nimmt nicht im Hauptprozess auf. Im Bundle liegen
  `com.microsoft.teams2.modulehost` (Media-Stack, einziger Helper mit `NSMicrophoneUsageDescription`)
  und `com.microsoft.teams2.helper` (WebView). Folgen:
  - Die Aktivierung ueber `IsRunningSomewhere` ist prozessunabhaengig und funktioniert unveraendert.
  - Jede kuenftige Pruefung „nimmt Teams gerade auf?“ muss die Helper erfassen: Bundle-ID mit Praefix
    `com.microsoft.teams2.`, nicht Gleichheit mit `com.microsoft.teams2`.
  - `TeamsMuteSync` sucht den Mute-Knopf korrekt im Hauptprozess, weil die UI dort liegt; das bleibt.
- Teams bekommt die Tipp-Stummschaltung nur auf Geraeteebene mit. Der Mute-Knopf in Teams bleibt
  unveraendert, und im Call erscheint kein Wechsel „stumm/offen“ bei den anderen Teilnehmenden.

## Absturzsicherheit

- Vor dem ersten Schreibzugriff einer `holding`-Phase schreibt TypingMute einen Marker in
  `UserDefaults`: Device-UIDs, Art (Mute-Property oder Lautstaerke) und gegebenenfalls die
  Ursprungslautstaerke. Nach `release` wird der Marker geloescht.
- Beim Start prueft AltTab+ den Marker **unabhaengig davon, ob die Funktion an ist**, gibt die gelisteten
  Geraete frei, sofern sie noch den von TypingMute geschriebenen Zustand haben, und loescht den Marker.
- Der Marker wird nur beim Wechsel `idle → holding` und zurueck geschrieben, nicht pro Taste.

## Einstellungen

| Schluessel | Werte | Default |
|---|---|---|
| `typingMuteEnabled` | bool | aus |
| `typingMuteHoldMs` | 150 bis 1500 | 400 |

Beschriftung: „Mikrofon beim Tippen stummschalten“ mit Hinweis „Nur waehrend eine App das Mikrofon
benutzt. Die Mikrofontaste hat immer Vorrang.“ Der Regler fuer die Frist erscheint erst, wenn der
Schalter an ist.

## Budgets

- Tap-Callback: zusaetzlich hoechstens ein atomarer Zeitstempel-Schreibzugriff und ein Flag-Vergleich.
- Latenz vom Zeitstempel des `keyDown` (`CGEvent.timestamp`) bis zur Rueckkehr des Schreibzugriffs,
  p95 ueber 200 Tipp-Phasen:

  | Geraet | Ziel |
  |---|---|
  | Eingebautes Mikrofon | unter 5 ms |
  | USB | unter 15 ms (USB-Control-Transfer, nicht beeinflussbar) |
  | Bluetooth | kein Ziel; Lautstaerke geht per Funk ans Headset |

  Die 5 ms sind **zu verifizieren**; der Grossteil der Zeit liegt in `coreaudiod` und im Treiber, nicht
  in AltTab+. Erreicht der Messwert das Ziel nicht, wird es nach Messung angepasst, nicht durch
  Aufweichen von TM-03.
- Die Latenz betrifft nur den **ersten** Anschlag einer Tipp-Phase; alle weiteren fallen in die
  laufende Stummschaltung. Auch bei 5 ms rutscht der Anfang des ersten Klicks durch, weil der Klick
  praktisch zeitgleich mit `keyDown` entsteht. Bekannte Grenze des Prinzips, auch bei Unclack.
- Debug-Profil zeigt Median und p95 der Latenz je Geraet, ohne Tasteninformation (TM-08).
- Idle mit Funktion an und ohne laufendes Mikrofon: keine zusaetzlichen Wakeups gegenueber Funktion aus.

## Fehlerfaelle

| Fall | Verhalten |
|---|---|
| CoreAudio-Schreibfehler beim Stummschalten | Geraet nicht in Ownership aufnehmen, Warnung im Log (ohne Tasteninfo) |
| CoreAudio-Schreibfehler beim Freigeben | Einmal nach 100 ms wiederholen, danach Marker behalten und sichtbar im Debug-Profil melden |
| Geraet wird waehrend `holding` abgesteckt | Aus Ownership entfernen, Marker aktualisieren |
| SecureInput aktiv (Passwortfeld) | Der Tap sieht keine `keyDown`; keine Stummschaltung. Bekannte, akzeptierte Grenze |
| Tap wird vom System deaktiviert | Laufende Phase ueber den normalen Timer freigeben; Recovery nach Q-04 |
| `kill -9` waehrend `holding` | Mikrofon bleibt bis zum naechsten Start stumm; Start gibt frei (TM-07) |

## Umsetzungsstufen

1. `TypingMuteTestable` mit Unit-Tests fuer die Tabelle in [Zustandsmodell](#zustandsmodell).
2. `TypingMute` mit Ownership, Timer, Marker; Anbindung an den Keyboard-Tap; Schalter in den Settings.
3. Aktivierung nur bei laufendem Mikrofon (`IsRunningSomewhere`-Listener).
4. Integration `AudioMute.toggle` / `isMuted`, Panic, Quit, Safe Mode.

Stufe 1 und 2 zusammen sind auslieferbar, solange Stufe 4 vor dem Merge folgt.

## Nicht in v1

- Akustische Erkennung von Tastengeraeuschen im Mikrofonsignal (echte Geraeuschunterdrueckung).
- Ausnahmeliste pro App oder pro Tastatur (z. B. leise externe Tastatur).
- Push-to-talk und dessen Umkehrung.
- Mausklicks als Ausloeser.

## Akzeptanz

- Funktion an, Call laeuft: Tippen schaltet das Mikrofon stumm, 400 ms nach der letzten Taste ist es
  wieder offen.
- Funktion an, kein Call: Tippen aendert keine CoreAudio-Property, und es existiert kein Timer.
- Nutzer hat das Mikrofon stummgeschaltet und tippt: nach dem Tippen bleibt es stumm.
- Mikrofontaste waehrend einer Tipp-Phase: Mikrofon bleibt stumm, auch nach Ablauf der Frist.
- `MicMuteIndicator` flackert beim Tippen nicht.
- Teams-Call mit `teamsMuteSync` an: der Teams-Mute-Knopf wird beim Tippen nie gedrueckt, auch nicht
  bei mehr als 20 s ununterbrochenem Tippen (mindestens zwei Timer-Ticks).
- Teams-Call mit `teamsMuteSync` an, Mikrofontaste waehrend einer Tipp-Phase: Teams zeigt danach
  „Unmute mic“; ein zweiter Druck gibt System und Teams wieder frei.
- Mikrofon ohne Mute-Property (Lautstaerke-Weg), Mikrofontaste waehrend einer Tipp-Phase, danach
  erneut: die Eingangslautstaerke ist wieder auf dem Wert vor der Tipp-Phase.
- Zweites, unbenutztes Mikrofon vom Nutzer stumm, Tippen im Teams-Call: Teams wird nicht stummgeschaltet.
- Teams-Call, eingebautes Mikrofon, Tippen: Teams zeigt keinen Hinweis „Dein Mikrofon ist stumm“.
- Eingebautes Mikrofon: p95 der Latenz nach [Budgets](#budgets) unter 5 ms, abgelesen im Debug-Profil.
- `keyDown` im Zustand `idle` fuehrt ausser den Schreibzugriffen keinen CoreAudio-Aufruf aus
  (pruefbar ueber einen Zaehler im Debug-Build).
- `kill -9` waehrend einer Tipp-Phase, danach Neustart von AltTab+: Mikrofon ist offen.
- Panic-Kill-Switch waehrend einer Tipp-Phase: Mikrofon sofort offen.
- Gehaltene Taste (Autorepeat) loest nach dem ersten Anschlag keine weiteren Schreibzugriffe aus.
- Log und Debug-Profil enthalten keine Tastencodes.

## Offene Fragen

- Reicht `kAudioDevicePropertyDeviceIsRunningSomewhere` fuer Apps, die das Mikrofon dauerhaft offen
  halten (z. B. Diktat im Hintergrund), oder braucht es eine Liste von Call-Apps als Zusatzbedingung?
- Zeigt Teams den Stumm-Hinweis auch bei Eingangslautstaerke 0? Falls ja, gibt es ohne virtuelles
  Audiogeraet keinen hinweisfreien Weg; dann Funktion pausieren, solange ein
  `com.microsoft.teams2.`-Prozess aufnimmt, und das im UI sagen.
- Aendert der Teams-Media-Stack mit „Mikrofonempfindlichkeit automatisch anpassen“ die
  System-Eingangslautstaerke? Falls ja, kaempft er gegen den Lautstaerke-Weg; TypingMute gibt dann nach
  (externe Aenderung), die Stummschaltung ist in diesem Moment wirkungslos.
- Ist Eingangslautstaerke 0 beim eingebauten Mikrofon echte Stille oder nur sehr leise? Messen; Ziel
  unter −60 dBFS fuer einen Tastenklick.
- Zeigen Zoom und Meet bei gesetzter Mute-Property ebenfalls einen Hinweis? (**zu verifizieren**)
- Haelt Teams das Mikrofon auch dann offen (`IsRunningSomewhere`), wenn es in Teams stumm ist? Falls ja,
  schaltet TypingMute unnoetig; harmlos, aber vermeidbar, indem TypingMute den zuletzt von
  `TeamsMuteSync` gelesenen Knopfzustand mitnutzt. Nicht in v1, weil `TeamsMuteSync` den Zustand heute
  nur bei eingeschalteter Einstellung und nur alle 10 s kennt.
- Soll die Tipp-Stummschaltung im Menueleisten-Icon sichtbar sein (z. B. gedimmtes Mikrofon), oder
  bleibt sie unsichtbar?
- Hat das schnelle Umschalten von Lautstaerke oder Mute-Property bei Bluetooth-Headsets hoerbare Artefakte oder
  Profilwechsel (HFP/A2DP)?
