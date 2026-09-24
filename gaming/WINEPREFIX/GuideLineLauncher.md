# WINEPREFIX — Wine-prefix templates voor gedeelde games

Dit systeem laat meerdere gebruikers dezelfde Windows-games draaien vanaf de NFS-share,
zonder dat elke game per gebruiker geïnstalleerd hoeft te worden.

## Kernprincipe

- **Games** staan **op de NFS-share**, gedeeld en leesbaar voor iedereen:
  `WINDOWSGAMES/<Game>/`
- **Wine-prefixen** worden **lokaal en VERS** aangemaakt in `~/GAMEPREFIXES/<Game>/`
  via `wineboot -i` (+ Proton-upgrade als de game via Proton start). Er wordt
  **nooit** een bestaande prefix gekopieerd.
- **Scripts** staan op de share en zijn **modulair**: één keer geschreven, per game
  alleen de game-specifieke config. De scripts zijn de basis/motor van dit systeem
  en werken volledig zelfstandig, zonder GUI.

De reden dat prefixen per gebruiker lokaal moeten staan is door testen vastgesteld:
**alleen de gebruiker die eigenaar is van een prefix kan die prefix starten.**
Prefixen op de NFS-share (zoals de oude `pfx.noa/`, `pfx.djuga/` mapjes) geven
bovendien lock-problemen onder Wine. Daarom: game lees je van de share,
de prefix wordt lokaal eigendom van de speler.

## Richtlijnen: hoe een launcher afleiden

Deze regels zijn de kern van het bouwen — ze gelden voor **elke** game, met of zonder gegeven prefix.

1. **Gegeven prefix = analyse, nooit kopiëren.**  
   Een share-prefix (`movedprefixes/`, `protonprefix/`) is *alleen* onderzoeksmateriaal. Je begint **altijd** met een schone, verse lokale prefix (`wineboot -i`). Kopiëren/linken is verboden.

2. **Start minimaal.**  
   De standaard is: kale wine-prefix + de juiste Windows-versie (`winecfg -v win10` of `win7`). Alleen wat de game laat *werken*, mag erbij.

3. **Voeg componenten één voor één toe en test na elke stap.**  
   Nooit de hele gegeven prefix in één keer "nachtrellen". Toevoegen → testen (launch → log + exitcode) → volgende. Alleen wat bewezen nodig is, blijft.

4. **Gegeven prefixen bevatten overtollige rommel.**  
   Ze zijn het resultaat van een proces van "bijvullen tot de game het doet". Wat erin staat, is **niet** vanzelfsprekend nodig. Historische laagjes (oude Proton-versies, overbodige hooks, verkeerde Windows-versie) zitten er vaak nog in.

5. **Minimalisme is het doel.**  
   Vaak is een kale wine-prefix met de juiste Windows-versie al genoeg (zoals Automation Empire). Over-engineering breekt simpele games.

### Referentie-mappen (`movedprefixes/`, `protonprefix/`) — géén runtime-afhankelijkheid

Op de share staan (nog) oude prefix-mappen (`WINEPREFIX/movedprefixes/`,
`PRE-INSTALLED-GAMES/protonprefix/`). Dit zijn **tijdelijk onderzoeksmateriaal**:
ze zijn alleen gebruikt om af te leiden welke extra stappen (hooks, VC++-redists,
appid's) een game nodig heeft. Ze worden **niet** gekopieerd, gelinkt of als
fallback aangeroepen door de scripts, en ze zullen op een gegeven moment van de
server **verwijderd** worden. Elk game-script moet dus blijven werken als deze
mappen niet meer bestaan — dat is ook expliciet getest (verse prefix + Proton
richt zelf alles in). Zie de richtlijnen hierboven voor de analyse-werkwijze.

## Directory-overzicht

```
NFS-share (gedeeld, read-mostly)
└─ PRE-INSTALLED-GAMES/
   ├─ WINDOWSGAMES/<Game>/        → de game zelf (AngryBirds.exe, Cyberpunk2077.exe, Cities.exe, ...)
   └─ WINEPREFIX/
      ├─ README.md                → deze documentatie
      └─ template-scripts/        → MODULAIRE LAUNCHER-SCRIPTS
         ├─ game-core/
         │  └─ game-common.sh        → HERBRUIKBARE CORE (provision, launch, marker, desktop, Proton-detectie)
         ├─ game-launchers/
         │  ├─ angry-birds.sh        → dun script: wine-mode, geen Proton nodig
         │  ├─ cyberpunk2077.sh      → dun script: Proton-runner + install_vcrun2019-hook
         │  ├─ citiesskylines.sh     → dun script: Proton-runner, geen hooks nodig
         │  └─ automationempire.sh   → standalone: kale wine + win10, geen hooks/libs (minimaal recept)
         └─ tools/
            └─ install-proton.sh     → generiek: installeert/update GE-Proton voor alle games

Lokaal (per gebruiker, eigenaar)
└─ ~/GAMEPREFIXES/
   └─ <Game>/
      ├─ pfx/                     → de eigenlijke Wine-prefix (vers aangemaakt)
      ├─ compatdata/<appid>/      → alleen bij Proton-games (symlink naar pfx/)
      └─ .provisioned             → marker: "provision is al uitgevoerd (versie X)"
```

## Hoe een game start (per gebruiker)

1. De gebruiker draait bijvoorbeeld:
   ```bash
   /mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINEPREFIX/template-scripts/game-launchers/angry-birds.sh
   ```
2. Het script roept de core aan; de core controleert of
   `~/GAMEPREFIXES/AngryBirds/.provisioned` bestaat en of de versie klopt.
   - **Niet bestaat (of oude versie)** → prefix lokaal en **vers** aanmaken
     (`wineboot -i`, eventuele extra stappen zoals VC++2019 via `PROVISION_HOOKS`),
     eigenaar = huidige gebruiker, marker schrijven. Bij Proton-games richt
     Proton bij de eerste start zelf de rest in ("Upgrading prefix from None
     to GE-Proton...") — dxvk/vkd3d/nvapi/ntsync.
   - **Bestaat al** → direct door naar het starten van de game.
   - Er wordt ook meteen een `.desktop`-icoon aangemaakt/bijgewerkt.
3. De game draait dus vanaf de NFS-share, de prefix staat lokaal.
4. **Na de eerste keer provisionen is er geen script/terminal/GUI meer nodig** —
   het `.desktop`-icoon start de game direct met de lokale prefix.

## Modulair ontwerp (belangrijk)

**Alles wat je vaker dan één keer gebruikt, zit in de core — niet in het per-game script.**

`game-common.sh` (core) bevindt zich in `template-scripts/game-core/` en bevat
uitsluitend generieke functies:
- `game_init`                    → variabelen normaliseren, paden afleiden
- `game_needs_provision`        → checkt de marker `$PREFIX_DIR/.provisioned`
- `game_provision`              → prefix **vers** aanmaken (`wineboot -i` + optionele hooks)
- `game_launch`                 → start via `wine` **of** via de Proton-runner (`PROTON_ENABLED=1`)
- `_detect_proton` / `_warn_missing_proton` → zoekt een GE-Proton-runner (PROTON_PIN → hoogste
  GE-Proton → Steam-Proton → umu-run); generieke foutmelding (verwijst naar `tools/install-proton.sh`)
  als er geen gevonden wordt — werkt voor élke game, gebruikt `$GAME_NAME`.
- `game_reprovision`            → marker-versie ≠ script-versie ⇒ opnieuw (vers) provisionen
- `game_make_desktop`           → `.desktop`-shortcut aanmaken; doelmap instelbaar (voor een
  latere GUI die de gebruiker de plek laat kiezen)

Per-game script is daardoor superdun; voorbeeld `angry-birds.sh`
(`template-scripts/game-launchers/`):

```bash
#!/bin/bash
export GAME_NAME="AngryBirds"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/Angrybirds"
export GAME_EXE="$GAME_DIR/AngryBirds.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"

source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"
```

Een wijziging aan de provision/launch-logica voer je **één keer** door in
`game-common.sh`; elke game neemt die automatisch over.

### Proton-opties (voor DirectX 11/12-games)

```bash
export PROTON_ENABLED="1"                # start via Proton-runner i.p.v. gewone wine
export PROTON_PIN="GE-Proton11-7"        # bewezen werkende versie; anders auto-detect
export STEAM_APPID="1091500"             # echte Steam-appid — nodig voor ProtonFixes
                                          # (anders IndexError bij een gamenaam zonder cijfers)
```
Ontbreekt Proton? Dan verwijst de generieke foutmelding naar
`tools/install-proton.sh` (downloadt/installeert automatisch de laatste
GE-Proton naar `~/.config/heroic/tools/proton/`, en maakt een
`InstallProton`-snelkoppeling).

### Optionele extra stappen per game (hooks)

Sommige games hebben extra onderdelen nodig in de prefix. Dit regelen we via
`PROVISION_HOOKS`, bijvoorbeeld:

```bash
export PROVISION_HOOKS=("install_vcrun2019" "install_vkd3d")
```

De core definieert de hooks; het per-game script kiest welke het nodig heeft.

## Exceptions-catalogus (wat je kunt toevoegen, met signaal)

| Onderdeel / uitzondering | Hook / optie | Wanneer nodig (signaal in log/game) |
|--------------------------|--------------|-------------------------------------|
| Windows-versie win7 | `VC_RUNTIME_WINVER="win7"` of `install_win7.sh` | Game crasht op win10 (bv. "Invalid window handle" na swapchain) |
| VC++ 2019 runtime | `install_vcrun2019` (methode `winetricks`/`redist`) | `c000007b`, DLL-not-found `msvcp140`/`vcruntime140`, `_CommonRedist/vcredist` in gamemap |
| DirectX 9 / d3dx9 / XAudio / XInput legacy | `install_d3dx9` | Oude D3D9-games, Unity < 2017, "d3dx9_43.dll not found" |
| .NET Framework 4.8 | `install_dotnet48` | Launcher/installer vereist .NET, crash met CLR-fout |
| Core fonts (Tahoma, Verdana, etc.) | `install_corefonts` | Tekst ontbreekt/vierkanten in menu's |
| Proton (D3D11/12 via DXVK/VKD3D) | `PROTON_ENABLED=1` + `PROTON_PIN` | Renderer = D3D11/12, Vulkan/ICD nodig, ProtonFixes database |
| Eigen DXVK in prefix | `install_dxvk` | Specifieke DXVK-versie nodig, Proton's graft breekt game |
| VKD3D (D3D12→Vulkan) | `install_vkd3d` | D3D12-games zonder Proton, of Proton's VKD3D te oud |
| gamescope-wrap (Wayland exclusive-FS fix) | `GAME_GAMESCOPE=1` + `install_gamescope` | AMD/Wayland: zwart scherm, focus-stall, "Exclusive FS: 1" in DXVK-log |
| toetsenbord fix (joystick-negering) | `disable_winebus` (pre-launch) | Game negeert toetsenbord zodra joystick-device gezien wordt |
| Wacom/joystick interactief uitsluiten | `wacom-detect` | Specifieke hardware die als joystick gemaskeerd wordt |
| Gamepad XInput via root (udev/hidraw) | `tools/pad-xinput-on.sh` | XInput-only game, pad werkt op OS (evdev) maar niet in-game |
| Overlays (MangoHud/vkBasalt) uitzetten | default `GAME_KEEP_OVERLAYS=0` | FPS-meter/HUD breekt Vulkan-init (Cyberpunk, AE, andere) |
| Steam-appid / emu (CODEX/MEX/Goldberg) | `STEAM_APPID`, `tools/steam-nonsteam-fix.sh` | `steam_appid.txt` in gamemap, crack/emu DLL's (`steam_api64.dll`, `steamclient64.dll`, etc.) |

## Onbekende game **zonder** prefix: bouwstappen

1. **Begin met het dunste template** (AngryBirds-vorm): `PROTON_ENABLED=0`, lege `PROVISION_HOOKS`, `CREATE_DESKTOP_SHORTCUT=1`.
2. **Snelclassificatie** van de game-map:
   - **Renderer**: OpenGL/D3D9 → plain wine; D3D11/12 → Proton. Check via `file` op exe, `strings` op DLL's, of `vulkaninfo`/`apiVersion` scan.
   - **Engine**: Unity (Mono/IL2CPP), Unreal, custom → beïnvloedt Mono/IL2CPP runtime, managed DLL's.
   - **Crack/emu**: CODEX/MEX/Goldberg/STEAMWORKS → `STEAM_APPID` + DLL-overrides voor emu-DLL's.
   - **Redists**: `_CommonRedist/` aanwezig? → VC++/DirectX/.NET hooks waarschijnlijk nodig.
3. **Symptoom → fix tabel** (één variabele per run wijzigen, testen na elke stap):
   - `exit c000007b` / DLL-not-found msvcp → `install_vcrun2019`
   - stil na swapchain / "Invalid window handle" → `install_win7` / win7, of Proton-versie
   - zwart scherm + exclusive-FS log → `GAME_GAMESCOPE=1` + `install_gamescope`
   - `steam_api64.dll` load fail / "No access to memory location" → emu-DLL-overrides + overlays uit
   - toetsenbord doet niks → `disable_winebus` (pre-launch)
   - Vulkan init crash met FPS-meter → overlays uit (`GAME_KEEP_OVERLAYS=0` al default)
4. **Werkwijze**: na elke wijziging → launch → log + exitcode analyseren → volgende component. Precies zoals de Automation Empire-procedure: begin minimaal, bouw één voor één.

## Per-game recepten

Concrete per-game recepten (config, hooks, exceptions) staan **in de launcher-scripts zelf** als commentaar, en in de werklog hieronder — niet in deze gids. Dit houdt de gids generiek en herbruikbaar.


## Steam non-Steam-fusie (het "Forza"-probleem) — samenvatting

**Feit (2026‑09‑20): de fusie is omzeilbaar.** De fusie staat of valt bij één
variabele: een **onbezeten echt store-appid** in `steam_appid.txt`. De omzeiling
is daardoor simpel — het bestand neutraliseren (rename → `steam_appid.txt.disabled`):
de game valt dan vanzelf terug op de bewezen pseudo-appid-route, zonder dat er
iets aan Steam zelf veranderd hoeft te worden. Status: **afgeleid uit eigen
logs + bestands/VDF-onderzoek (2026‑09)**; een gecontroleerde A/B-runtest
(steam_appid.txt = 261570 vs 480) kan dit desgewenst later nog van "afgeleid"
naar "bewezen" tillen (optioneel, bij de GUI-integratie).

**Symptoom (2026, zelf ondervonden):** een non-Steam-shortcut van een
repack-game start niet; Steam meldt "game niet gestart / niet geïnstalleerd"
en hamert op installeren/kopen via de officiële winkel; de shortcut raakt
daarna als store-titel "vast" en is lastig terug te draaien.

**Bewijs in de eigen Steam-logs (console-linux.txt, 2026‑05‑20):**
```
13:02:59 chdir ".../Forza-Horizon-5/"
13:02:59 Game Recording - would start recording game 1551360 ...
13:03:01 ProtonFixes ... UNKNOWN (1551360)      ← sessie gebonden aan het echte store-appid
13:03:23 game stopped ...
13:04:30 AppID 1551360 adding PID ...           ← herpoging
13:04:39 AppID 1551360 no longer tracking PID ... exit code -1 (×20)  ← afgebroken door license-gate
13:04:39 Remove 1551360 from running list
```

**Mechanisme (uit de logs afgeleid):**
- De gamemap bevat een **`steam_appid.txt`**. Steam leest dat en **bindt de
  non-Steam-sessie aan het echte store-appid** (bijv. 1551360 = Forza Horizon 5).
- Bezit je dat appid niet → **license-gate**: de procesketen wordt binnen
  seconden afgebroken (`exit -1`) en de shortcut wordt in de client met de
  store-titel vervlochten (vandaar "niet geïnstalleerd / koop het" en de
  moeite om de shortcut terug te krijgen).
- Games **zonder** `steam_appid.txt` in de map draaien daarentegen als
  **pseudo-appid** (bv. `14879414305781972992`, `5208010`, `4157105450` zichtbaar
  in de logs) → **geen fusie, geen license-gate** → non-Steam-shortcuts werk.

**Betekenis voor deze collectie** (gescand 2026‑09):
- Conflict-dragers (bestand aanwezig → Forza-patroon als je ze als Steam-shortcut
  toevoegt zonder dat je het appid bezit): **Eve Online (8500)**,
  **AOW.Planetfall (718850)** en **Ori_atwotw (1057090)**.
- **Ori: Blind Forest** heeft géén bestand → al fusie-veilig.
- **Ori: WOTW** (**Ori_atwotw**): was een conflict-drager (=`1057090`, onbezeten);
  het bestand is op 2026‑09‑20 **geneutraliseerd** (→ `steam_appid.txt.disabled`)
  via de nieuwe tool `tools/steam-nonsteam-fix.sh` — voor de game inert
  (standalone pc-build, geen steam/emu-dlls), voor Steam geen fuseerbaar appid
  meer. De launcher voedt de appid al via env (`export STEAM_APPID=1057090`);
  Proton/ProtonFixes houdt daarmee z'n identiteit ("UNKNOWN (1057090)" in de
  eerste-run-log bevestigt dat de env-drager werkt). Terugzetten: de tool
  `restore`.
- "Het bestand weg ⇒ game start niet" is **niet** waar voor deze repacks; alleen
  echte Steamworks-licenties hebben het appid hard nodig, en die zitten hier niet.

**Gevolg voor de workflow:** de launcher-scripts hoeven niets op de Steam-route
te weten (zij draaien Proton direct, zonder de Steam-client-license-gate). De
Steam-shortcut-route incl. SteamInput/pad wordt **later bij de GUI** ingebouwd —
met als vuistregel: geen `steam_appid.txt` = veilig; aanwezig + niet bezeten =
Forza-patroon. Apart blijft de wrap-afhankelijkheid (exclusive-FS op
AMD/Wayland): díe bepaalt of een game óók zonder wrap via Steam zou stallen.

## Eigenaarschap & permissies

- Prefixen worden op lokale schijf aangemaakt → eigenaar is automatisch de
  gebruiker die de game start. Dit is bewust; het is de enige betrouwbare
  manier waarop Wine-prefixen correct werken.
- Scripts op de share: leesbaar voor de hele groep; uitvoerbaar maken met
  `chmod +x`.

## GUI-voornemen (later, nu niet belangrijk)

**De werking via de scripts is de basis; de GUI is nu niet belangrijk.** Zodra
er een Python-GUI komt, is die uitsluitend een **gebruiksvriendelijke
opstarthelper**: een venster met een selector van spelletjes; bij kiezen wordt
het bijbehorende `game-launchers/<game>.sh`-script aangeroepen (dat zelf de
prefix aanmaakt indien nodig, en anders direct start).

**Zodra de prefix eenmaal is aangemaakt, heeft de gebruiker de GUI niet meer
nodig** — het `.desktop`-icoon (dat de scripts al automatisch aanmaken) start
de game direct met de lokale prefix, zonder terminal of GUI.

---

## Werklog / status (compaction-samenvatting)

> Opgeslagen als geheugen voor volgende sessies; hier staat waar het systeem
> mee bezig is, wat bewezen is en wat de volgende stappen zijn.

### Doel (lopend werk)

Cyberpunk 2077 is afgerond en gedocumenteerd (werklog hieronder); resultaat
bevestigd door gebruiker. Nieuwe spellen volgen hetzelfde patroon. Cities:
Skylines op AMD/Wayland is ook afgerond; daarbij werd de gamescope-wrap een
generieke core-optie (`GAME_GAMESCOPE` + `GAME_GAMESCOPE_RES`) in plaats van een
per-game hack.

### Nooit vergeten

- **Geen sudo / root** in de scripts; de gebruiker is de interactor en klikt
  zelf (kdialog/zenity) Ja of Nee. Overrides voor een latere GUI bestaan al:
  `WACOM_CHOICE=ja|nee`.
- **Geen backup-logica in de wacom-module** — backups doet de core
  (`_snapshot_backup` → `template-scripts/backup/`, ver1→ver3-rotatie).
  Debug-logs horen in `/tmp` (alleen voor de agent).
- **`tools/ask-yesno.sh`** is de herbruikbare Ja/Nee-vrager
  (TTY→kdialog→zenity→notify-send; exit 0=ja, 1=nee, 2=geen methode).
- **`disable_winebus`** (historisch: `Enable SDL=0` + `DisableHidraw=1`) maakte
  de toetsen ooit werkend, maar schakelde óók alle echte gamepads uit. De nu
  bewezen variant zet **alleen `Enable SDL=0`** (hidraw blijft aan) → toetsenbord
  werkt. Let op de nuance (gamepad-analyse, 2026-09): "better gamepads blijven
  werken via XInput/hidraw" geldt alleen zolang Wine die hint-route fysiek kan
  bereiken; op deze machine ontbreekt dat (geen hidraw-node voor de pad,
  `/dev/hidraw*` root-only), dus de pad speelt wél op OS-niveau, maar niet in
  XInput-only-games zoals Cyberpunk.
- **`WACOM_CHOICE` als env-var is NIET de bedoeling van de flow** — de knoop
  zelf moet bij elke start getoond worden, anders is de flow "niet zoals
  bedoeld".
- Bash-tool van de agent doodt achtergrondprocessen bij terugkeer (SIGHUP) →
  persistente runs via `setsid`/`nohup`. `pkill -f wine/proton` matcht de eigen
  shell → hang; zelf-matchende patronen vermijden of `-x` gebruiken.
- `_provision_fresh` wist een bestaande prefix niet zelf; voor een échte verse
  provision eerst `rm -rf ~/GAMEPREFIXES/<Game>`.
- **AMD/RADV + XWayland + DXVK exclusive-FS:** de game presenteert niet naar
  voren (zwart scherm, focus-stall) → **gamescope-wrap is de standaard-fix**
  (`GAME_GAMESCOPE=1`, optioneel `GAME_GAMESCOPE_RES` tegen het 720p-verlies).
  NVIDIA-machines hebben dit issue niet (bewezen op de GTX-1070-rij).

### Verifieerbare feiten

- **Hardware:** De game ziet eender welk joystick-achtig device als
  "controller" en negeert dan toetsenbord/muis. Op deze machine zijn er
  minstens twee "valse": een **Wacom Intuos BT M (056a:0378)** die joydev als
  js* exposeert, en de **eigen Lenovo-toetsenbord-js (17ef:6099,
  `ID_INPUT_KEY=1`)** die er altijd in zit — vandaar dat "Wacom los" nooit
  genoeg is. Echte gamepad: **Holtek (045e:028e, `ID_INPUT_JOYSTICK=1`)**.
- **Eerste succesvolle launch (referentie):** werkte destijds wél met zowel
  Wacom als gamepad in de USB-poorten → er is tussentijds iets veranderd;
  dit onderscheid telt mee bij het zoeken naar de oorzaak.
- **v16-launcher:** `PROVISION_HOOKS=("install_gamescope" "install_vcrun2019"
  "wacom-detect")`, `PROTON_PIN="GE-Proton11-7"`, `GAME_GAMESCOPE="1"`,
  `VC_RUNTIME_METHOD="redist"`, `STEAM_APPID="1091500"`. v15-regressie
  (geen vcrun/PIN/gamescope → stille stop, laatste regel *"Failed loading SDL3
  library."*) is daarmee gerepareerd.
- **Hook `wacom-detect` bewerkt in de praktijk:** bij Ja wordt de Wacom fysiek
  losgekoppeld en bevestigt de hook dat ("Wacom losgekoppeld — gamepad kan nu
  werken"); log-regel verschijnt netjes vóór de game-start.

### Status

- ✅ `wacom-detect.sh` (hooks/) gebouwd en los getest: `_wacom_present`,
  `_wacom_as_joystick` (vindt `js0`), `_wacom_await_unplug`
  (`WACOM_WAIT_SEC`, standaard 30 s), `hook_run()`. Beide keuzepaden + timeout
  geverifieerd.
- ✅ cyberpunk2077.sh op v16 gebracht (zie feiten hierboven).
- ✅ v16-provision live geslaagd: backup-snapshot op share, hooks draaiden,
  marker v16, `.desktop`-shortcut, gamescope-wrap actief (Wayland), Proton
  gestart.
- ✅ **OORZAAK + FIX GEVONDEN (2026-09):** de game negeert toetsenbord zodra
  er één joystick-achtig device te zien is, en die machine heeft er altijd
  minstens één: de eigen **Lenovo-toetsenbord-js (17ef:6099, `ID_INPUT_KEY`)**
  plus willekeurige andere (Wacom 056a). Isolatietest bewees: Space dood met
  alleen keyboard-js1 (geen Wacom, geen gamepad). "Wacom los" kan dus nooit
  de fix zijn. **Fix = winebus `Enable SDL=0`** (hidraw blijft aan →
  DisableHidraw wordt NIET meer gezet, dat schakelde ook alle gamepads uit);
  echte gamepads (045e, `ID_INPUT_JOYSTICK`) blijven via XInput/hidraw
  werken. SDL-env-hints (`SDL_GAMECONTROLLER_IGNORE_DEVICES` e.d.) worden
  niet door de game gehonoreerd.
- ✅ **Test D (bewijs Wacom-onafhankelijkheid):** `Enable SDL=0` + Wacom erin
  (ja, ook met pad) → Space werkt, óók wanneer de keuze-dialoog met "Nee"
  wordt beantwoord. Conclusie: wacom-detect-flow is voor Cyberpunk overbodig;
  `wacom-detect.sh` blijft bestaan als herbruikbare interactieve module voor
  andere hosts/games.
- ✅ **GAMEPAD-ANALYSE (2026-09, afgerond):** pad (045e:028e, "Microsoft
  X-Box 360 pad") werkt op OS-niveau volledig (A/B/X/Y, LB/RB, L3/R3,
  Select/Start, beide sticks vol bereik, triggers, D-pad — bewezen via evdev).
  Maar in Cyberpunk heeft hij **geen werkende route**:
  - XInput/hidraw-route dood: de pad heeft géén hidraw-node (xpad-driver
    claimt het USB-interface) en `/dev/hidraw*` is `0600` root → winebus:
    `Unable to open "/dev/hidraw0", Permission denied`. Zonder leesbare
    hidraw bouwt Wine geen XInput-controller → Cyberpunk (XInput-only) ziet
    geen gamepad.
  - SDL/evdev-joystick-route faalt: met `Enable SDL=1` breekt het
    toetsenbord in élke variant (met/zonder `SDL_GAMECONTROLLER_IGNORE_DEVICES`,
    `EXCEPT`, `BLACKLIST` — getest in runs X/Y/Z) en krijgt de pad nog steeds
    geen device (`evdev event3: deferring ... to a different backend`, waarna
    niets wordt aangemaakt). `SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT` zet de
    pad nota bene zélf op de negeren-lijst (verkeerde SDL2-semantiek).
  - Einde: standaard terug op de bewezen staat **`Enable SDL=0`** (toetsenbord
    werkt). Strikt XInput-in-game zou een echte XInput-bron vereisen:
    eenmalige udev-rule (root) die hidraw 045e:028e leesbaar maakt, óf
    Steam/SteamInput-overlay.
  - ✅ **Nieuwe vondst (vervolg 2026-09):** een schone SDL-context (géén
    SDL-hint-env) laadt de pad WEL als winebus-device met `is_gamepad 1`
    (bewezen in een 20s-winebus-probe):
    `bus_create_hid_device desc {vid 045e, pid 028e, is_gamepad 1, ...}`.
    De eerder gebruikte SDL-hints (`SDL_GAMECONTROLLER_IGNORE_DEVICES(Exception)`)
    waren zélf het gif: de EXCEPT-variant zette de pad óp de negeren-lijst.
    Paspoort: gamepad-modus is dus zonder root mogelijk — ten koste van het
    toetsenbord (game schakelt naar controllermodus; keyboard valt uit).
  - ✅ **Losse handmatige tool** `tools/cyberpunk_gamepad.sh`
    (`status|probe|on|off`), géén onderdeel van de workflow: `on` zet
    `.pad-mode`-marker + `Enable SDL=1` (de drift-guard in disable_winebus
    slaat dan bewust over), `off` doet het omgekeerde. Standaard blijft
    toetsenbordmodus; padmodus is opt-in en in-game-nog-te-bevestigen.
- ✅ Launcher v17: `SCRIPT_VERSION="17"`,
  `PROVISION_HOOKS=("install_gamescope" "install_vcrun2019" "disable_winebus")`
  én `PRE_LAUNCH_HOOKS=("disable_winebus")` als drift-guard → `Enable SDL=0`
  staat bij élke start gegarandeerd (en blijft staan als de registry ooit weer
  wordt omgezet).
- ✅ **CITIES: SKYLINES (2026-09, afgerond):** launcher v2 (GE-Proton11-7,
  appid 255710, verse prefix) start op de NVIDIA/GTX-1070-machine direct, maar
  op deze AMD/Wayland-machine: zwarte spinner, venster kwam niet naar voren, en
  gamescope patchte het interne beeld naar 720p. Fixes:
  - `GAME_GAMESCOPE=1` → gamescope-wrap lost de present/focus-stall op
    (XWayland + RADV + DXVK exclusive-FS; NVIDIA had het niet).
  - `GAME_GAMESCOPE_RES` → nu leeg/uit in de launcher → **core auto-detect**
    van de actieve monitormode via xrandr (op deze machine 1920x1080); pin
    optioneel met een expliciete "WxH"-export. Gamescope pakt daardoor nooit
    meer zelf een 720p-mode.
  - `dxvk.conf` naast de game-exe: `dxvk.numCompilerThreads = 4` +
    `dxvk.enableGraphicsPipelineLibrary = True` → shader-compile piekte vóór
    tot ~195% CPU gedurende minuten; nu een korte piek en snel aan het menu.
  - Boot-bevestiging door gebruiker: zwart+spinner → blauwe logo → witte logo →
    hoofdmenu. Exit: verloopt netjes zolang je Proton de paar tellen teardown
    gunt (`Destroying swapchain` → `Primary child shut down` → alles weg); te
    snel de taakbalk gebruiken = schijncrash.
  - Prefix met warme DXVK-cache bewust behouden i.p.v. verse provision.
  - `PROVISION_HOOKS=(install_gamescope)` toegevoegd voor verse machines
    (skip als al aanwezig / geen root → melding; géén re-provision van deze
    prefix, want de marker vergelijkt alleen SCRIPT_VERSION).
- ✅ **ORI-WOTW (2026-09, afgerond):** `ori-willofthewisps.sh` (v1, dun).
  Verse prefix `OriWillOfTheWisps` (.provisioned=1). Unity **IL2CPP**
  PC-build standalone; gamescope-wrap + res auto (1080p/240Hz aangemaakt);
  boot→menu vlot, idle ~5%, gebruiker: "ging smooth". Referentie-prefix
  (movedprefixes/1057090.ori_atwotw) gebruikte winetricks d3dx9/10/11_43 +
  dxvk + vcrun6 → onder modern Proton NIET nodig.
  Gamepad-onderzoek (na "gamepad-game?"): Óri is ontworpen rond de controller
  maar KBM is volwaardig/aanbevolen (WOTW: XInput-only + schakelt naar
  controllermodus als een Xinput-pad aanwezig is → KB dan ondergeschikt;
  BF: XInput én DirectInput, maar DInput-mapping van de originele build is
  berucht gebroken). Pad-in-game = root-route (xpad weg + udev-hidraw |
  hidraw leesbaar) of SteamInput; SDL-only levert bij WOTW niets en bij BF
  een gebroken DInput-layout.
- ✅ **ORI-BF (2026-09, bezig→afronding):** `ori-blindforest.sh` — CODEX
  origineel (261570), 32-bit Unity5-Mono `ori.exe`; gamescope-wrap
  (exclusive-FS in oude d3d11-log); verse prefix `OriBlindForest`. Eerste
  run hing ("hang na ~5s, Primary child shut down"); referentierun
  2026-09-20 herhaalde dat NIET: `ori.exe` >2 min stabiel, titel/menu
  zichtbaar en stabiel (gebruiker bevestigd). Voorafgaande hang dus niet
  gereproduceerd; diffuse/perifere oorzaak (niet pad, wél mogelijk
  vóór PROTON_PIN-pinning). Speeltest door gebruiker resteert.
- ✅ **STEAM-TOOLS (2026-09-20, nieuw):** bij de non-Steam-fusie-route
  gebouwde toolset (alle in `tools/`):
  - `steam-nonsteam-fix.sh` — inspect | neutralise | restore | fake |
    scan | boom (--dry-run, --appid, --len). Eerste echte toepassing:
    WOTW's `steam_appid.txt` (1057090) op 2026-09-20 geneutraliseerd.
    Scan (2026-09, WINDOWSGAMES): conflict-dragers Eve Online (8500) en
    AOW.Planetfall (718850 + steam_api64.dll).
  - `appid.fromname.sh` — naam→appid (Digital-root-condensering, standaard
    8 cijfers, `-l <len>` voor BF's 261570-formaat; 10/10 cross-check tegen
    `appid.numerator.py` incl. reverse). `appid.numerator.reverse.py` =
    reverse-lookup van die methode.
  - `steam-shortcut-cleanup.sh` — list | verify | remove <naam> (--commit/
    --force/--file). Punt: shortcuts.vdf is **binair** VDF → de bewezen
    `vdf`-pythonlib doet load/roundtrip (geverifieerd byte-exact 10499 B) en
    reikt writes uit; `remove` weigert meer dan één match en schrijft
    standaard NIET (dry-run; --commit vereist + Steam gesloten + backup).
    Echt bestand (userdata 203236556): 21 entries; **Forza Horizon 5 (#20)**
    staat er nog in en is klaar voor één-opdracht-verwijdering zodra Steam
    gesloten is — test-verwijdering slaagde op een kopie (20 entries, stabiel).
- ✅ **GAMEPAD-TOOLS (2026-09, nieuw):** de SDL/winebus-route is opgegeven
  en gearchiveerd (backup/): het eigen probe-verdict ("pad krijgt GEEN
  winebus-device") bewees dat hij doodloopt, én XInput-only-titels (Ori,
  Cyberpunk) lezen sowieso alleen een wine-gebouwde XInput-controller.
  Vervanging = root-route als **een bewust los paar tools**:
  `pad-xinput-on.sh` (xpad-driver uit → usbhid/udev → hidraw leesbaar via
  70-pad-xinput.rules; `--shot`=tijdelijk) en `pad-xinput-off.sh`
  (udev-rule weg + xpad terug; idempotent). Worden bewust NIET door
  launchers aangeroepen en doen géén SDL/marker-schoonmaak (die blijft bij
  de launch-time guard `disable_winebus`). Uiteindelijk oproepbaar via GUI.
- ✅ **AUTOMATION EMPIRE (2026-09, afgerond):** `automationempire.sh` — standalone plain-wine launcher (geen core, geen hooks). Kale wine-prefix + `winecfg -v win10` + CODEX `steam_api64.dll` overrides. Referentie-prefix (`movedprefixes/1112790`) bevatte overtollige componenten (Proton/DXVK v2.x, win7, vcrun2019, d3dx9, Steam registry, RUNASADMIN) — **bewezen NIET nodig**. Les: minimalisme afleiden, niet referentie naspelen. Overlays/FPS-meter breekt de game → overlays standaard uit.

### Volgende stappen

1. ✅ `game-common.sh` ondersteunt generiek `PRE_LAUNCH_HOOKS` (zelfde
   array/string-mechaniek als `PROVISION_HOOKS`); hooks lopen vóór
   `game_launch` bij élke run.
2. ✅ `cyberpunk2077.sh`: v17, fix in provision én pre-launch (drift-guard).
3. ✅ Spielverificaatie gamepad: OS-niveau volledig werkend; in-game bewust
   géén pad-pad (zie werklog). Toetsenbord-control lui prima.
4. ✅ Cities: Skylines op deze AMD/Wayland-machine afgerond (gamescope-wrap,
   native 1080p, dxvk.conf parallel-compile) — zie werklog-bullet hierboven.
5. ✅ Ori: Will of the Wisps — launcher klaar en "smooth" bevestigd;
   `steam_appid.txt` geneutraliseerd (fix-tool). Pad-retest vervalt
   (overbodig verklaard); off-cyclus per gebruiker niet nodig.
   Menuslot verschijnt zodra de gebruiker speelt (nog geen slot in saves).
6. 🔄 Ori: Blind Forest — referentierun 2026-09-20: titel/menu stabiel,
   hang niet gereproduceerd. **Speeltest door gebruiker volgt**; daarna
   rij "afgerond".
7. 🔜 Steam non-Steam-fusie-optioneel: A/B-verificatie (261570 vs 480) en
   Forza-#20-shortcut-verwijdering via `steam-shortcut-cleanup.sh`
   (Steam sluiten, `remove "Forza" --commit`). Bedoeld voor GUI-integratie.

### Relevante bestanden

```
template-scripts/game-core/game-common.sh        → core; PRE_LAUNCH_HOOKS gebouwd (idempotente drift-guards)
template-scripts/game-core/hooks/wacom-detect.sh → bewaard als herbruikbare interactieve module (niet meer voor Cyberpunk)
template-scripts/game-core/hooks/disable_winebus.sh → bewezen fix (Enable SDL=0, hidraw aan) — provision én pre-launch
template-scripts/game-core/hooks/install_vcrun2019.sh, install_gamescope.sh → provision hooks
template-scripts/game-launchers/cyberpunk2077.sh → dun launcher-script (v17)
template-scripts/game-launchers/citiesskylines.sh → GAME_GAMESCOPE=1; res auto-detect (xrandr) of pin via GAME_GAMESCOPE_RES
template-scripts/game-launchers/ori-willofthewisps.sh → v1, dun; IL2CPP pc-build standalone (oriandthewillofthewisps-pc.exe)
WINDOWSGAMES/Cities-Skylines-none-Steam/dxvk.conf → numCompilerThreads=4 + enableGraphicsPipelineLibrary=True (in de gamemap)
template-scripts/tools/ask-yesno.sh             → herbruikbare Ja/Nee-vrager
template-scripts/tools/pad-xinput-on.sh         → losse ROOT-tool: Xboxpad als echte XInput (xpad-weg + hidraw + udev-rule; `--shot`=tijdelijke chmod; `status`)
template-scripts/tools/pad-xinput-off.sh        → losse ROOT-tool: ongedaan maken (udev-rule weg + xpad terug); idempotent
template-scripts/tools/steam-nonsteam-fix.sh    → inspect/neutralise/restore/fake/scan/boom (conflict-dragers); toegepast op WOTW (1057090)
template-scripts/tools/appid.fromname.sh        → naam→appid (8 cijfers, `-l <len>`); cross-check met appid.numerator*.py
template-scripts/tools/steam-shortcut-cleanup.sh→ binair-VDF-shortcut-cleanup (list/verify/remove; --commit is dry-run-bewust)
backup/cyberpunk_gamepad.sh.sdl-route.20260920  → gearchiveerde SDL/winebus-route (doodlopend bewezen; vervangen door pad-xinput-*)
backup/gamepad.off.sh.sdl-sweep.20260920        → gearchiveerde SDL/marker-sweep (was niet wat gevraagd was; overbodig na pad-xinput-off)
template-scripts/tools/archive/                 → (overige vervallen tool-ingredienten)
~/GAMEPREFIXES/Cyberpunk2077/                   → lokale prefix (pfx/, compatdata/1091500/, .provisioned=17)
~/GAMEPREFIXES/OriWillOfTheWisps/               → lokale prefix (.provisioned=1), saves in AppData\LocalLow
~/GAMEPREFIXES/OriBlindForest/                  → lokale prefix (.provisioned=1); saves in AppData\Roaming\Steam\CODEX\261570\remote
```

