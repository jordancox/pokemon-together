# Insieme

An iPad app for a parent and a child to learn the Pokémon Trading Card Game together, with the child's own cards, in
Italian or English. The iPad lies flat between the two players, and each gets half of the screen. A voice runs the game:
whose turn it is, what to do next, the damage, Weakness, who wins. On screen there are a few big words in capitals and
the numbers. With the voice switched off, the same lines show as text for the parent to read aloud.

**Level 1, the first battle:** one Basic Pokémon each. A coin decides who starts. Each turn you give one Energy, then
attack or tap DONE. Weakness doubles the damage, Resistance takes some off, and the first Pokémon knocked out loses.
The app supplies the Energy. It plays each attack's printed damage plus the common effects (coin flips, healing,
extra Energy, self-damage, protection). Bench, prize cards, Evolution and Trainers come in later levels.

## The cards

`cards.txt` lists the cards, one TCGdex id per line. `python3 tools/cards.py` turns it into `ios/App/Data/cards.json`,
with the Italian and English names and attacks, and fetches any missing sprites. To find an id from a card's name and
number: `python3 tools/cards.py find pikachu 25`. The card pictures are downloaded during each build and are not kept
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
