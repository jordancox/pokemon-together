# Insieme · Pokémon IT + EN

A bilingual, child-friendly tutorial for the physical Pokémon Trading Card Game.

- Four short missions, with 16 interactive steps.
- A nine-step guided practice using clearly fictional teaching cards.
- A real-card table companion, searchable reference, and device-based IT/EN speech.
- Local lesson progress, PWA manifest, and offline assets.

Run locally: `python3 -m http.server 4173 --directory public`

Build: `npm run build` (no dependencies required). Serve `dist/` over HTTPS for installation and offline caching. On iPad use Safari → Share → Add to Home Screen.

Browser validation covered lessons, answer gating, persistence, practice state, table turns, search, dialogs, responsive layouts, and offline loading in Chromium. Real iPad Safari and Italian device voices have not been tested on hardware.

The `test.mjs` harness uses the browser and Playwright available in the build environment; adjust its paths for another machine.

Pokémon artwork is distributed via PokeAPI and belongs to its respective rights holders. This is an unofficial learning project. Official rules are linked inside the app.
