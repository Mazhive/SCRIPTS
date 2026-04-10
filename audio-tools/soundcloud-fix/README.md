# Audio Seek Fixer (SoundCloud & YT-DLP Tool)

Dit script is ontworpen voor Linux (Debian 12) om audiobestanden te repareren die niet goed werken in mediaspelers zoals VLC. 

### Het Probleem
Wanneer je tracks downloadt van SoundCloud (bijvoorbeeld met `yt-dlp`), ontbreekt vaak de index-informatie in het bestand. Hierdoor kun je in VLC niet "scrollen" of "seeken" met het oranje bolletje; je kunt alleen het nummer van begin tot eind luisteren of tappen.

### De Oplossing
Dit script loopt recursief door een opgegeven map, herstelt de tijdlijn-index van elk audiobestand (`.mp3`, `.m4a`, `.ogg`, `.opus`) met behulp van FFmpeg zonder kwaliteitsverlies, en behoudt de volledige mappenstructuur en metadata.

---

## 🚀 Installatie

### 1. Vereisten
Je hebt `ffmpeg` nodig op je systeem. Op Debian/Ubuntu installeer je dit met:
```bash
sudo apt update && sudo apt install ffmpeg -y
