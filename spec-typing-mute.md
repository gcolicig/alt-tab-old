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
| TM-05 | Eine Tipp-Stummschaltung loest nie `TeamsMuteSync` aus | Sonst drueckt AltTab+ in Teams bei jedem Wort den Mute-Knopf |
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
- Stummschaltung ueber `kAudioDevicePropertyMute`; ohne settable Mute-Property ueber die Eingangs-
  lautstaerke wie in `AudioMute.simulateInputMute`. Der gemerkte Lautstaerkewert gehoert der
  TypingMute-Ownership, nicht `AudioMute.simulatedInputMutes`.
- Ein Geraet, das beim Ausloesen bereits stumm ist, gehoert **nicht** zur Ownership und wird beim
  Freigeben nicht angefasst (TM-04).

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

- `AudioMute.toggle(input: true)` fragt zuerst `TypingMute.surrenderOwnership()`. Liefert das `true`,
  war das Mikrofon nur durch Tippen stumm; der Toggle interpretiert den Ausgangszustand als **nicht
  stumm** und schaltet folglich stumm. Die Geraete bleiben stumm, gehoeren jetzt aber dem Nutzer.
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
| `TeamsMuteSync` | Wird nie aus TypingMute aufgerufen (TM-05). Der 10-s-Abgleich liest `AudioMute.isMuted`, das Tipp-Stummschaltungen ignoriert |
| `MicKey` | Unveraendert; die Taste landet in `AudioMute.toggle` und damit in `surrenderOwnership` |
| `AudioMute.restoreOnQuit` | Ruft zusaetzlich `TypingMute.releaseAll()` auf |
| Panic-Kill-Switch | `disableInputModulesForSafety` ruft `TypingMute.releaseAll()` auf |

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
- Latenz von `keyDown` bis Mikrofon stumm: Ziel unter 15 ms fuer eingebaute Mikrofone. Der erste
  Anschlag einer Tipp-Phase kann trotzdem durchrutschen; das ist eine bekannte Grenze des Prinzips,
  auch bei Unclack.
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
- Teams-Call mit `teamsMuteSync` an: der Teams-Mute-Knopf wird beim Tippen nie gedrueckt.
- `kill -9` waehrend einer Tipp-Phase, danach Neustart von AltTab+: Mikrofon ist offen.
- Panic-Kill-Switch waehrend einer Tipp-Phase: Mikrofon sofort offen.
- Gehaltene Taste (Autorepeat) loest nach dem ersten Anschlag keine weiteren Schreibzugriffe aus.
- Log und Debug-Profil enthalten keine Tastencodes.

## Offene Fragen

- Reicht `kAudioDevicePropertyDeviceIsRunningSomewhere` fuer Apps, die das Mikrofon dauerhaft offen
  halten (z. B. Diktat im Hintergrund), oder braucht es eine Liste von Call-Apps als Zusatzbedingung?
- Reagieren Zoom, Teams und Meet auf ein kurz stummes Hardware-Mikrofon mit einem Hinweis „Mikrofon ist
  stumm“? Falls ja: Lautstaerke-Weg statt Mute-Property bevorzugen (**zu verifizieren**).
- Soll die Tipp-Stummschaltung im Menueleisten-Icon sichtbar sein (z. B. gedimmtes Mikrofon), oder
  bleibt sie unsichtbar?
- Hat das schnelle Umschalten der Mute-Property bei Bluetooth-Headsets hoerbare Artefakte oder
  Profilwechsel (HFP/A2DP)?
