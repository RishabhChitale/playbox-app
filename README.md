# Playbox app

A mobile client for a self-hosted Playbox media server. Browse the library, open a show, and play an episode.

- Flutter, `media_kit` (libmpv) for playback, plain `http` for the GraphQL API.
- Set the server URL in Settings (default `http://100.121.45.79:9998`).
- iOS builds run in GitHub Actions and produce an unsigned `.ipa` for sideloading (SideStore/AltStore).

Builds run on GitHub Actions (macOS runner).

## Install (SideStore / AltStore)

Add this source: `https://raw.githubusercontent.com/RishabhChitale/playbox-app/main/apps.json`

Current release: v0.2.0 (`playbox-0.2.0.ipa`). Adds Search, a title page with Add, and a Downloads tab.
