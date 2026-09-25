# WINEPREFIX Workflow — Handleiding

Dit document beschrijft de volledige workflow van het systeem: van **GUI setup** tot **dagelijks gebruik via desktop-shortcuts**.

---

## Architectuur Overzicht

```
NFS-share (read-mostly)
├── WINDOWSGAMES/<Game>/          → Game bestanden (bijv. <Game>.exe)
└── WINEPREFIX/
    ├── template-scripts/
    │   ├── game-core/
    │   │   └── game-common.sh      → CORE: provision, launch, desktop-shortcut
    │   ├── game-launchers/
    │   │   ├── <game-launcher>.sh  → Dun installer/launcher per game
    │   │   └── gameicons/          → Icoons per game (PNG/JPEG)
    │   └── tools/
    └── gui/
        └── game-gui.py             → Éénmalige setup GUI (carousel + terminal)

Lokaal per gebruiker (~)
└── GAMEPREFIXES/<Game>/
    ├── pfx/                        → Wine prefix (vers aangemaakt)
    ├── compatdata/<appid>/         → Symlink naar pfx/ (Proton games)
    └── .provisioned                → Marker: versie van laatste provision
```

---

## Kernprincipes

1. **Games op NFS** — gedeeld, read-only
2. **Prefix lokaal** — `~/GAMEPREFIXES/<Game>/`, eigenaar = gebruiker
3. **Scripts op share** — modulair, herbruikbare core (`game-common.sh`)
4. **Desktop-shortcuts** — gemaakt door de launcher-scripts zelf (met icon + execute-property)
5. **GUI = setup tool** — één keer draaien, daarna niet meer nodig

---

## Levenscyclus van een Game

### 1. Eerste keer (via GUI of direct script)

```
User klikt icoon in GUI (of start launcher-script direct)
                    │
                    ▼
Launcher script start (bijv. <game-launcher>.sh)
                    │
                    ├─▶ Exporteert variabelen: GAME_NAME, GAME_DIR, GAME_EXE, etc.
                    ├─▶ source game-common.sh
                    └─▶ game_main()
                             │
                             ├─▶ game_init()           → paden afleiden, validatie
                             ├─▶ game_needs_provision() → checkt ~/.provisioned marker
                             │       └─▶ NEET → game_provision()
                             │               ├─▶ wineboot -i (verse prefix)
                             │               ├─▶ hooks uitvoeren (vcrun2019, gamescope, etc.)
                             │               └─▶ marker schrijven (SCRIPT_VERSION)
                             ├─▶ game_make_desktop()   → maakt ~/Desktop/<Game>.desktop MET icon + execute
                             └─▶ game_launch()         → start game (wine of Proton-runner)
```

### 2. Volgende keren (via desktop-shortcut)

```
User klikt ~/Desktop/<Game>.desktop
                    │
                    ▼
Launcher script start
                    │
                    └─▶ game_main()
                             ├─▶ game_needs_provision() → marker bestaat + versie OK
                             ├─▶ game_make_desktop()    → shortcut bestaat al, herschrijft (idempotent)
                             └─▶ game_launch()          → direct starten
```

---

## Desktop-Shortcut Creatie (met Icon + Execute-property)

**Verantwoordelijkheid:** `game_make_desktop()` in `game-common.sh`

**Variabelen die de launcher-script exporteert:**

| Variabele | Voorbeeld | Doel |
|-----------|-----------|------|
| `CREATE_DESKTOP_SHORTCUT=1` | `"1"` | Activeer shortcut creatie |
| `GAME_NAME` | `"<Game>"` | Bestandsnaam + Name= veld |
| `GAME_LAUNCHER` | `"/pad/naar/<game-launcher>.sh"` | Exec= veld |
| `DESKTOP_ICON_PATH` | `"/pad/naar/<icon>.png"` | **Icon= veld (optioneel)** |
| `DESKTOP_SHORTCUT_DIR` | `"$HOME/Desktop"` | Doelmap (optioneel, default Desktop) |
| `GUI_DESKTOP_SHORTCUT` | `"1"` of `"0"` | **GUI-override** (niet door scripts geëxporteerd): heeft voorrang op `CREATE_DESKTOP_SHORTCUT`, zodat de GUI-checkbox per klik kan kiezen. Launcher-scripts houden hierdoor bewust `"1"` hardcoded. |

**Auto-resolve icon (geen `DESKTOP_ICON_PATH` nodig):**
- Eerst: genormaliseerde exact-match (`a-z0-9`, lowercase) op alle bestandsnamen in `game-launchers/gameicons/`.
- Daarna: containment-match (stempje `IN` GAME_NAME of GAME_NAME `IN` stempje).
- Laatste redmiddel: letterlijke `GAME_NAME.png|jpg|jpeg`.
- Voorbeeld: GAME_NAME="CitiesSkylines" → `Cities&Skylines.png`; GAME_NAME="AstroidBountyHunter" → `astroid.bounty.hunter.png`. **De GUI gebruikt exact dezelfde regel** (game-gui.py `_resolve_icon`).

**Execute-property:** Na aanmaak voert `game_make_desktop` `chmod +x` uit op het `.desktop` bestand → krijgt `-rwxr-xr-x` rechten → KDE/GNOME vertrouwt het direct (geen uitroepteken/dialog).

**Resultaat (`~/Desktop/<Game>.desktop`):**
```ini
[Desktop Entry]
Type=Application
Name=<Game>
Exec="/mnt/.../<game-launcher>.sh"
Icon=/mnt/.../gameicons/<icon>.png
Terminal=false
Categories=Game;
```

**Bestandsrechten na aanmaak:**
```
-rwxr-xr-x 1 user user 311 Sep 23 20:30 /home/user/Desktop/<Game>.desktop
```

---

## Nieuwe Game Toevoegen (Standaardpatroon)

### Stap 1: Launcher-script aanmaken
`template-scripts/game-launchers/<game-launcher>.sh`:

```bash
#!/bin/bash
# <Game> — dun per-game launcher.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../game-core/game-common.sh"

export GAME_NAME="<GameName>"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINDOWSGAMES/<GameMap>"
export GAME_EXE="$GAME_DIR/<Game>.exe"
export PREFIX_ARCH="win64"
export SCRIPT_VERSION="1"
export CREATE_DESKTOP_SHORTCUT="1"
export GAME_LAUNCHER="$(readlink -f "$0")"
export DESKTOP_ICON_PATH="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINEPREFIX/template-scripts/game-launchers/gameicons/<icon>.png"

# Proton games (optioneel):
# export PROTON_ENABLED="1"
# export PROTON_PIN="GE-Proton11-7"
# export STEAM_APPID="123456"
# export PROVISION_HOOKS=("install_vcrun2019" "install_gamescope")

game_main "$@"
```

**Gamescope (per script of per klik):**
```bash
# Vast in het script:
export GAME_GAMESCOPE="1"          # altijd wrappen (bij Wayland + gamescope)
export GAME_GAMESCOPE_RES="1920x1080"  # interne resolutie vastzetten (optioneel)

# GUI-checkbox "Start met Gamescope" stuurt GUI_GAMESCOPE="1|0" via env;
# die heeft voorrang op GAME_GAMESCOPE (zelfde patroon als de desktop-checkbox).
```

**Native Linux-game** (géén Wine-prefix, bv. Celeste/Xonotic/UT2004):
```bash
#!/bin/bash
# <Game> — native Linux-game, geen prefix/provision.
export GAME_NAME="<GameName>"
export GAME_DIR="/mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/Native/<GameMap>"
export GAME_NATIVE="1"                     # slaat wine/prefix/provision over
export GAME_NATIVE_SHELL="bash"            # optioneel: runner (bash/sh/./)
export GAME_NATIVE_CMD="<startscript>.sh"  # commando om de game te starten
export GAME_LAUNCHER="$(readlink -f "$0")"
export CREATE_DESKTOP_SHORTCUT="1"
source "$(dirname "${BASH_SOURCE[0]}")/../game-core/game-common.sh"
game_main "$@"
```
Gamescope werkt dan net zo (GAME_GAMESCOPE of GUI-checkbox). Desktop-file + icon komen via `game_make_desktop`.

### Stap 2: Icoon toevoegen
Plaats `<icon>.png` (1024x1024 aanbevolen) in:
`template-scripts/game-launchers/gameicons/`

### Stap 3: Testen
```bash
# Via terminal (eerste run = provision + launch)
/mnt/.../game-launchers/<game-launcher>.sh

# Check desktop shortcut
cat ~/Desktop/<GameName>.desktop
ls -la ~/Desktop/<GameName>.desktop   # moet -rwxr-xr-x tonen

# Tweede run = direct launch via desktop-icon
~/Desktop/<GameName>.desktop
```

---

## GUI (game-gui.py) — Éénmalige Setup

**Doel:** Visuele overzicht + eerste launch van geselecteerde games.

**Starten:**
```bash
python3 /mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINEPREFIX/game-gui.py
# Of via applicatiemenu: "Game Launcher"
```

**Interface:**
- **Carousel**: banner met game-icoons (muiswiel/pijltjes = bladeren, klik = launch, Enter/Space = launch)
- **Checkboxes** (tussen carousel en terminal):
  - **Desktop-icoon op het bureaublad** (standaard AAN) → stuurt `GUI_DESKTOP_SHORTCUT=1|0` aan alle launcher-scripts
  - **Start met Gamescope** (standaard UIT) → stuurt `GUI_GAMESCOPE=1|0`
  - **SDL3-fallback aan** (standaard AAN) → stuurt `GUI_SDL3_DYNAMIC_API_OFF=1|0` (zie settings-tabel)
  - **Bevestigen vóór start** (standaard AAN) → Ja/Nee-dialog bij elke klik
  - **Installatiemap** (per game, optioneel) → tekstveld + "Bladeren…" naast de checkboxes; toont de geldige map van de geselecteerde game (conf → script-default) en stelt een **per-game** installatiepad in via `installpaths.conf` (zie Configuratie)
- **Terminal-frame**: live output (groen op zwart, monospace)

**Gedrag:**
- Klik icoon → launch script → provision (indien nodig) + desktop-shortcut + game start
- Installatie-banner `== <Game> — installatie wordt uitgevoerd ==` bovenaan de terminal
- Sluit-tab per run; bij sluiten van het venster met draaiende games eerst bevestigingsvraag

**Na eerste gebruik:** GUI hoeft **niet meer** geopend te worden. Gebruiker start games via hun desktop-icoons.

---

## Settings & Configuratie

### Environment variabelen (voor scripts)
| Variabele | Default | Beschrijving |
|-----------|---------|--------------|
| `PREFIX_ROOT` | `$HOME/GAMEPREFIXES` | Root voor alle prefixes |
| `DESKTOP_SHORTCUT_DIR` | `$HOME/Desktop` | Waar shortcuts komen |
| `WINEDEBUG` | `-all` | Wine debug output onderdrukken |
| `GUI_DESKTOP_SHORTCUT` | *(niet gezet)* | GUI-override van `CREATE_DESKTOP_SHORTCUT` (`1`/`0`) |
| `GUI_GAMESCOPE` | *(niet gezet)* | GUI-override van `GAME_GAMESCOPE` (`1`/`0`) |
| `GAME_SDL3_DYNAMIC_API_OFF` | `1` | Per-script: zet `SDL3_DYNAMIC_API=0` (ingesloten SDL-route) om de dynapi-warning/hard-fail te voorkomen. `0` = uit |
| `GUI_SDL3_DYNAMIC_API_OFF` | *(niet gezet)* | GUI-override van `GAME_SDL3_DYNAMIC_API_OFF` (`1`/`0`) |
| `GUI_GAME_DIR` | *(niet gezet)* | GUI-override van `GAME_DIR` (beperkt tot GUI-launch): pad afkomstig uit het installatiemap-veld, ook weggeschreven naar `installpaths.conf` |
| `GAME_GUI` | `1` | Door de GUI geëxporteerd: onderdrukt de "eerst GUI / weetje" melding |

**Eerste start:** de GUI plaatst eenmalig `~/Desktop/GameLauncher.desktop` (met `gamelauncherv1.png`, `chmod +x`). Bestaat die al, dan blijft hij ongemoeid.

### Installatiepaden (`installpaths.conf`)

Per-game installatiemappen zijn configureerbaar zonder de launcher-scripts aan te
passen. Opbouw:

```
~/.config/gamelauncher/installpaths.conf
GAME_DIR_<GAME_NAME>="/mnt/.../WINDOWSGAMES/<GameMap>"
```

Een `GAME_DIR_<GAME_NAME>`-regel (key = `GAME_NAME` van het launcher-script,
case-insensitief gelezen) overschrijft de hardcoded `GAME_DIR` in dat script.

**Override-volgorde** (`game_resolve_install_dir` in `game-core/game-conf.sh`):

1. `GUI_GAME_DIR` (GUI-launch met ander pad, opgegeven in het installatiemap-veld)
2. `installpaths.conf` (`GAME_DIR_<GAME_NAME>`)
3. script-default (`export GAME_DIR=...` in het launcher-script)

De GUI schrijft het veld-effect direct naar `installpaths.conf` (lege optie verwijdert
de regel). Los de launcher aan → `game_resolve_install_dir` afgeleid
(`GAME_EXE_REL="${GAME_EXE#"$GAME_DIR"/}"`) zodat één gedeelde engine-launch
(`game_common`) overal mee kan.

### Native games
Geen prefix/provision nodig: zet `GAME_NATIVE="1"` + `GAME_NATIVE_CMD`. Totale flow is dan: lock → backup-snapshot → desktop-file (+ icon) → launch (optioneel gamescope-wrap). Het installatiepad is óók hier configureerbaar (`game_resolve_install_dir`).

### Automation Empire (eigen prefix-markering)
`automationempire.sh` probeert geen Wine via de core, maar beheert een eigen prefix
met een **marker-gate** op versie: `$PREFIX_DIR/.provisioned` bevat `SCRIPT_VERSION`.
- Marker **ontbreekt** of heeft een **andere versie** dan `SCRIPT_VERSION="1"` → één
  idempotente provision (prefix aanmaken + `winecfg -v win10`) en marker schrijven.
- Marker **klopt** → direct starten, geen provision.
`SCRIPT_VERSION` verhogen = bewust de prefix herbouwen na een config-wijziging.

---

## Troubleshooting

| Probleem | Oplossing |
|----------|-----------|
| Game start niet, geen output | Check `~/GAMEPREFIXES/<Game>/pfx` bestaat, `wineboot -i` handmatig |
| Shortcut zonder icon | Check `DESKTOP_ICON_PATH` in launcher, of icoon in `gameicons/` |
| Shortcut niet direct klikbaar (uitroepteken) | Check `chmod +x` in `game_make_desktop`; `ls -la` moet `-rwxr-xr-x` tonen |
| Prefix corrupt | `rm -rf ~/GAMEPREFIXES/<Game>` → volgende run maakt verse prefix |
| Proton niet gevonden | `template-scripts/tools/install-proton.sh` draaien |
| Gamescope mist (AMD/Wayland) | `install_gamescope` hook toevoegen aan launcher |
| Gamescope werkt niet via GUI-checkbox | Check dat het game-script game-common gebruikt (`game_main` of `_gscope_argv`); de GUI stuurt `GUI_GAMESCOPE`, niet `GAME_GAMESCOPE` |
| Carousel scrolt niet door (muiswiel/pijltjes) | Check `game-gui.py` → `move_to()` gemaakt — zet `self._target` |
| Game-icoon in carousel is placeholder | Check `gameicons/` heeft een PNG; naam matcht via normalisatie/containment met de game-key |

---

## Backup & Versiebeheer

- `game-common.sh` maakt backup-snapshots voor elke run:
  `template-scripts/backup/ver1_<datum>_<tijd>/`
- Max 3 versies (ver1 → ver2 → ver3, oudste verdwijnt)
- GUI-code zit in `gui/` — niet in backup opgenomen

---

## Samenvatting Commando's

```bash
# Game direct launchen (na eerste setup)
~/Desktop/<Game>.desktop

# GUI starten (voor nieuwe games)
python3 /mnt/VG_00/PUBLIC-LIBRARY/PRE-INSTALLED-GAMES/WINEPREFIX/game-gui.py

# Proton (GE) installeren/updaten
/mnt/.../template-scripts/tools/install-proton.sh

# Nieuwe game launcher testen
/mnt/.../template-scripts/game-launchers/<game-launcher>.sh

# Prefix resetten
rm -rf ~/GAMEPREFIXES/<Game>
```