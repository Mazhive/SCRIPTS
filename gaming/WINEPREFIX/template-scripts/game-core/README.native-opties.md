# Native-launch: extra opties (uitbreiding game-common.sh)

Datum: 2026-09-24 · Backup: `backup/ver1_20260924_092447/`, `backup/ver1_20260924_102250/`

De native-tak van `game_launch()` in `game-common.sh` ondersteunt per-game
opties voor **GAME_NATIVE=1** spellen. De bedoeling: oudere GL-engines die op
een Wayland-sessie zwart beeld geven (bekend bij NVIDIA / hybride
AMD-iGPU+NVIDIA-dGPU, fullscreen) via een omweg laten renderen.
**Native-only**: geen van deze mechanismen doet iets voor GAME_NATIVE!=1.

## 1. GAME_NATIVE_SDL_DRIVER (SDL-videodriver afdwingen)

Waarden: `auto` (standaard) · `wayland` · `x11`

- `x11`: forceert `SDL_VIDEODRIVER=x11` → de game rendert via **XWayland-GLX**,
  die KWin betrouwbaar componeert, onafhankelijk van de GPU/PRIME-keuze.
  Wordt **alleen** toegepast als:
  - `XDG_SESSION_TYPE=wayland` (andere sessies → auto), én
  - `DISPLAY` gezet, én
  - het XWayland-socket `/tmp/.X11-unix/X${DISPLAY#:}` bestaat.
  Ontbreekt één van die drie? Dan netjes terugvallen op `auto` mét logregel.
- `wayland`: forceert `SDL_VIDEODRIVER=wayland` (nieuwere engines die juist op
  Wayland beter draaien).

Per game instellen in het launcher-script vóór `game_main`:
```bash
export GAME_NATIVE_SDL_DRIVER="x11"
```

## 2. GAME_NATIVE_EXTRA_ARGS (engine-arguments)

Extra engine-argumenten die vóór de door de gebruiker geboden argumenten
worden ingeschoven (bewust ongequoot, net als bij wine-args):
```bash
export GAME_NATIVE_EXTRA_ARGS="+vid_fullscreen 0"   # bv. windowed starten
export GAME_GAMESCOPE="1"                            # gamescope-wrap (bestond al)
```

## 3. GUI-checkboxes (windowed / gamescope) — "Instellingen"-icoon

Per-game checkbox-vlaggen voor het "geluid maar geen beeld"-symptoom, **native
only**. Géén automatische popup: de checkbox-editor wordt uitsluitend
aangeroepen via het toegevoegde desktop-icoon **"<GAME> - Instellingen"** of
via `./<launcher>.sh --gui-flags`.

- Terminal (`-t 1`) → `whiptail --checklist`; desktop-icoon (GUI) → `kdialog
  --checklist`, fallback `zenity` (drie `--question`-dialogen); niets
  beschikbaar → editor slaat over.
- Vinkjes: **windowed**, **gamescope**, **snapshot** (backup-snapshot vóór elke
  start — alleen testomgeving).
- Keuzes bewaard in `$GAMEPREFIXES_ROOT/<GAME_NAME>/flags.conf` (buiten
  `template-scripts`, raakt niet door desktop-regenerate):
  ```
  windowed=1        # → +vid_fullscreen 0 (GUI_NATIVE_WINDOWED="1")
  gamescope=1       # → GAME_GAMESCOPE met GUI_GAMESCOPE-override
  snapshot=1        # → _snapshot_backup() vóór elke start van déze game
  ```
- Precedentie: **checkbox wint** van de statische script-defaults. `windowed=0`
  stript `+vid_fullscreen 0` zelfs uit een script-hardcode; `gamescope=0`
  forceert gamescope uit (`GUI_GAMESCOPE=0`), het bestaande override-patroon.
  `snapshot` alleen een trigger vóór de launch (0 = géén snapshot).
- De `GUI_*`-variabelen worden in `game_main()` net vóór `game_launch`
  gezet; de native-tak van `game_launch` (rond de `native_args`) verwerkt
  `GUI_NATIVE_WINDOWED`.
- Backup-snapshots draaien **nooit** automatisch voor elke game: alleen via
  `SNAPSHOT_BACKUP=1` (env, test-scripts) óf de aangevinkte `snapshot`-checkbox
  van een specifieke game. Normale start blijft daardoor <1s (géén 120s-rsync).
  Na een snapshot via het icoon tonen `kdialog`/`zenity` een "Snapshot klaar"-melding.

### GUI-route (game-gui.py)
`game-gui.py` (WINEPREFIX/game-gui.py) heeft een vijfde vinkje
**"Backup-snapshot vóór elke start (testzone)"**. Dat zet per launch
`SNAPSHOT_BACKUP=1` in de kind-env (plus `GAME_GUI=1`); de gate in `game_main`
draait dan de snapshot, en het terminal-frame van de GUI toont de voortgang
live. `GAME_GUI=1` onderdrukt daarbij de extra kdialog/zenity-melding in
`_flags_snapshot_notify()` (de GUI terminal vervangt die). Twee gelijkwaardige
routes blijven naast elkaar bestaan: GUI-vinkje = per-launch/globaal (geen
persistentie, zoals `cb_gamescope`); Instellingen-icoon/`--gui-flags` =
per-game persistent in `flags.conf`.

## Gewijzigd

- `game-core/game-common.sh` — native-tak `game_launch()`: SDL-driver-selectie
  + `GAME_NATIVE_EXTRA_ARGS` + `GUI_NATIVE_WINDOWED`-verwerking; nieuwe
  helpers `_flags_file/_read/_write/_defaults/_apply/_editor` (+ derde checkbox
  `snapshot`), `_flags_want_snapshot`, `_flags_snapshot_notify`; `game_main()`
  `--gui-flags`-pad + `_flags_apply` vóór de launch + backup-gate
  (`SNAPSHOT_BACKUP=1` óf `snapshot=1`); `game_make_desktop()` extra
  "Instellingen"-icoon (native only).
- `game-launchers/xonotic.sh` — `export GAME_NATIVE_SDL_DRIVER="x11"` +
  fallback-toelichting.
- `../game-gui.py` (WINEPREFIX) — vijfde optievinkje "Backup-snapshot vóór elke
  start (testzone)" → `SNAPSHOT_BACKUP` + `GAME_GUI` in de launch-env.

Referentie-case: Xonotic op een CachyOS-PC (KWin 6 Wayland, AMD Raphael-iGPU +
NVIDIA GTX 1070, `sdl2-compat` op SDL3): geluid maar zwart fullscreen-venster
via de SDL-Wayland-driver; `x11` verwacht dit te verhelpen via XWayland-GLX.