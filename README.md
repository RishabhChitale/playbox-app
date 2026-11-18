# Playbox app

A mobile client for a self-hosted Playbox media server. Browse the library, open a show, and play an episode.

- Flutter, `media_kit` (libmpv) for playback, plain `http` for the GraphQL API.
- Set the server URL in Settings (default `http://100.121.45.79:9998`).
- iOS builds run in GitHub Actions and produce an unsigned `.ipa` for sideloading (SideStore/AltStore).
