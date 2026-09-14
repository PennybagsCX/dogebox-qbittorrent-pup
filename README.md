# ⬇️ qBittorrent for Dogebox

<p align="center"><img src="qbittorrent/logo.png" width="110" alt="qBittorrent pup logo"></p>

**[qBittorrent-nox](https://www.qbittorrent.org) (headless, Web UI) packaged as a [Dogebox](https://dogebox.org) pup** — the download engine for the media automation stack: [Radarr](https://github.com/PennybagsCX/dogebox-radarr-pup) / [Sonarr](https://github.com/PennybagsCX/dogebox-sonarr-pup) drive it, [Jellyfin](https://github.com/PennybagsCX/dogebox-jellyfin-pup) plays the results. Indexer definitions (including the public-domain **Internet Archive**) via [Prowlarr](https://github.com/PennybagsCX/dogebox-prowlarr-pup).

> ⚖️ qBittorrent is a general-purpose BitTorrent client. What you download and the rights to it are your responsibility — pair it with legal sources (public domain / Creative Commons) to stay clean.

## Install

Pup Store → Manage Sources → add `https://github.com/PennybagsCX/dogebox-qbittorrent-pup.git` → install **qBittorrent**. Launch the web UI from the pup screen (dogebox maps a host port).

## First run

- On first boot the WebUI allows LAN/bridge subnets without a password so you can set up — **create your credentials immediately** in the WebUI (Settings → Web UI) or via the API:

```bash
curl -X POST http://<box>:<port>/api/v2/app/setPreferences \
  -d 'json={"web_ui_username":"you","web_ui_password":"secret","web_ui_auth_subnet_whitelist_enabled":false}'
```

- Default save path: `/storage/downloads` (inside the pup).
- Radarr/Sonarr connect to it as a **qBittorrent download client** at the dogebox host port.

## Media pipeline

`qB /storage/downloads` → host sync timer → Radarr/Sonarr import & rename → existing timer → Jellyfin library. Because pups are filesystem-isolated, the bridge is a host-side systemd timer (rsync + a `DownloadedMoviesScan` / `DownloadedEpisodesScan` API call) — see the Radarr/Sonarr pup READMEs.

## Legal source tip

The Internet Archive hosts thousands of public-domain films with native torrents — grab a `.torrent` from any item page and drop it into the qB WebUI for an instant legal end-to-end test. For automatic indexing, add the Internet Archive indexer in Prowlarr and sync it to Radarr/Sonarr.

## License

MIT for the packaging. qBittorrent is GPL — this repo only packages it.
