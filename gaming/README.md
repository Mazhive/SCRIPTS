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

### Referentie-mappen (`movedprefixes/`, `protonprefix/`) — géén runtime-afhankelijkheid

Op de share staan (nog) oude prefix-mappen (`WINEPREFIX/movedprefixes/`,
`PRE-INSTALLED-GAMES/protonprefix/`). Dit zijn **tijdelijk onderzoeksmateriaal**:
ze zijn alleen gebruikt om af te leiden welke extra stappen (hooks, VC++-redists,
appid's) een game nodig heeft. Ze worden **niet** gekopieerd, gelinkt of als
fallback aangeroepen door de scripts, en ze zullen op een gegeven moment van de
server **verwijderd** worden. Elk game-script moet dus blijven werken als deze
mappen niet meer bestaan — dat is ook expliciet getest (verse prefix + Proton
richt zelf alles in, zie per-game-notities hieronder).

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
         │  └─ citiesskylines.sh     → dun script: Proton-runner, geen hooks nodig
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

## Per-game notities

| Game                  | Renderer         | Opmerking |
|-----------------------|-------------------|-----------|
| **Angry Birds**       | OpenGL 2          | Wine-mode (geen Proton). Runtimes (`msvcp100.dll`, `msvcr100.dll`) liggen al naast de exe. Geen hooks nodig. |
| **Cyberpunk 2077**    | DirectX 12        | Proton-runner (`PROTON_PIN=GE-Proton11-7`, `STEAM_APPID=1091500`). Proton installeert dxvk/vkd3d/nvapi zelf bij de eerste start. Vereist wel de hook `install_vcrun2019` (VC++ 2019, zie `_CommonRedist` in de gamemap) — zonder deze hook stopt de game direct en stil. Bevestigd werkend: hoofdmenu bereikt. |
| **Cities: Skylines**  | DirectX 11 (Unity)| Non-Steam MEX-crack repack. Proton-runner (`PROTON_PIN=GE-Proton11-7`, `STEAM_APPID=255710` — matcht de crack's eigen `MEX.ini`). Geen hooks nodig (game brengt eigen Mono-runtime mee, geen `_CommonRedist`). Bevestigd werkend: hoofdmenu bereikt, geen glitches. |

### Black Myth: Wukong — specifieke waarschuwing

De (huidige) Hypervisor-crack (`HV-StartGame.exe` + `Simplesvm.sys`) laadt een
**kernel-driver en hypervisor op ring -1**. Wine is user-mode-only en kan dit
structurerend nooit ondersteunen → deze build is **niet speelbaar op Linux**.
Alleen een non-HV build (zonder hypervisor) is geschikt voor dit systeem.

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

## Logboek / status

- [x] Angry Birds: `game-common.sh` + `angry-birds.sh` geschreven en werkend
- [x] Angry Birds: provision-test (eigendom, marker v1, `.desktop`-shortcut) — bevestigd
- [x] Cyberpunk 2077: `cyberpunk2077.sh` met Proton-runner (`GE-Proton11-7`) +
      `install_vcrun2019`-hook — bevestigd werkend, hoofdmenu bereikt
- [x] Cities: Skylines: `citiesskylines.sh` met Proton-runner, geen hooks nodig —
      bevestigd werkend, hoofdmenu bereikt, geen glitches
- [x] `tools/install-proton.sh`: generieke GE-Proton-installer + `InstallProton`-snelkoppeling
- [x] Generieke `_warn_missing_proton()` (werkt voor elke game via `$GAME_NAME`)
- [x] Generieke `.desktop`-shortcut-locatie (instelbaar, voorbereid op GUI)
- [ ] Eindtest: `movedprefixes/`/`protonprefix/` tijdelijk verwijderen en bevestigen
      dat alle drie games nog steeds zelfstandig starten
- [ ] Ori (2x): launcher-scripts nog te schrijven
- [ ] Python-GUI (opstarthelper, niet urgent)