# Insieme

An iPad (or iPhone) helper for a parent and a child learning the Pokémon Trading Card Game together, playing with the child's
own cards on the table, in Italian or English. The iPad lies flat between the two players, and each gets half of the
screen. The app knows the cards in the collection and chooses a fair pair: each player finds the card shown on their half
and puts it in front of them. A voice then runs the game, assuming nobody knows a single rule. It says whose turn it is and what to do with the cards ("put a Lightning
Energy card on Pikachu"). It explains each part of a card the first time it matters (HP, the Energy an attack needs,
damage, Weakness), and it does the damage maths and keeps count. On screen there are only a few big words in capitals
and the numbers. With the voice switched off, the same lines show as text for the parent to read aloud.

The voice is [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) (Apache 2.0), run on the iPad itself by
[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache 2.0), which uses espeak-ng to sound out the words. The
iPad's own voice takes over if Kokoro can't run.

**Level 1, the first battle:** one Basic Pokémon each, with some Energy cards beside it. A coin decides who starts.
Each turn you put one Energy card on your Pokémon, then attack or tap DONE. Weakness doubles the damage, Resistance
takes some off, and the first Pokémon knocked out loses. It plays each attack's printed damage plus the common effects
(coin flips, healing, extra Energy, self-damage, protection). Bench, drawing cards, prize cards, Evolution and Trainers
come in later levels.

## The cards

His cards are added in the app. The + on the pick screen opens the camera, which reads the code printed at the bottom
left of a card ("SVI 038/198"), or you can type a name. The card comes from TCGdex in Italian and English and is saved
on the iPad.

`cards.txt` lists the sample cards built into the app, one TCGdex id per line. `python3 tools/cards.py` turns it into `ios/App/Data/cards.json`,
with the Italian and English names and attacks, and fetches any missing sprites. To find an id from a card's name and
number: `python3 tools/cards.py find pikachu 25`. `python3 tools/cards.py sets` refreshes the table of set codes the camera
uses. Attack effects are matched by the patterns in `ios/App/Data/effects.json`, shared by the app and the script. The card pictures are downloaded during each build and are not kept
in this repo.

## Building

There's no Mac involved. XcodeGen (`ios/project.yml`) and GitHub Actions (`.github/workflows/ios.yml`) build it on a
cloud Mac. Every push sends back simulator screenshots, and `gh workflow run ios.yml -f testflight=true` sends a build
to TestFlight.

## Credits

Card data and pictures: [TCGdex](https://tcgdex.dev) (MIT). Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites)
(Pokémon Showdown's animated sprites). The sounds and the icon are made by `tools/sounds.py` and `tools/icon.py`.

This is an unofficial, non-commercial family project. Pokémon and its characters, card art and names are trademarks
and copyright of Nintendo, Creatures and GAME FREAK, and the Pokémon Company.
