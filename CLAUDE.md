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

- iPad (and iPhone: the same board, scaled down; Jordan, 18 Oct 2026: "we should do an iPhone build too"), portrait,
  lying flat. Side 0 is the bottom half, side 1 the top (turned 180°). Each half is designed at
  834×575 (half an 11-inch iPad) and scaled (`Fit` in `Board.swift`). The middle strip has the Poké Ball (choose the
  Pokémon / start / say it again / play again; hold 1.2 s to stop a game), the 🇮🇹 🇬🇧 switch and the voice switch.
- **The app chooses the Pokémon** (Jordan, 17 Oct: "we have no idea what cards to choose… we do not know any rules
  here"): the first Poké Ball tap picks a fair pair from the cards that can play (`choose`: about the same HP), and the
  voice says to find the card shown on your half in the pile. Tapping a Pokémon still chooses it yourself. Nothing
  may assume they know a rule or a card part: the voice says what an Energy card looks like and its colour
  (`Say.energyLook`), where things go ("under Pikachu's card"), and explains HP at the first damage.
- `Game.swift` has the rules (level 1, see README) and the whole turn flow. The ENERGY button means "I put an Energy
  card on it", and the voice names the type to put on (`nextEnergy`). The first-time explanations are the
  `told` keys (energy, cost, attack, coin, weak, count), once each time the app opens. Everything said goes through `Game.say`:
  spoken by `Voice`, or, with the voice off
  (Jordan, 17 Oct: "if I am playing with him and want to just read the instructions myself"), shown as the latest
  line at the top of each half. `Say.swift` has every line, Italian first.
- **The voice is Kokoro**, run on the iPad (Jordan, 17 Oct, after hearing samples: "it does sound a lot better than
  the ipad's premium voices"; his OK to add it). `Kokoro.swift`: sherpa-onnx (Swift package) runs Kokoro v1.0, put
  in the app by `ios/ci/kokoro.sh` (never committed). Voices: Sara (35) for Italian, Emma (21, British) for English.
  Making a sentence takes about as long as saying it (on the VM; his 2018 iPad is untested), so every sentence is kept
  in Library/Caches/Voice once made, and the game asks ahead: `Game.warm()` for the lines every game says,
  `warm(card)` when a Pokémon is chosen. A line is played sentence by sentence, the next made while one plays. If
  Kokoro can't load, the iPad's own voice (AVSpeechSynthesizer) speaks. Names are respelled for both voices from
  `Data/names.json` ("Pikaciù", "Peekachoo"): add a name there when Jordan hears one said wrong, checking it with
  espeak-ng first.
- Cards: `cards.txt` → `tools/cards.py` → `ios/App/Data/cards.json` (TCGdex, IT and EN). Effects are read from the
  English text by the `EFFECTS` patterns. An effect that isn't matched is `skip`: the attack does only its damage, and
  an attack with no damage is hidden. Check the "effect not played" list it prints when adding cards. Level 1 only
  plays Basic Pokémon with a damaging attack.
- Card pictures are never committed (public repo). The cloud Mac runs `tools/cards.py art` into `ios/build/Cards`
  before each build. Sprites (PokeAPI, Jordan's OK on 17 Oct) are committed in `ios/App/Sprites`.
- **His cards are added in the app** (Jordan, 17 Oct: doing it through Claude was "outside the app… bit clunky"): the
  + tile on the pick screen opens `AddView` (`Adding.swift`). The camera (VisionKit's DataScanner; not on the
  simulator, so only tried on his iPad) reads the set code and number at the bottom left ("SVI 038/198"; the language
  is printed beside the code, "SVI IT", often read as one word). The number after the slash (198) narrows it to the
  sets with that many cards (`Data/sets.json`: code, count and date of every set), and only those sets' codes are
  looked for: a card is full of words that are an old set's code ("HP", Italian "la", "si", "ma"), which picked the
  wrong card in build 12. A parent can also type the number ("38/198", "SVI 38"), a name, or both ("pikachu 25");
  results are newest first, each with its code and number under it to check against the card. The card, its
  pictures and sprite are fetched from TCGdex/PokeAPI and saved in the app's Documents (`collection.json`); effects
  are read with the same `Data/effects.json` as `tools/cards.py`.
- **The pick screen starts empty** (Jordan, 18 Oct, on build 12's sample cards: "it needs to be blank, and we just
  add the ones that we have, and they start showing up bit by bit"): only his cards, still pictures (not animated), the
  ones that can't play yet faded (tapping one says why). The 12 sample cards from `cards.txt` are only for the cloud
  Mac's screenshots and test games (`-demo`, `-auto`).

## Building and shipping

The ios-testflight skill: public repo, so every push touching `ios/`, `tools/cards.py` or the workflow builds for
free. Look at the screenshots (`gh run download <id> -n shots`) and the `auto*.log` files (whole games played by
themselves, every line said) before saying anything works. TestFlight: `gh workflow run ios.yml -f testflight=true`.
Bundle id `org.jordancox.insieme`.
