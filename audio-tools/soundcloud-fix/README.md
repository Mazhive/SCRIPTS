# Audio Seek Fixer (SoundCloud & YT-DLP Tool)

This script is designed for Linux (Debian 12) to repair audio files that do not work properly in media players like VLC.

# The Problem

When you download tracks from SoundCloud (for example, with yt-dlp), the index information is often missing from the file. As a result, you cannot "scroll" or "seek" in VLC using the orange dot; you can only listen to or tap the track from beginning to end.

### The Solution

This script recursively iterates through a specified folder, restores the timeline index of each audio file (.mp3, .m4a, .ogg, .opus) using FFmpeg without loss of quality, and preserves the entire folder structure and metadata.

## 🚀 Installation
### 1. Requirements

You need ffmpeg on your system. On Debian/Ubuntu you install this with:

sudo apt update && sudo apt install ffmpeg -y

# ######################################################################################################################################################################

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
