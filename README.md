# Insieme

An iPad (or iPhone) helper for a parent and a child learning the Pokémon Trading Card Game together, playing with
their own cards on the table, in Italian or English. The iPad lies flat between the two players. The parent's half
(the bottom) is calm and has the instructions written out, assuming nobody knows a single rule: whose turn it is,
what to do with the cards ("put a Lightning Energy card under Pikachu's card"), and each part of a card the first time
it matters (HP, the Energy an attack needs, damage, Weakness). The child's half (the top, facing the child) has
pictures, numbers and single words. The app knows your cards and chooses a fair pair, does the damage maths and keeps
count. A voice can read the lines aloud, but it's off to start with: the parent does the talking.

The app has separate modes. **Learn** has three practice levels, each adding one thing from the real game:
1 Practice battle, 2 Team, 3 Retreat. Any Pokémon card with an attack that does damage can battle, evolved ones too
(on their own, as if they were Basic). **Decks** builds a deck of 60 cards each for the real game, step by step (see
below). The app's help during the real game comes next.

The voice, when on, is [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) (Apache 2.0), run on the iPad itself by
[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache 2.0), which uses espeak-ng to sound out the words. The
iPad's own voice takes over if Kokoro can't run.

**Level 1, the first battle:** one Pokémon each, with some Energy cards beside it. A coin decides who starts.
Each turn you put one Energy card on your Pokémon, then attack or tap DONE. Weakness doubles the damage, Resistance
takes some off, and the first Pokémon knocked out loses. It plays each attack's printed damage plus the common effects
(coin flips, healing, extra Energy, self-damage, protection, damage written in the text). Drawing cards, prize cards,
Evolution and Trainers come in the later levels.

**Level 2, Team:** three Pokémon each. One fights; the others wait behind it, on the bench. When one is knocked out,
its player taps who comes in next, and whoever knocks out the other's whole team wins.

**Level 3, Retreat:** the same teams, and once a turn the fighting Pokémon can retreat to the bench and let another
come in. It costs as many Energy cards as the circles next to "retreat" at the bottom of its card; its damage stays
with it.

**Decks:** five steps, on the board. Choose a type (he taps a symbol on his half), add about 20 Pokémon in whole
families and about 20 Trainers with the camera, count out the Energy that fills the deck up to 60, and check it against
the real rules (exactly 60, no more than 4 of the same card, at least one Basic Pokémon, one ACE SPEC at most). The
parent's half says what to do and why; the child's half shows his families with a gap where one is missing, the
counts, and the Energy cards to count out. Each card added says what it is: a Basic, what it evolves from, a
Trainer's kind (Item, Supporter, Pokémon Tool, Stadium) and what it does.

## The cards

Your cards are added in the app. CARDS, in the middle, opens the camera, which reads the code printed at the bottom
left of a card ("SVI 038/198"), or you can type a name. The card comes from TCGdex in Italian and English and is saved
on the iPad.

`cards.txt` lists the sample cards built into the app for the test games and screenshots made on each build (the app itself starts with none), one TCGdex id per line. `python3 tools/cards.py` turns it into `ios/App/Data/cards.json`,
with the Italian and English names and attacks, and fetches any missing sprites. To find an id from a card's name and
number: `python3 tools/cards.py find pikachu 25`. `python3 tools/cards.py sets` refreshes the table of sets (their codes, card counts and dates) that the camera
and the search use. Attack effects are matched by the patterns in `ios/App/Data/effects.json`, shared by the app and the script. The card pictures are downloaded during each build and are not kept
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
