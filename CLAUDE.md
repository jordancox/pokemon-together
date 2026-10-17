# Insieme (pokemon-together)

A native iPad app for Jordan and his son (almost 7, reads capital letters word by word) to learn the Pokémon TCG
together with the son's own cards, in Italian or English. **Simple, voice first, little text.** Jordan's brief
(17 Oct 2026): "super great and easy and not over complicated"; "less complex and text heavy" than the September
web app (Insieme v1, lessons and quizzes, replaced; it's in git history before 17 Oct). Add features one at a time,
when Jordan asks.

**They play with the real cards** (Jordan, 17 Oct, after the first build was an on-screen game: "help with real
cards", and "why are you explaining this to me in here?"). The iPad is the guide and scorekeeper, not the game. The
teaching happens in the app, by voice, at the moment it matters, never in a chat message.

@README.md

## How it works

- iPad only, portrait, lying flat. Side 0 is the bottom half, side 1 the top (turned 180°). Each half is designed at
  834×575 (half an 11-inch iPad) and scaled (`Fit` in `Board.swift`). The middle strip has the Poké Ball (start / say
  it again / play again; hold 1.2 s to stop a game), the 🇮🇹 🇬🇧 switch and the voice switch.
- `Game.swift` has the rules (level 1, see README) and the whole turn flow. The ENERGY button means "I put an Energy
  card on it", and the voice names the type to put on (`nextEnergy`). The first-time explanations are the
  `told` keys (hp, energy, cost, attack, coin, weak, count), once each time the app opens. Everything said goes through `Game.say`:
  spoken by `Voice` (AVSpeechSynthesizer, the best Italian or English voice on the iPad), or, with the voice off
  (Jordan, 17 Oct: "if I am playing with him and want to just read the instructions myself"), shown as the latest
  line at the top of each half. `Say.swift` has every line, Italian first.
- Cards: `cards.txt` → `tools/cards.py` → `ios/App/Data/cards.json` (TCGdex, IT and EN). Effects are read from the
  English text by the `EFFECTS` patterns. An effect that isn't matched is `skip`: the attack does only its damage, and
  an attack with no damage is hidden. Check the "effect not played" list it prints when adding cards. Level 1 only
  plays Basic Pokémon with a damaging attack.
- Card pictures are never committed (public repo). The cloud Mac runs `tools/cards.py art` into `ios/build/Cards`
  before each build. Sprites (PokeAPI, Jordan's OK on 17 Oct) are committed in `ios/App/Sprites`.
- **His cards are added in the app** (Jordan, 17 Oct: doing it through Claude was "outside the app… bit clunky"): the
  + tile on the pick screen opens `AddView` (`Adding.swift`). The camera (VisionKit's DataScanner; not on the
  simulator, so only tried on his iPad) reads the set code and number at the bottom left ("SVI 038/198"; the language
  is printed beside the code, "SVI IT", often read as one word) → `Data/sets.json` → the TCGdex id. Or a name is
  typed. The card, its pictures and sprite are fetched from TCGdex/PokeAPI and saved in the app's Documents
  (`collection.json`); effects are read with the same `Data/effects.json` as `tools/cards.py`. Until he has two
  playable cards, the pick screen shows the 12 sample cards built in from `cards.txt`.

## Building and shipping

The ios-testflight skill: public repo, so every push touching `ios/`, `tools/cards.py` or the workflow builds for
free. Look at the screenshots (`gh run download <id> -n shots`) and the `auto*.log` files (whole games played by
themselves, every line said) before saying anything works. TestFlight: `gh workflow run ios.yml -f testflight=true`.
Bundle id `org.jordancox.insieme`.
