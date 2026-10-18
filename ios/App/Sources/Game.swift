import SwiftUI
import UIKit
import Observation

// Level 1, the first battle: one Basic Pokémon each. A coin decides who starts. Each turn: one Energy, then an attack
// (or DONE). Weakness doubles the damage, Resistance takes some off, and the first Pokémon knocked out loses. The real
// rule that whoever goes first can't attack on their very first turn is kept. The app gives the Energy: one of the
// type its next attack needs. Side 0 is the bottom half of the screen, side 1 the top.

enum Step { case pick, coin, battle, over }

struct Side {
    var card: Card?
    var energy: [String] = []
    var damage = 0
    var gaveEnergy = false
    var shield = false   // no damage during the opponent's next turn
    var reduce = 0       // this much less damage during the opponent's next turn
    var locked = false   // can't attack this turn
    var lockNext = false // can't attack during its next turn
    var hp: Int { max(0, (card?.hp ?? 0) - damage) }
}

/// A line of the game, written at the top of each half during the battle.
struct Caption: Identifiable, Equatable {
    let id: Int
    let text: String
}

/// A number flying off a Pokémon: "-30", "+20".
struct Pop: Equatable {
    let side: Int
    let text: String
    let id: Int
}

@MainActor @Observable final class Game {
    var lang: Lang = Lang(rawValue: UserDefaults.standard.string(forKey: "lang") ?? "") ?? .it
    var step: Step = .pick
    var sides = [Side(), Side()]
    var turn = 0      // whose turn it is
    var turns = 0     // turns played; 0 is the very first
    var busy = false  // an attack is playing out
    var winner: Int?
    var coinOut = false
    var coinAngle = 0.0
    var coinPokemon = true // the coin has the two Pokémon on it (who starts), or heads and tails
    var lunge: Int?        // the side whose Pokémon is jumping at the other
    var shakes = [0, 0]    // bumped on each hit, to shake that side's Pokémon
    var pop: Pop?
    var banner: Int?       // "your turn!" over that side
    var zoom = [false, false]
    // The voice is off unless switched on (Jordan, 18 Oct 2026: "I'll be talking to him the whole time"); the parent's
    // half has the lines written out.
    var quiet = UserDefaults.standard.object(forKey: "quiet") == nil ? true : UserDefaults.standard.bool(forKey: "quiet")
    var level = 1             // 1 practice battle; 2 and 3 aren't built yet
    var levelNote: String?    // said when a level that isn't built is tapped
    var pictures = 0          // bumped when card pictures that were missing have downloaded, to redraw
    var captions: [Caption] = []                            // the last lines, written during the battle

    let voice = Voice()
    var mine: [Card] = Store.load() // your cards, added with CARDS (AddView): one box for both players
    var adding = false
    /// The cards the Poké Ball chooses from: only yours (Jordan, 18 Oct 2026: "it needs to be blank, and we just add the
    /// ones that we have"). The sample cards only on the cloud Mac (-demo, -auto), for the screenshots.
    var cards: [Card] {
        let yours = mine.filter(\.playable)
        return (yours.count >= 2 || !trial ? yours : Card.all.filter(\.playable)).sorted { ($0.dex ?? 0) < ($1.dex ?? 0) }
    }
    private let trial = UserDefaults.standard.string(forKey: "demo") != nil || UserDefaults.standard.bool(forKey: "auto")
    @ObservationIgnored var told = Set<String>() // the longer explanations, said once each time the app opens
    @ObservationIgnored var popID = 0
    @ObservationIgnored var captionID = 0
    let fast = UserDefaults.standard.bool(forKey: "fast")

    func name(_ s: Int) -> String { sides[s].card?.name(lang) ?? "" }
    func card(_ id: String) -> Card? { cards.first { $0.id == id } }

    func boot() {
        UIApplication.shared.isIdleTimerDisabled = true
        voice.lang = lang
        voice.fast = fast
        voice.quiet = quiet
        note("\(cards.count) cards, language \(lang.rawValue)")
        let demo = UserDefaults.standard.string(forKey: "demo") ?? ""
        if demo == "ready", cards.count > 1 { // the Poké Ball has chosen
            sides[0].card = card("sv03.5-025") ?? cards[0]
            sides[1].card = card("sv03.5-004") ?? cards[1]
        }
        if ["battle", "zoom", "over"].contains(demo), cards.count > 1 {
            sides[0] = Side(card: card("sv03.5-025") ?? cards[0], energy: ["Lightning", "Lightning"], damage: 20)
            sides[1] = Side(card: card("sv03.5-004") ?? cards[1], energy: ["Fire"], damage: 30)
            turns = 3
            step = .battle
            zoom[0] = demo == "zoom"
            if demo == "over" { winner = 0; step = .over }
            captions = [Caption(id: -2, text: Say.damage(lang, 30)), Caption(id: -1, text: Say.turnFirst(lang, name(0), "Lightning"))]
        }
        if demo == "add" { adding = true }
        if let ids = UserDefaults.standard.string(forKey: "add") { // the cloud Mac: add these cards as the add screen would
            Task {
                for id in ids.split(separator: ",") {
                    if case .ok(let c) = await TCGdex.fetch(String(id)) {
                        add(c)
                        note("added \(c.id) picture \(Art.missing(c).isEmpty ? "ok" : "MISSING") \(c.name.en)/\(c.name.it) \(c.stage ?? "") \(c.hp) HP, " + c.attacks.map { "\($0.name.en) \($0.damage)\($0.mod ?? "") \($0.fx?.kind ?? "-")" }.joined(separator: "; "))
                    } else { note("could not add \(id)") }
                }
            }
        }
        if UserDefaults.standard.bool(forKey: "auto") { Task { await autoplay() } }
        else if step == .pick { speak(sides[0].card == nil ? Say.start(lang, cards.count) : Say.chosen(lang, name(0), name(1)) + " " + Say.ready(lang)) }
        warm()
        if UserDefaults.standard.bool(forKey: "voicetest") { Task { await voiceTest() } }
        if UserDefaults.standard.bool(forKey: "scantest") { Task { await scanTest() } }
        if let id = UserDefaults.standard.string(forKey: "breakpicture"), let c = mine.first(where: { $0.id == id }) {
            for file in c.img.values { try? FileManager.default.removeItem(at: Store.docs.appendingPathComponent("Cards/" + file)) }
            note("breakpicture: removed \(id)'s pictures") // the cloud Mac: as if their download had failed
        }
        Task { await repairPictures() }
        if UserDefaults.standard.bool(forKey: "prerender") { Task { await prerender() } }
    }

    /// Kokoro makes ahead of time the sentences every game says (when the app opens, the language changes or the voice
    /// comes back on; and on the cloud Mac, `prerender`). Each Pokémon's own are made when it's added or chosen.
    func warm() {
        let l = lang, z = "ZZ" // a stand-in name: sentences with a Pokémon's name in them are left for warm(card)
        var lines = [Say.start(l, 0), Say.start(l, 1), Say.start(l, 2), Say.ready(l), Say.flip(l), Say.firstTurnRule(l), Say.canAttack(l),
                     Say.notEnough(l), Say.oneEnergy(l), Say.energyFirst(l), Say.heads(l), Say.tails(l), Say.nothing(l),
                     Say.coinTeach(l), Say.again(l), Say.language(l), Say.voiceOn(l), Say.chosen(l, z, z),
                     Say.notEnoughTeach(l, z, 1), Say.canAttackTeach(l, z), Say.leftTeach(l, z, 60, 20, 40)]
        lines += ["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting", "Darkness", "Metal", "Colorless"].map { Say.turn(l, z, $0) }
        lines += stride(from: 10, through: 200, by: 10).map { Say.damage(l, $0) }
        voice.prepare(lines.flatMap(Kokoro.sentences).filter { !$0.contains(z) }, .later)
    }

    func warm(_ c: Card, _ when: Kokoro.When = .soon) {
        let l = lang, n = c.name(l)
        var lines = [Say.starts(l, n), Say.allEnergy(l, n), Say.ko(l, n), Say.wins(l, n), Say.wait(l, n)]
        lines += Set(c.moves.flatMap(\.cost) + [c.type]).sorted().map { Say.turn(l, n, $0) }
        lines += c.moves.map { Say.uses(l, n, $0.name(l)) }
        lines += stride(from: c.hp - 10, to: 0, by: -10).map { Say.left(l, n, $0) }
        voice.prepare(lines, when)
    }

    /// -prerender (the cloud Mac, before a TestFlight build, ios/ci/voice.sh): every game's sentences in both languages,
    /// to go in the app.
    func prerender() async {
        for l in [Lang.it, .en] {
            lang = l
            voice.lang = l
            warm()
        }
        await pause(3)
        while Kokoro.shared.pending > 0 { await pause(2) }
        note("prerender: done")
    }

    /// -voicetest (the cloud Mac): how long Kokoro takes to make some lines, in the log.
    func voiceTest() async {
        note("voicetest: kokoro \(Kokoro.shared.on ? "on" : "off")")
        for l in [Lang.it, .en] {
            setLang(l)
            await say(Say.chosen(l, "Pikachu", "Charmander"))
            await say(Say.turnFirst(l, "Pikachu", "Lightning"))
        }
        note("voicetest: done")
    }

    /// -scantest (the cloud Mac, which has no camera): what the camera reads from one card held still, a frame every
    /// 50 ms, each line read a little differently and one digit misread. It must be looked up once (build 20 flickered
    /// looking it up again and again); ios/ci/sim-shots.sh fails otherwise.
    func scanTest() async {
        let adder = Adder(game: self)
        let frames = [["SHF EN 001/072"], ["0 001/072 ●"], ["SHF 001/072", "Rowlet"], ["SHF EN 007/072"], ["001/072"]]
        for i in 0..<30 {
            adder.scan(frames[i % frames.count])
            await pause(0.05)
        }
        while adder.busy { await pause(0.1) }
        note("scantest: \(adder.lookups) lookup\(adder.lookups == 1 ? "" : "s"), found \(adder.found.map(\.id))")
    }

    /// Card pictures that didn't download when the card was added: tried again each time the app opens.
    func repairPictures() async {
        let broken = mine.filter { !Art.missing($0).isEmpty }
        guard !broken.isEmpty else { return }
        var fixed = 0
        for c in broken where await TCGdex.repair(c) { fixed += 1 }
        note("pictures: \(broken.count) cards missing one, \(fixed) repaired")
        if fixed > 0 { pictures += 1 }
    }

    func setLang(_ l: Lang) {
        lang = l
        voice.lang = l
        UserDefaults.standard.set(l.rawValue, forKey: "lang")
        speak(Say.language(l) + (step == .pick && sides[0].card == nil ? " " + Say.start(l, cards.count) : ""))
        warm()
        for c in sides.compactMap(\.card) { warm(c) }
    }

    func setQuiet(_ q: Bool) {
        quiet = q
        voice.quiet = q
        UserDefaults.standard.set(q, forKey: "quiet")
        Sound.play("pop")
        if !q {
            speak(Say.voiceOn(lang))
            warm()
            for c in sides.compactMap(\.card) { warm(c) }
        }
    }

    /// Everything the game says goes through here: spoken, or shown when the voice is off.
    func say(_ text: String) async {
        guard !text.isEmpty else { return }
        captionID += 1
        withAnimation(.easeOut(duration: 0.2)) { captions = Array((captions + [Caption(id: captionID, text: text)]).suffix(2)) }
        await voice.say(text)
    }

    func speak(_ text: String) { Task { await say(text) } }

    func add(_ c: Card) {
        mine.removeAll { $0.id == c.id }
        mine.append(c)
        Store.save(mine)
        if c.playable { warm(c, .later) }
    }

    func remove(_ id: String) {
        mine.removeAll { $0.id == id }
        Store.save(mine)
    }

    func openAdding() {
        voice.stop()
        adding = true
    }

    func closeAdding() {
        adding = false
        if step == .pick { sides = [Side(), Side()]; speak(Say.start(lang, cards.count)) } // the cards may have changed
    }

    // MARK: Choosing

    func setLevel(_ n: Int) {
        guard step == .pick else { return }
        levelNote = n == 1 ? nil : Say.levelSoon(lang)
        Sound.play("pop")
    }

    /// The Energy cards to put next to a Pokémon before the battle: exactly what its strongest attack needs (its own
    /// type for a Colorless cost). Build 29 showed four for every Pokémon, which looked like a rule (Jordan: "why are
    /// there four energy cards here").
    func energyFor(_ c: Card) -> [String] {
        let cost = (strongest(c)?.cost ?? []).map { $0 == "Colorless" ? c.type : $0 }
        return cost.isEmpty ? [c.type] : cost
    }

    func strongest(_ c: Card) -> Attack? { c.moves.max { $0.cost.count < $1.cost.count } }

    /// Enough Energy for its strongest attack: no more ENERGY step, straight to attacking.
    func hasAll(_ s: Int) -> Bool {
        guard let a = sides[s].card.flatMap(strongest) else { return true }
        return canPay(a.cost, sides[s].energy)
    }

    /// The Poké Ball at the start: the app chooses a Pokémon for each player. The second has about the same HP as the
    /// first, so it's a fair fight.
    func choose() {
        guard step == .pick, !busy, cards.count > 1 else { return }
        for s in [0, 1].shuffled() where sides[s].card == nil {
            let other = sides[1 - s].card
            var pool = cards.filter { $0.name.en != other?.name.en }
            if pool.isEmpty { pool = cards.filter { $0.id != other?.id } }
            guard let o = other else { sides[s].card = pool.randomElement(); continue }
            let near = pool.filter { abs($0.hp - o.hp) <= 20 }
            sides[s].card = (near.isEmpty ? Array(pool.sorted { abs($0.hp - o.hp) < abs($1.hp - o.hp) }.prefix(3)) : near).randomElement()
        }
        Sound.play("pop")
        for c in sides.compactMap(\.card) { warm(c) }
        note("chose \(name(0)) \(sides[0].card?.hp ?? 0) HP against \(name(1)) \(sides[1].card?.hp ?? 0) HP")
        speak(Say.chosen(lang, name(0), name(1)) + " " + Say.ready(lang))
    }

    /// The Poké Ball in the middle: choose the Pokémon, start, say it again, or play again.
    func ball() {
        switch step {
        case .pick:
            if sides.allSatisfy({ $0.card != nil }) { Task { await go() } }
            else if cards.count < 2 { speak(Say.start(lang, cards.count)) }
            else { choose() }
        case .over: again()
        case .coin, .battle: if !quiet { speak(voice.last) }
        }
    }

    /// Holding the Poké Ball: back to the start (from the battle, or to choose other Pokémon).
    func quit() {
        if step == .pick, sides[0].card != nil {
            sides = [Side(), Side()]
            Sound.play("pop")
            speak(Say.start(lang, cards.count))
            return
        }
        guard step == .battle, !busy else { return }
        again()
    }

    func again() {
        winner = nil
        zoom = [false, false]
        sides = [Side(), Side()]
        step = .pick
        Sound.play("pop")
        speak(Say.again(lang))
    }

    func go() async {
        guard step == .pick, !busy, let a = sides[0].card, let b = sides[1].card else { return }
        busy = true
        sides = [Side(card: a), Side(card: b)]
        turns = 0
        winner = nil
        step = .coin
        speak(Say.flip(lang))
        let first = Int.random(in: 0...1)
        await flip(front: first == 0, pokemon: true)
        turn = first
        await say(Say.starts(lang, name(first)))
        withAnimation { coinOut = false }
        step = .battle
        busy = false
        await startTurn()
    }

    // MARK: Turns

    func startTurn() async {
        let s = turn
        sides[s].gaveEnergy = false
        sides[s].shield = false // these lasted through the opponent's turn
        sides[s].reduce = 0
        if sides[s].lockNext { sides[s].locked = true; sides[s].lockNext = false }
        note("turn \(turns): \(name(s)) \(sides[s].hp) HP, energy \(sides[s].energy.joined(separator: " ")); \(name(1 - s)) \(sides[1 - s].hp) HP")
        Sound.play("turn")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { banner = s }
        Task {
            await pause(1.6)
            if banner == s { withAnimation { banner = nil } }
        }
        if hasAll(s) { // nothing left to put on: attack (or DONE if it can't this turn)
            sides[s].gaveEnergy = true
            await say(sides[s].locked ? Say.locked(lang, name(s)) : Say.allEnergy(lang, name(s)))
            return
        }
        let e = nextEnergy(s)
        if told.insert("energy").inserted { await say(Say.turnFirst(lang, name(s), e)) }
        else { await say(Say.turn(lang, name(s), e)) }
    }

    func giveEnergy(_ s: Int) async {
        guard step == .battle, !busy else { return }
        guard s == turn else { await say(Say.wait(lang, name(turn))); return }
        guard !sides[s].gaveEnergy else { await say(hasAll(s) ? Say.allEnergy(lang, name(s)) : Say.oneEnergy(lang)); return }
        let t = nextEnergy(s)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            sides[s].energy.append(t)
            sides[s].gaveEnergy = true
        }
        Sound.play("energy")
        if turns == 0 { await say(Say.firstTurnRule(lang)); return }
        if sides[s].locked { await say(Say.locked(lang, name(s))); return }
        let teach = told.insert("cost").inserted // the attacks' Energy circles, explained the first time
        if usable(s).isEmpty { await say(teach ? Say.notEnoughTeach(lang, name(s), sides[s].energy.count) : Say.notEnough(lang)) }
        else if teach { told.insert("attack"); await say(Say.canAttackTeach(lang, name(s))) }
        else if told.insert("attack").inserted { await say(Say.canAttackFirst(lang, name(s))) }
        else { await say(Say.canAttack(lang)) }
    }

    /// DONE: the turn passes.
    func done(_ s: Int) async {
        guard step == .battle, !busy else { return }
        guard s == turn else { await say(Say.wait(lang, name(turn))); return }
        guard sides[s].gaveEnergy else { await say(Say.energyFirst(lang)); return }
        await endTurn()
    }

    private func endTurn() async {
        sides[turn].locked = false
        turn = 1 - turn
        turns += 1
        await startTurn()
    }

    // MARK: Energy

    /// Typed costs need that type; Colorless takes any.
    func canPay(_ cost: [String], _ have: [String]) -> Bool {
        var pool = have
        for t in cost where t != "Colorless" {
            guard let i = pool.firstIndex(of: t) else { return false }
            pool.remove(at: i)
        }
        return pool.count >= cost.filter { $0 == "Colorless" }.count
    }

    func usable(_ s: Int) -> [Int] {
        let moves = sides[s].card?.moves ?? []
        return moves.indices.filter { canPay(moves[$0].cost, sides[s].energy) }
    }

    /// The Energy the app gives: the type the cheapest attack it can't pay for yet is missing, or the Pokémon's own.
    func nextEnergy(_ s: Int) -> String {
        guard let c = sides[s].card else { return "Colorless" }
        for a in c.moves.sorted(by: { $0.cost.count < $1.cost.count }) {
            var pool = sides[s].energy
            for t in a.cost where t != "Colorless" {
                if let i = pool.firstIndex(of: t) { pool.remove(at: i) } else { return t }
            }
        }
        return c.type
    }

    // MARK: Attacking

    func attack(_ s: Int, _ i: Int) async {
        guard step == .battle, !busy, let me = sides[s].card, i < me.moves.count, let foe = sides[1 - s].card else { return }
        let a = me.moves[i]
        guard s == turn else { await say(Say.wait(lang, name(turn))); return }
        guard sides[s].gaveEnergy else { await say(Say.energyFirst(lang)); return }
        guard turns > 0 else { await say(Say.firstTurnRule(lang)); return }
        guard !sides[s].locked else { await say(Say.locked(lang, name(s))); return }
        guard canPay(a.cost, sides[s].energy) else {
            await say(Say.needs(lang, a.name(lang), a.cost.count, sides[s].energy.count))
            return
        }
        busy = true
        let f = 1 - s
        let kind = a.fx?.kind ?? "", n = a.fx?.n ?? 0, each = a.fx?.each ?? 0
        await say(Say.uses(lang, name(s), a.name(lang)))

        var dmg = a.damage, nothing = false
        switch kind {
        case "coinBonus":
            if await coinFlip() { dmg += n }
        case "coinNothing":
            if !(await coinFlip()) { dmg = 0; nothing = true }
        case "coins", "untilTails":
            var heads = 0
            for _ in 0..<(kind == "coins" ? max(1, n) : 8) { // until tails: 8 heads at most
                if await coinFlip() { heads += 1 } else if kind == "untilTails" { break }
            }
            dmg = each * heads
            nothing = heads == 0
        case "plusFoeCounters": dmg += each * (sides[f].damage / 10)
        case "plusOwnCounters": dmg += each * (sides[s].damage / 10)
        case "plusOwnEnergy": dmg += each * sides[s].energy.count
        default: break
        }
        var weak = false, resisted = false, shielded = false, toughened = false
        if dmg > 0 && kind != "noWeakness" {
            if foe.weak == me.type { dmg *= 2; weak = true }
            if foe.resist == me.type { dmg = max(0, dmg - (foe.resistBy ?? 30)); resisted = true }
        }
        let before = dmg // after Weakness and Resistance, before the defender's own protection
        if dmg > 0 && sides[f].shield { dmg = 0; shielded = true }
        if dmg > 0 && sides[f].reduce > 0 { dmg = max(0, dmg - sides[f].reduce); toughened = true }

        // The hit
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { lunge = s }
        Sound.play("whoosh")
        await pause(0.22)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { lunge = nil }
        if dmg > 0 {
            Sound.play(weak ? "bighit" : "hit")
            withAnimation(.linear(duration: 0.5)) { shakes[f] += 1 }
            withAnimation(.easeOut(duration: 0.4)) { sides[f].damage += dmg }
            show("-\(dmg)", on: f)
        }
        withAnimation { coinOut = false }
        if shielded { await say(Say.shielded(lang, name(f))) }
        else {
            if weak { await say((told.insert("weak").inserted ? Say.weakTeach : Say.weak)(lang, name(f), Kind.name(me.type, lang), before)) }
            else if resisted { await say(Say.resisted(lang, name(f), before)) }
            if toughened { await say(Say.toughened(lang, name(f), dmg)) }
            else if !weak && !resisted { await say(dmg > 0 ? Say.damage(lang, dmg) : nothing || a.damage > 0 ? Say.nothing(lang) : "") }
        }

        // What happens after the damage
        switch kind {
        case "heal":
            let h = min(n, sides[s].damage)
            if h > 0 {
                withAnimation(.easeOut(duration: 0.4)) { sides[s].damage -= h }
                show("+\(h)", on: s)
                Sound.play("heal")
                await say(Say.heal(lang, name(s), h))
            }
        case "attach":
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                for _ in 0..<max(1, n) { sides[s].energy.append(nextEnergy(s)) }
            }
            Sound.play("energy")
            await say(Say.extraEnergy(lang, name(s)))
        case "self":
            Sound.play("hit")
            withAnimation(.linear(duration: 0.5)) { shakes[s] += 1 }
            withAnimation(.easeOut(duration: 0.4)) { sides[s].damage += n }
            show("-\(n)", on: s)
            await say(Say.selfHit(lang, name(s), n))
        case "discard":
            let k = min(n, sides[s].energy.count)
            if k > 0 {
                withAnimation { sides[s].energy.removeLast(k) }
                await say(Say.discard(lang, name(s), k))
            }
        case "protectCoin":
            if await coinFlip() {
                sides[s].shield = true
                await say(Say.shieldUp(lang, name(s)))
            }
            withAnimation { coinOut = false }
        case "reduce":
            sides[s].reduce = n
            await say(Say.braced(lang, name(s), n))
        case "lockSelf":
            sides[s].lockNext = true
            await say(Say.restNext(lang, name(s)))
        case "lockFoe":
            sides[f].locked = true
            await say(Say.foeLocked(lang, name(f)))
        default: break
        }

        if sides[f].hp == 0 { await knockOut(f); return }
        if sides[s].hp == 0 { await knockOut(s); return } // it hurt itself too much
        if dmg > 0 {
            if told.insert("count").inserted { await say(Say.leftTeach(lang, name(f), foe.hp, sides[f].damage, sides[f].hp)) }
            else { await say(Say.left(lang, name(f), sides[f].hp)) }
        }
        busy = false
        await endTurn()
    }

    private func knockOut(_ k: Int) async {
        Sound.play("ko")
        winner = 1 - k
        note("KO: \(name(k)); \(name(1 - k)) wins after \(turns + 1) turns")
        await say(Say.ko(lang, name(k)))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { step = .over }
        busy = false
        Sound.play("win")
        await pause(0.6)
        await say(Say.wins(lang, name(1 - k)))
    }

    // MARK: The coin

    /// Spins the coin in the middle and lands it: front is the bottom player's Pokémon (or heads), back the top's (or tails).
    func flip(front: Bool, pokemon: Bool) async {
        coinPokemon = pokemon
        coinOut = true
        let target = coinAngle - coinAngle.truncatingRemainder(dividingBy: 360) + 360 * 5 + (front ? 0 : 180)
        Sound.play("coin")
        withAnimation(.easeOut(duration: fast ? 0.2 : 1.4)) { coinAngle = target }
        await pause(fast ? 0.25 : 1.5)
    }

    func coinFlip() async -> Bool {
        if told.insert("coin").inserted { await say(Say.coinTeach(lang)) }
        let heads = Bool.random()
        await flip(front: heads, pokemon: false)
        await say(heads ? Say.heads(lang) : Say.tails(lang))
        return heads
    }

    // MARK: Little things

    /// Tapping a card: show it big and read it out.
    func read(_ s: Int) {
        guard let c = sides[s].card else { return }
        withAnimation(.easeOut(duration: 0.2)) { zoom[s].toggle() }
        if zoom[s] { speak(Say.card(lang, c)) } else if !quiet { voice.stop() }
    }

    func show(_ text: String, on s: Int) {
        popID += 1
        let id = popID
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pop = Pop(side: s, text: text, id: id) }
        Task {
            await pause(1.3)
            if pop?.id == id { withAnimation(.easeOut) { pop = nil } }
        }
    }

    func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9))
    }

    /// -auto (the cloud Mac): two random Pokémon play a whole game by themselves.
    func autoplay() async {
        guard cards.count > 1 else { return }
        await pause(1)
        choose()
        await pause(0.5)
        await go()
        var moves = 0
        while step == .battle && moves < 80 {
            moves += 1
            await pause(fast ? 0.4 : 1.2)
            let s = turn
            await giveEnergy(s)
            await pause(0.4)
            if turns > 0, !sides[s].locked, let i = usable(s).last { await attack(s, i) } else { await done(s) }
        }
        note("auto: finished, winner \(winner.map { name($0) } ?? "none")")
    }
}
