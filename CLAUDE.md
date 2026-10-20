# Insieme (pokemon-together)

A native iPad app for Jordan and his son (almost 7, reads capital letters word by word) to learn the Pokémon TCG
together with the son's own cards, in Italian or English. **Simple, little text on his side.** Jordan's brief
(17 Oct 2026): "super great and easy and not over complicated"; "less complex and text heavy" than the September
web app (Insieme v1, lessons and quizzes, replaced; it's in git history before 17 Oct). Add features one at a time,
when Jordan asks.

**They play with the real cards** (Jordan, 17 Oct, after the first build was an on-screen game: "help with real
cards", and "why are you explaining this to me in here?"). The iPad is the guide and scorekeeper, not the game. The
teaching happens in the app, at the moment it matters, never in a chat message.

**Coherence before features** (Jordan, 18 Oct, after build 20: "I'm 45 and can't parse what this is. Why are you
shipping stuff that is stumping a 45 year old?… make the next build coherent please even if it's not complete").
Before any TestFlight build, walk the screenshots in order as someone who has never seen the app: each screen must
say what it is and what to do next. Send Jordan the screens in order, one line each, before TestFlight.

**A parent half and a child half** (Jordan, 18 Oct: "I'll be talking to him the whole time. The issue is reading on
his side upside down is impossible… make parent side less distracting and with instructions for me to follow. He gets
single word type stuff on his side"). The bottom half (side 0, `parentSide`) is the parent's: dark grey, nothing
pulsing, the instructions written out in sentences to read and pass on. The top half (side 1, `childSide`), turned to
face him, has pictures, numbers and single words (READY?, his Pokémon, ENERGY, the attacks, DONE, RETREAT, WHO?, YOUR
TURN!, YOU WIN!). **The voice is off** unless switched on: Jordan does the talking.

**Levels, laddered up by hand** (Jordan, 18 Oct: "Practice battle. More complex. Full sim. We can manually ladder up
as we learn the mechanics… up to like level 5? level 10?"). Each adds one thing from the real game (`Say.level`):
1 Practice battle (one Pokémon each, Energy, attacks), 2 Team (three Pokémon each, one fighting and the rest on the
bench; after a KO its player taps who comes in), 3 Retreat (RETREAT, once a turn, pays the card's retreat cost in
Energy), 4 Evolution, 5 Your hand (a deck each, draw and play), 6 Prize cards, 7 Trainers, 8 Full game (special
conditions, abilities, all the rules). **1 to 3 are built** (`Say.built`; 2 and 3 on 20 Oct 2026). The parent picks
the level on the start screen (remembered); the ones not built say so. Build the next level only when Jordan asks.

@README.md

## How it works

- iPad (and iPhone: the same board, scaled down; Jordan, 18 Oct 2026: "we should do an iPhone build too"), portrait,
  lying flat. Side 0 is the bottom half, side 1 the top (turned 180°). Each half is designed at
  834×575 (half an 11-inch iPad) and scaled (`Fit` in `Board.swift`). The middle strip has the Poké Ball (choose the
  Pokémon / start / say it again / play again; hold 1.2 s to stop a game or choose again), the EN / IT switch
  (letters, never flags: Jordan is Canadian), CARDS (your cards, before a battle) and the voice switch.
- **The app chooses the Pokémon** (Jordan, 17 Oct: "we have no idea what cards to choose… we do not know any rules
  here"): the first Poké Ball tap picks a fair pair from your cards that can play (`choose`: about the same HP). The
  child's half shows his card, big; the parent's shows both, with the Energy cards to put next to each
  (`energyFor`). There is no grid of cards on the halves (build 20 had one on both and it read as two hands). Nothing
  may assume they know a rule or a card part: the lines say what an Energy card looks like and its colour
  (`Say.energyLook`), where things go ("under Pikachu's card"), and explain HP at the first damage.
- `Game.swift` has the rules (levels 1–3, see README) and the whole turn flow. A `Side` is a team of `Mon`s (card,
  Energy, damage) and the one fighting (`active`). From level 2 the Poké Ball chooses three each (two with only four or
  five cards), each about the HP of the one it faces; the child's half shows the fighter at the top, by the middle of
  the table, and the bench behind it, as on the table. The bench shows beside the HP on both halves; a knockout with two
  left on the bench puts them big on that half (`BenchPicker`, CHI? / WHO? on the child's) to tap. The ENERGY button
  means "I put an Energy card on it", and the voice names the type to put on (`nextEnergy`). The first-time explanations are the
  `told` keys (energy, cost, attack, coin, weak, count), once each time the app opens. Everything said goes through
  `Game.say`: written at the top of the parent's half (the last two lines), and spoken by `Voice` when the voice is
  on. `Say.swift` has every line, Italian first.
- **The voice, when on, is Kokoro**, run on the iPad (Jordan, 17 Oct, after hearing samples: "it does sound a lot better than
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
  an attack with no damage is hidden. Check the "effect not played" list it prints when adding cards. **Any Pokémon
  with an attack that does damage battles**, at every level: evolutions too, on their own as if Basic (Jordan, 20 Oct
  2026: "he sometimes just wants to play"), and damage written in the text (`hit`: Golbat's "40 damage to 1 of your
  opponent's Pokémon", on the fighting one; `counters`: Mr. Mime's damage counters). Cards added before a rule existed
  are read again when the app opens (`Game.reread`). A bench-only attack (Moltres 151) or a copied one (Mew ex) can't
  play yet. **When a battle can't start, the parent's half says why** in yellow (`Game.intro`, `Say.cantStart`): how
  many cards the level needs, how many of yours can battle, which can't, and what to do.
- Card pictures are never committed (public repo). The cloud Mac runs `tools/cards.py art` into `ios/build/Cards`
  before each build. Sprites (PokeAPI, Jordan's OK on 17 Oct) are committed in `ios/App/Sprites`.
- **Your cards are added in the app** (Jordan, 17 Oct: doing it through Claude was "outside the app… bit clunky"):
  CARDS in the middle strip opens `AddView` (`Adding.swift`), one box of cards for both players. The camera (VisionKit's DataScanner; not on the
  simulator, so only tried on his iPad) reads the set code and number at the bottom left ("SVI 038/198"; the language
  is printed beside the code, "SVI IT", often read as one word). The number after the slash (198) narrows it to the
  sets with that many cards (`Data/sets.json`: code, count and date of every set), and only those sets' codes are
  looked for: a card is full of words that are an old set's code ("HP", Italian "la", "si", "ma"), which picked the
  wrong card in build 12. A parent can also type the number ("38/198", "SVI 38"), a name, or both ("pikachu 25");
  results are newest first, each with its code and number under it to check against the card. The card, its
  pictures and sprite are fetched from TCGdex/PokeAPI and saved in the app's Documents (`collection.json`); effects
  are read with the same `Data/effects.json` as `tools/cards.py`.
- **Only your cards** (Jordan, 18 Oct, on build 12's sample cards: "it needs to be blank, and we just add the ones
  that we have"): the Poké Ball chooses from the cards added with CARDS. The 12 sample cards from `cards.txt` are only
  for the cloud Mac's screenshots and test games (`-demo`, `-auto`).

## Learned from playing (carry each level's lessons into the next)

Jordan, 18 Oct: "build one at a time with the learnings I get from each one taken forward". Add what each level's
first real games teach, here, before building the next level.

- Level 1, builds 9–20 (18 Oct): a grid of cards on both halves read as two hands of cards; neither of them could tell
  what the app was. One thing per screen, said in plain words. The parent talks, so the voice is off and the
  parent's half carries the sentences; the child can't read upside down, so his half has single words. The camera
  screen must not flicker (Apple's text boxes and tips off, one lookup per card). Letters for languages, not flags.
- Level 1, build 31 (18 Oct, first real game, Heatran won): lines came faster than Jordan could read them out, and the
  end screen dropped the Weakness explanation. The parent's half keeps every line of the game, scrollable, through
  the end screen (`LogView`). Four Energy cards for every Pokémon looked like a rule: show exactly what's needed.
- Level 1, build 38 (20 Oct): his evolved cards were kept "for a later level", so the Poké Ball sometimes did
  nothing and nothing said why ("it's not clear why the battle won't start sometimes"). A child wants to play with the
  cards he likes: every Pokémon that can do damage battles, and whatever stops a battle starting is said in plain
  words where the parent is looking. CI: added evolutions must say "battles yes", and a too-small box must name the
  card that can't battle.

## Building and shipping

The ios-testflight skill: public repo, so every push touching `ios/`, `tools/cards.py` or the workflow builds for
free. Look at the screenshots (`gh run download <id> -n shots`) and the `auto*.log` files (whole games played by
themselves, every line said) before saying anything works. TestFlight: `gh workflow run ios.yml -f testflight=true`.
Bundle id `org.jordancox.insieme`.
