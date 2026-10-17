#!/usr/bin/env python3
# The cards in the app, from cards.txt and TCGdex (api.tcgdex.net: free, open source, Italian and English).
#
#   python3 tools/cards.py              cards.txt → ios/App/Data/cards.json, plus any missing sprites in ios/App/Sprites
#   python3 tools/cards.py find NAME [NUMBER]   look a card up (English and Italian names both work)
#   python3 tools/cards.py art [DIR]    the card pictures, into ios/build/Cards (the cloud Mac runs this before each build)
#
# Only the standard library, so it runs as it is on the cloud Mac. The card pictures are never committed: the cloud Mac
# downloads them into the app. Sprites come from PokeAPI's sprite collection (github.com/PokeAPI/sprites) and are kept
# in the repo: Showdown's animated ones, or the plain one where there's none.
#
# The app plays each attack's printed damage, plus the effects it knows (EFFECTS below, read from the English text).
# Attacks whose effect it doesn't know yet do only their damage, and those with no damage are left out.
import json, re, sys, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST, OUT, SPRITES = ROOT / 'cards.txt', ROOT / 'ios/App/Data/cards.json', ROOT / 'ios/App/Sprites'
API = 'https://api.tcgdex.net/v2'
POKEAPI = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon'
# TCGdex's Italian names for the types, back to the English ones the app uses
TYPES_IT = {'Erba': 'Grass', 'Fuoco': 'Fire', 'Acqua': 'Water', 'Lampo': 'Lightning', 'Psico': 'Psychic', 'Lotta': 'Fighting',
            'Oscurità': 'Darkness', 'Metallo': 'Metal', 'Folletto': 'Fairy', 'Drago': 'Dragon', 'Incolore': 'Colorless'}

N = r'(\d+)'
EFFECTS = [  # (English effect text, what the app does); the whole text has to match
    (rf"Flip a coin\. If heads, this attack does {N} more damage\.", lambda m: {'kind': 'coinBonus', 'n': int(m[1])}),
    (r"Flip a coin\. If tails, this attack does nothing\.", lambda m: {'kind': 'coinNothing'}),
    (rf"Flip {N} coins\. This attack does {N} damage for each heads\.", lambda m: {'kind': 'coins', 'n': int(m[1]), 'each': int(m[2])}),
    (rf"Flip a coin until you get tails\. This attack does {N} damage for each heads\.", lambda m: {'kind': 'untilTails', 'each': int(m[1])}),
    (rf"Heal {N} damage from this Pokémon\.", lambda m: {'kind': 'heal', 'n': int(m[1])}),
    (rf"This Pokémon also does {N} damage to itself\.", lambda m: {'kind': 'self', 'n': int(m[1])}),
    (r"Search your deck for a Basic (\{\w\} )?Energy card and attach it to this Pokémon\. Then, shuffle your deck\.", lambda m: {'kind': 'attach', 'n': 1}),
    (rf"Search your deck for up to {N} Basic (\{{\w\}} )?Energy cards and attach them to this Pokémon\. Then, shuffle your deck\.", lambda m: {'kind': 'attach', 'n': int(m[1])}),
    (r"Attach a Basic (\{\w\} )?Energy card from your discard pile to this Pokémon\.", lambda m: {'kind': 'attach', 'n': 1}),
    (r"Discard (an|a|\d+|all) (\{\w\} )?Energy (card )?from this Pokémon\.", lambda m: {'kind': 'discard', 'n': 99 if m[1] == 'all' else 1 if m[1] in ('a', 'an') else int(m[1])}),
    (r"During your next turn, this Pokémon can't attack\.", lambda m: {'kind': 'lockSelf'}),
    (r"During your opponent's next turn, the Defending Pokémon can't attack\.", lambda m: {'kind': 'lockFoe'}),
    (r"Flip a coin\. If heads, during your opponent's next turn, prevent all damage (done to this Pokémon by attacks|from and effects of attacks done to this Pokémon)\.", lambda m: {'kind': 'protectCoin'}),
    (rf"During your opponent's next turn, this Pokémon takes {N} less damage from attacks( \(after applying Weakness and Resistance\))?\.", lambda m: {'kind': 'reduce', 'n': int(m[1])}),
    (rf"This attack does {N} more damage for each damage counter on your opponent's Active Pokémon\.", lambda m: {'kind': 'plusFoeCounters', 'each': int(m[1])}),
    (rf"This attack does {N} more damage for each damage counter on this Pokémon\.", lambda m: {'kind': 'plusOwnCounters', 'each': int(m[1])}),
    (rf"This attack does {N} more damage for each Energy attached to this Pokémon\.", lambda m: {'kind': 'plusOwnEnergy', 'each': int(m[1])}),
    (r"This attack's damage isn't affected by Weakness or Resistance.*", lambda m: {'kind': 'noWeakness'}),
]
FIX = {}  # by hand, when an effect is worded differently: {'sv03.5-039 Stompy Stomp': {'kind': 'coins', 'n': 2, 'each': 20}}


def get(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'insieme-cards'}), timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404: return None
            err = e
        except Exception as e:
            err = e
        time.sleep(1 + i)
    raise SystemExit(f'{url}: {err}')


def card(lang, cid):
    b = get(f'{API}/{lang}/cards/{cid}')
    return json.loads(b) if b else None


def effect(cid, attack):
    if f"{cid} {attack['name']}" in FIX: return FIX[f"{cid} {attack['name']}"]
    text = (attack.get('effect') or '').strip()
    if not text: return None
    for pattern, make in EFFECTS:
        m = re.fullmatch(pattern, text)
        if m: return make(m)
    return {'kind': 'skip'}  # not played yet: the attack does its printed damage only


def damage(d):
    m = re.fullmatch(r'(\d+)\s*([+×x\-]?)', str(d or '').strip())
    return (int(m[1]), {'x': '×'}.get(m[2], m[2]) or None) if m else (0, None)


def build():
    ids = [l.split('#')[0].split()[0] for l in LIST.read_text().splitlines() if l.split('#')[0].strip()]
    with ThreadPoolExecutor(6) as ex:
        en = list(ex.map(lambda i: card('en', i), ids))
        it = list(ex.map(lambda i: card('it', i), ids))
    cards, notes = [], []
    for cid, e, i in zip(ids, en, it):
        if not e: notes.append(f'{cid}: not on TCGdex'); continue
        if e.get('category') not in ('Pokemon', 'Pokémon'):
            notes.append(f"{cid} {e['name']}: a {e.get('category')} card, not used yet"); continue
        i = i or {}
        ia = i.get('attacks') or []
        attacks = []
        for k, a in enumerate(e.get('attacks') or []):
            dmg, mod = damage(a.get('damage'))
            fx = effect(cid, a)
            if fx and fx['kind'] == 'skip': notes.append(f"{cid} {e['name']} · {a['name']}: effect not played ({a['effect'][:70]})")
            attacks.append({'name': {'en': a['name'], 'it': ia[k]['name'] if k < len(ia) else a['name']},
                            'cost': a.get('cost') or [], 'damage': dmg, 'mod': mod, 'fx': fx})
        w, r = (e.get('weaknesses') or [{}])[0], (e.get('resistances') or [{}])[0]
        img, src = {}, {}
        for lang, c in (('en', e), ('it', i)):
            if c.get('image'): src[lang] = c['image'] + '/high.webp'
        file = cid.replace('.', '_') + '.webp'
        for lang in src: img[lang] = f'{lang}/{file}'
        if 'it' not in img and 'en' in img: notes.append(f"{cid} {e['name']}: no Italian picture, the English one is used")
        cards.append({
            'id': cid, 'dex': (e.get('dexId') or [None])[0], 'stage': e.get('stage'), 'hp': e.get('hp') or 0,
            'type': (e.get('types') or ['Colorless'])[0], 'weak': w.get('type'),
            'resist': r.get('type'), 'resistBy': abs(int(r['value'])) if r.get('value') else None,
            'retreat': e.get('retreat') or 0, 'evolvesFrom': e.get('evolveFrom'),
            'name': {'en': e['name'], 'it': i.get('name') or e['name']},
            'attacks': attacks, 'img': img, 'src': src})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(cards, ensure_ascii=False, indent=1) + '\n')
    SPRITES.mkdir(parents=True, exist_ok=True)
    for dex in sorted({c['dex'] for c in cards if c['dex']}):
        if (SPRITES / f'{dex}.gif').exists() or (SPRITES / f'{dex}.png').exists(): continue
        b = get(f'{POKEAPI}/other/showdown/{dex}.gif')
        if b: (SPRITES / f'{dex}.gif').write_bytes(b); continue
        b = get(f'{POKEAPI}/{dex}.png')
        if b: (SPRITES / f'{dex}.png').write_bytes(b)
        else: notes.append(f'#{dex}: no sprite')
    basics = sum(c['stage'] == 'Basic' for c in cards)
    print(f'{len(cards)} Pokémon ({basics} Basic) → {OUT.relative_to(ROOT)}')
    for n in notes: print('  ' + n)


def art(out):
    out = Path(out)
    jobs = [(src, out / c['img'][lang]) for c in json.loads(OUT.read_text()) for lang, src in c['src'].items()]
    def one(job):
        src, dest = job
        if dest.exists(): return 0
        dest.parent.mkdir(parents=True, exist_ok=True)
        b = get(src)
        if b: dest.write_bytes(b)
        return len(b or b'')
    with ThreadPoolExecutor(8) as ex: sizes = list(ex.map(one, jobs))
    print(f'{len(jobs)} card pictures in {out} ({sum(sizes) // 1024} KB downloaded)')


def find(name, number=None):
    for lang in ('en', 'it'):
        q = f'{API}/{lang}/cards?name={urllib.request.quote(name)}' + (f'&localId={int(number):03d}' if number else '')
        for c in json.loads(get(q) or b'[]')[:40]:
            print(f"{c['id']:16} {lang}  {c['name']}")
        if number and not json.loads(get(q) or b'[]'):  # promos and old sets don't pad the number
            for c in json.loads(get(f'{API}/{lang}/cards?name={urllib.request.quote(name)}&localId={number}') or b'[]')[:40]:
                print(f"{c['id']:16} {lang}  {c['name']}")


if __name__ == '__main__':
    a = sys.argv[1:]
    if a[:1] == ['find']: find(*a[1:3])
    elif a[:1] == ['art']: art(a[1] if len(a) > 1 else ROOT / 'ios/build/Cards')
    else: build()
