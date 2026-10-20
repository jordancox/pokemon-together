import SwiftUI
import UIKit
import Observation

// Level 1, the first battle: one Pokémon each. A coin decides who starts. Each turn: one Energy, then an attack (or
// DONE). Weakness doubles the damage, Resistance takes some off, and the first Pokémon knocked out loses. The real rule
// that whoever goes first can't attack on their very first turn is kept. The app gives the Energy: one of the type its
// next attack needs. Level 2, Team: three Pokémon each, one fighting and the others waiting on the bench; when one is
// knocked out, its player chooses who comes in, and the first to lose the whole team loses. Level 3, Retreat: once a
// turn, the fighting Pokémon can go back to the bench for one there, paying its retreat cost in Energy. Side 0 is the
// bottom half of the screen, side 1 the top.

enum Step { case pick, coin, battle, over }

/// One Pokémon on the table: its card, the Energy on it and the damage it has taken (kept on the bench too).
struct Mon {
    var card: Card
    var energy: [String] = []
    var damage = 0
    var hp: Int { max(0, card.hp - damage) }
}

/// One player: their Pokémon (one in level 1, a team from level 2), which of them is fighting, and this turn so far.
struct Side {
    var team: [Mon] = []
    var active = 0          // the one fighting; the rest wait on the bench
    var gaveEnergy = false  // the Energy step is done this turn (one put on, or it needs no more)
    var attached = false    // an Energy card went on this turn
    var retreated = false   // level 3: once a turn
    var shield = false   // no damage during the opponent's next turn
    var reduce = 0       // this much less damage during the opponent's next turn
    var locked = false   // can't attack this turn
    var lockNext = false // can't attack during its next turn

    init(_ cards: [Card] = []) { team = cards.map { Mon(card: $0) } }

    var card: Card? { team.indices.contains(active) ? team[active].card : nil }
    var energy: [String] {
        get { team.indices.contains(active) ? team[active].energy : [] }
        set { if team.indices.contains(active) { team[active].energy = newValue } }
    }
    var damage: Int {
        get { team.indices.contains(active) ? team[active].damage : 0 }
        set { if team.indices.contains(active) { team[active].damage = newValue } }
    }
    var hp: Int { team.indices.contains(active) ? team[active].hp : 0 }
    /// The team waiting behind the one fighting, not knocked out.
    var bench: [Int] { team.indices.filter { $0 != active && team[$0].hp > 0 } }
    /// Not knocked out yet, the one fighting included.
    var left: Int { team.filter { $0.hp > 0 }.count }
}

/// Why a player is choosing a Pokémon from the bench.
enum Why { case ko, retreat }

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
    var choosing: Int?     // the side choosing who comes in from its bench (its half shows them, to tap)
    var nudge = 0          // bumped when the Poké Ball can't start a battle, to shake the reason why
    // The voice is off unless switched on (Jordan, 18 Oct 2026: "I'll be talking to him the whole time"); the parent's
    // half has the lines written out.
    var quiet = UserDefaults.standard.object(forKey: "quiet") == nil ? true : UserDefaults.standard.bool(forKey: "quiet")
    var level = min(max(UserDefaults.standard.integer(forKey: "level"), 1), Say.built) // the last one played
    var levelNote: String?    // said when a level that isn't built is tapped
    var pictures = 0          // bumped when card pictures that were missing have downloaded, to redraw
    var captions: [Caption] = []                            // this game's lines, written on the parent's half

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
    @ObservationIgnored var why = Why.ko
    @ObservationIgnored var waiting: [Int] = [] // the sides still to bring a Pokémon in after a knockout
    @ObservationIgnored var popID = 0
    @ObservationIgnored var captionID = 0
    let fast = UserDefaults.standard.bool(forKey: "fast")

    func name(_ s: Int) -> String { sides[s].card?.name(lang) ?? "" }
    func card(_ id: String) -> Card? { cards.first { $0.id == id } }

    /// How many Pokémon each player has: one in level 1; from level 2 a team of three (two when there are only four or
    /// five cards).
    var size: Int { level == 1 ? 1 : min(3, cards.count / 2) }
    /// The cards a battle needs: one each in level 1, at least two each from level 2.
    var need: Int { level == 1 ? 2 : 4 }
    var canStart: Bool { cards.count >= need }
    /// The parent's half before a battle: what this level is and what to tap, or plainly why it can't start yet
    /// (Jordan, 20 Oct 2026: "it's not clear why the battle won't start sometimes").
    func intro() -> String {
        canStart ? Say.start(lang, level, size)
            : Say.cantStart(lang, level: level, can: cards.count, need: need, added: mine.count,
                            out: mine.filter { !$0.playable }.map { $0.name(lang) })
    }

    /// Said once the Poké Ball has chosen: who, and how to set the cards out.
    func chosenLine() -> String {
        level == 1 ? Say.chosen(lang, name(0), name(1)) + " " + Say.ready(lang) : Say.chosenTeam(lang) + " " + Say.setUpTeam(lang)
    }

    func boot() {
        UIApplication.shared.isIdleTimerDisabled = true
        voice.lang = lang
        voice.fast = fast
        voice.quiet = quiet
        if let only = UserDefaults.standard.string(forKey: "only") { // the cloud Mac: as if only these were added (not saved)
            let ids = Set(only.split(separator: ",").map(String.init))
            mine = mine.filter { ids.contains($0.id) }
        }
        note("\(cards.count) cards, language \(lang.rawValue), level \(level)")
        if !canStart { note("can't start: \(intro())") }
        let demo = UserDefaults.standard.string(forKey: "demo") ?? ""
        if ["ready", "battle", "zoom", "over", "next"].contains(demo), canStart { // the Poké Ball has chosen
            // the same Pokémon on every screenshot: Pikachu (and team) at the bottom, Charmander (and team) at the top
            let ids = [["sv03.5-025", "sv03.5-074", "sv03.5-133"], ["sv03.5-004", "sv03.5-007", "sv03.5-001"]]
            for s in [0, 1] {
                let team = ids[s].prefix(size).compactMap(card)
                sides[s] = Side(team.count == size ? team : Array(cards[(s * size)..<(s * size + size)]))
            }
        }
        if ["battle", "zoom", "over", "next"].contains(demo), canStart {
            sides[0].energy = ["Lightning", "Lightning"]
            sides[0].damage = 20
            sides[1].energy = ["Fire"]
            sides[1].damage = 30
            if size > 2 { sides[0].team[2].damage = sides[0].team[2].card.hp } // one of the parent's team already knocked out
            turns = 3
            step = .battle
            zoom[0] = demo == "zoom"
            if demo == "over" { winner = 0; step = .over }
            captions = [Caption(id: -2, text: Say.damage(lang, 30)), Caption(id: -1, text: Say.turnFirst(lang, name(0), "Lightning"))]
            if demo == "next", size > 1 { // his Pokémon has just been knocked out: he chooses who comes in
                sides[1].damage = sides[1].card?.hp ?? 0
                why = .ko
                choosing = 1
                captions += [Caption(id: -4, text: Say.koTeam(lang, name(1))), Caption(id: -3, text: Say.whoNext(lang, name(1)))]
            }
        }
        if demo == "add" { adding = true }
        if let ids = UserDefaults.standard.string(forKey: "add") { // the cloud Mac: add these cards as the add screen would
            Task {
                for id in ids.split(separator: ",") {
                    if case .ok(let c) = await TCGdex.fetch(String(id)) {
                        add(c)
                        _ = await TCGdex.finish(c)
                        note("added \(c.id) picture \(Art.missing(c).isEmpty ? "ok" : "MISSING") \(c.name.en)/\(c.name.it) \(c.stage ?? "") \(c.hp) HP, battles \(c.playable ? "yes" : "no"), " + c.attacks.map { "\($0.name.en) \($0.damage)\($0.mod ?? "") \($0.fx?.kind ?? "-")" }.joined(separator: "; "))
                    } else { note("could not add \(id)") }
                }
            }
        }
        if UserDefaults.standard.bool(forKey: "auto") { Task { await autoplay() } }
        else if step == .pick { speak(sides[0].card == nil ? intro() : chosenLine()) }
        warm()
        if UserDefaults.standard.bool(forKey: "voicetest") { Task { await voiceTest() } }
        if UserDefaults.standard.bool(forKey: "scantest") { Task { await scanTest() } }
        if let id = UserDefaults.standard.string(forKey: "breakpicture"), let c = mine.first(where: { $0.id == id }) {
            for file in c.img.values { try? FileManager.default.removeItem(at: Store.docs.appendingPathComponent("Cards/" + file)) }
            note("breakpicture: removed \(id)'s pictures") // the cloud Mac: as if their download had failed
        }
        Task { await repairPictures() }
        Task { await reread() }
        if UserDefaults.standard.bool(forKey: "prerender") { Task { await prerender() } }
    }

    /// Kokoro makes ahead of time the sentences every game says (when the app opens, the language changes or the voice
    /// comes back on; and on the cloud Mac, `prerender`). Each Pokémon's own are made when it's added or chosen.
    func warm() {
        let l = lang, z = "ZZ" // a stand-in name: sentences with a Pokémon's name in them are left for warm(card)
        var lines = [Say.start(l, 1, 1), Say.start(l, 2, 3), Say.start(l, 3, 3), Say.ready(l), Say.flip(l), Say.firstTurnRule(l),
                     Say.canAttack(l), Say.notEnough(l), Say.oneEnergy(l), Say.energyFirst(l), Say.heads(l), Say.tails(l),
                     Say.nothing(l), Say.coinTeach(l), Say.again(l), Say.language(l), Say.voiceOn(l), Say.chosen(l, z, z),
                     Say.chosenTeam(l), Say.setUpTeam(l), Say.oneRetreat(l), Say.noBench(l),
                     Say.notEnoughTeach(l, z, 1), Say.canAttackTeach(l, z), Say.leftTeach(l, z, 60, 20, 40)]
        lines += ["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting", "Darkness", "Metal", "Colorless"].map { Say.turn(l, z, $0) }
        lines += stride(from: 10, through: 200, by: 10).map { Say.damage(l, $0) }
        voice.prepare(lines.flatMap(Kokoro.sentences).filter { !$0.contains(z) }, .later)
    }

    func warm(_ c: Card, _ when: Kokoro.When = .soon) {
        let l = lang, n = c.name(l)
        var lines = [Say.starts(l, n), Say.allEnergy(l, n), Say.ko(l, n), Say.wins(l, n), Say.wait(l, n)]
        if level > 1 { lines += [Say.koTeam(l, n), Say.koLast(l, n), Say.comesIn(l, n), Say.teamWins(l, n), Say.whoNext(l, n)] }
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

    /// -scantest (the cloud Mac, which has no camera): what the camera reads from five cards, one after the other, each
    /// added like a parent tapping it: a frame every 50 ms, each line read a little differently, one digit misread.
    /// Each must be looked up once (build 20 flickered looking it up again and again) and added (build 33 stalled after
    /// four on Jordan's iPad); ios/ci/sim-shots.sh fails otherwise.
    func scanTest() async {
        let adder = Adder(game: self)
        let codes = ["001/072", "038/198", "025/165", "034/193", "036/198"], sets = ["SHF", "SVI", "MEW", "PAL", "SVI"]
        let misread = ["007/072", "039/198", "026/165", "035/193", "037/198"]
        var added = 0
        for (k, n) in codes.enumerated() {
            let frames = [["\(sets[k]) EN \(n)"], ["0 \(n) ●"], ["\(sets[k]) \(n)", "Rowlet"], ["\(sets[k]) EN \(misread[k])"], [n]]
            for i in 0..<(k == 0 ? 30 : 10) {
                adder.scan(frames[i % frames.count])
                await pause(0.05)
            }
            for _ in 0..<150 where adder.found.isEmpty { await pause(0.1) } // the lookup, 15 seconds at most
            if let b = adder.found.first {
                await adder.add(b)
                added += 1
            }
            note("scantest: card \(k + 1) \(n): \(adder.lookups) lookups so far, \(adder.cameraInfo)")
        }
        note("scantest: \(adder.lookups) lookups, \(added) added")
    }

    /// Card pictures that didn't download when the card was added: tried again each time the app opens.
    func repairPictures() async {
        let broken = mine.filter { !Art.missing($0).isEmpty }
        guard !broken.isEmpty else { return }
        var fixed = 0
        for c in broken where await TCGdex.repair(c) { fixed += 1 }
        note("pictures: \(broken.count) cards missing one, \(fixed) repaired\(fixed == broken.count ? ", all" : "")")
        if fixed > 0 { pictures += 1 }
    }

    /// Cards added before the app could play any of their attacks (Golbat's damage is written in its text): read again
    /// each time the app opens, in case it can now.
    func reread() async {
        let old = mine.filter { !$0.playable }
        guard !old.isEmpty else { return }
        var now = 0
        for c in old {
            guard case .ok(let n) = await TCGdex.fetch(c.id), n.playable, let i = mine.firstIndex(where: { $0.id == c.id }) else { continue }
            mine[i] = n
            now += 1
        }
        note("reread: \(old.count) cards that couldn't battle, \(now) can now")
        if now > 0 { Store.save(mine) }
    }

    func setLang(_ l: Lang) {
        lang = l
        voice.lang = l
        UserDefaults.standard.set(l.rawValue, forKey: "lang")
        speak(Say.language(l) + (step == .pick && sides[0].card == nil ? " " + intro() : ""))
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
        withAnimation(.easeOut(duration: 0.2)) { captions = Array((captions + [Caption(id: captionID, text: text)]).suffix(120)) }
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
        if step == .pick { sides = [Side(), Side()]; speak(intro()) } // the cards may have changed
    }

    // MARK: Choosing

    func setLevel(_ n: Int) {
        guard step == .pick else { return }
        Sound.play("pop")
        guard n <= Say.built else { levelNote = Say.levelSoon(lang); return }
        levelNote = nil
        level = n
        UserDefaults.standard.set(n, forKey: "level")
        sides = [Side(), Side()]
    }

    /// The Energy cards to put next to a Pokémon before the battle: exactly what its strongest attack needs (its own
    /// type for a Colorless cost), and from level 3 enough to pay its retreat. Build 29 showed four for every Pokémon,
    /// which looked like a rule (Jordan: "why are there four energy cards here").
    func energyFor(_ c: Card) -> [String] {
        let cost = (strongest(c)?.cost ?? []).map { $0 == "Colorless" ? c.type : $0 }
        var e = cost.isEmpty ? [c.type] : cost
        if level >= 3 { e += Array(repeating: c.type, count: max(0, c.retreat - e.count)) }
        return e
    }

    func strongest(_ c: Card) -> Attack? { c.moves.max { $0.cost.count < $1.cost.count } }

    /// Enough Energy for its strongest attack (and from level 3, to retreat): no more ENERGY step, straight to attacking.
    func hasAll(_ s: Int) -> Bool {
        guard let c = sides[s].card else { return true }
        let attack = strongest(c).map { canPay($0.cost, sides[s].energy) } ?? true
        return attack && (level < 3 || sides[s].energy.count >= c.retreat)
    }

    /// The Poké Ball at the start: the app chooses the Pokémon (Jordan, 17 Oct 2026: "we have no idea what cards to
    /// choose"). One each in level 1, a team each from level 2. Each of the second player's has about the same HP as the
    /// one it faces in the same place, so it's a fair fight; all different Pokémon when there are enough.
    func choose() {
        guard step == .pick, !busy, canStart else { return }
        var pool = cards.shuffled(), a: [Card] = [], b: [Card] = []
        func take(near o: Card?) -> Card? {
            let used = Set((a + b).map(\.name.en))
            var options = pool.filter { !used.contains($0.name.en) }
            if options.isEmpty { options = pool }
            var pick = options.first
            if let o {
                let close = options.filter { abs($0.hp - o.hp) <= 20 }
                pick = (close.isEmpty ? Array(options.sorted { abs($0.hp - o.hp) < abs($1.hp - o.hp) }.prefix(3)) : close).randomElement()
            }
            pool.removeAll { $0.id == pick?.id }
            return pick
        }
        for _ in 0..<size {
            if let c = take(near: nil) { a.append(c) }
            if let c = take(near: a.last) { b.append(c) }
        }
        sides = Bool.random() ? [Side(a), Side(b)] : [Side(b), Side(a)]
        Sound.play("pop")
        for side in sides { for m in side.team { warm(m.card) } }
        note("chose " + [0, 1].map { s in sides[s].team.map { "\($0.card.name(lang)) \($0.card.hp) HP" }.joined(separator: ", ") }.joined(separator: " against "))
        speak(chosenLine())
    }

    /// The Poké Ball in the middle: choose the Pokémon, start, say it again, or play again.
    func ball() {
        switch step {
        case .pick:
            if sides.allSatisfy({ $0.card != nil }) { Task { await go() } }
            else if !canStart { // the reason, shaken on the parent's half
                Sound.play("pop")
                withAnimation(.linear(duration: 0.5)) { nudge += 1 }
                speak(intro())
            }
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
            speak(intro())
            return
        }
        guard step == .battle, !busy else { return }
        again()
    }

    func again() {
        winner = nil
        choosing = nil
        waiting = []
        zoom = [false, false]
        sides = [Side(), Side()]
        step = .pick
        Sound.play("pop")
        speak(Say.again(lang))
    }

    func go() async {
        guard step == .pick, !busy, sides.allSatisfy({ $0.card != nil }) else { return }
        busy = true
        sides = sides.map { Side($0.team.map(\.card)) }
        turns = 0
        winner = nil
        captions = [] // a fresh list of lines for each game
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
        sides[s].attached = false
        sides[s].retreated = false
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
        // level 3: the moment retreating matters, once
        if level >= 3, let foe = sides[1 - s].card, sides[s].card?.weak == foe.type, !sides[s].bench.isEmpty,
           told.insert("retreatTip").inserted {
            await say(Say.retreatTip(lang, name(s), Kind.name(foe.type, lang)))
        }
    }

    func giveEnergy(_ s: Int) async {
        guard step == .battle, !busy, choosing == nil else { return }
        guard s == turn else { await say(Say.wait(lang, name(turn))); return }
        guard !sides[s].gaveEnergy else { await say(hasAll(s) ? Say.allEnergy(lang, name(s)) : Say.oneEnergy(lang)); return }
        let t = nextEnergy(s)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            sides[s].energy.append(t)
            sides[s].gaveEnergy = true
            sides[s].attached = true
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
        guard step == .battle, !busy, choosing == nil else { return }
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
        guard step == .battle, !busy, choosing == nil, let me = sides[s].card, i < me.moves.count, let foe = sides[1 - s].card else { return }
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
        case "hit", "counters": dmg = a.power // the damage written in its text, on the fighting Pokémon
        default: break
        }
        var weak = false, resisted = false, shielded = false, toughened = false
        if dmg > 0 && kind != "noWeakness" && kind != "counters" { // damage counters aren't affected by Weakness
            if foe.weak == me.type { dmg *= 2; weak = true }
            if foe.resist == me.type { dmg = max(0, dmg - (foe.resistBy ?? 30)); resisted = true }
        }
        let before = dmg // after Weakness and Resistance, before the defender's own protection
        if dmg > 0 && sides[f].shield { dmg = 0; shielded = true }
        if dmg > 0 && sides[f].reduce > 0 && kind != "counters" { dmg = max(0, dmg - sides[f].reduce); toughened = true }

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

        let downs = [f, s].filter { sides[$0].hp == 0 } // s: it hurt itself too much
        if !downs.isEmpty { await knockedOut(downs, by: s); return }
        if dmg > 0 {
            if told.insert("count").inserted { await say(Say.leftTeach(lang, name(f), foe.hp, sides[f].damage, sides[f].hp)) }
            else { await say(Say.left(lang, name(f), sides[f].hp)) }
        }
        busy = false
        await endTurn()
    }

    /// After an attack: each side whose Pokémon was knocked out brings in the next from its bench, or, with none left,
    /// loses. When both run out at once, the attacker wins (as in level 1).
    private func knockedOut(_ downs: [Int], by s: Int) async {
        for k in downs {
            Sound.play("ko")
            note("KO: \(name(k)), \(sides[k].left) left on that side")
            await say(level == 1 ? Say.ko(lang, name(k)) : sides[k].left > 0 ? Say.koTeam(lang, name(k)) : Say.koLast(lang, name(k)))
        }
        if let k = [1 - s, s].first(where: { sides[$0].left == 0 }) { await win(1 - k); return }
        waiting = downs
        busy = false
        await nextIn()
    }

    private func win(_ w: Int) async {
        winner = w
        note("win: \(name(w)) after \(turns + 1) turns")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { step = .over }
        busy = false
        Sound.play("win")
        await pause(0.6)
        await say(level == 1 ? Say.wins(lang, name(w)) : Say.teamWins(lang, name(w)))
        note("log: \(captions.count) lines kept at the end") // the cloud Mac checks the end screen keeps them
    }

    // MARK: The bench (from level 2)

    /// The next side that has lost its fighting Pokémon brings one in: by itself when only one is left on the bench,
    /// else that player taps one on their half. Then the turn passes.
    private func nextIn() async {
        guard let k = waiting.first else { await endTurn(); return }
        let bench = sides[k].bench
        if bench.count == 1 {
            waiting.removeFirst()
            await comeIn(k, bench[0])
            await nextIn()
            return
        }
        why = .ko
        choosing = k
        await say(Say.whoNext(lang, name(k)))
    }

    /// Tapping a Pokémon on the bench, when that side is choosing who comes in.
    func pick(_ k: Int, _ i: Int) async {
        guard choosing == k, !busy, sides[k].bench.contains(i) else { return }
        choosing = nil
        switch why {
        case .ko:
            waiting.removeAll { $0 == k }
            await comeIn(k, i)
            await nextIn()
        case .retreat:
            await retreatTo(k, i)
        }
    }

    /// Tapping away from the bench: a retreat not wanted after all (after a knockout someone has to come in).
    func cancelPick() {
        guard why == .retreat, choosing != nil else { return }
        choosing = nil
    }

    private func comeIn(_ k: Int, _ i: Int) async {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            sides[k].active = i
            sides[k].locked = false
            sides[k].lockNext = false
        }
        Sound.play("pop")
        note("in: \(name(k)) \(sides[k].hp) HP")
        await say(Say.comesIn(lang, name(k)))
    }

    func canRetreat(_ s: Int) -> Bool {
        level >= 3 && !sides[s].retreated && !sides[s].bench.isEmpty && sides[s].energy.count >= (sides[s].card?.retreat ?? 0)
    }

    /// RETREAT (level 3): the fighting Pokémon goes back to the bench and another comes in. It costs as many Energy
    /// cards as the circles next to "retreat" at the bottom of its card. Once a turn; its damage stays with it.
    func retreat(_ s: Int) async {
        guard level >= 3, step == .battle, !busy, choosing == nil else { return }
        guard s == turn else { await say(Say.wait(lang, name(turn))); return }
        guard !sides[s].retreated else { await say(Say.oneRetreat(lang)); return }
        let bench = sides[s].bench
        guard !bench.isEmpty else { await say(Say.noBench(lang)); return }
        let cost = sides[s].card?.retreat ?? 0
        if told.insert("retreat").inserted { await say(Say.retreatTeach(lang, name(s), cost)) }
        guard sides[s].energy.count >= cost else { await say(Say.retreatCost(lang, name(s), cost, sides[s].energy.count)); return }
        if bench.count == 1 { await retreatTo(s, bench[0]); return }
        why = .retreat
        choosing = s
        await say(Say.whoIn(lang, name(s)))
    }

    private func retreatTo(_ s: Int, _ i: Int) async {
        let out = name(s), was = sides[s].active, cost = sides[s].card?.retreat ?? 0
        let paid = Array(sides[s].energy.suffix(cost))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            sides[s].energy.removeLast(min(cost, sides[s].energy.count))
            sides[s].active = i
            sides[s].locked = false // what an attack did to it ends when it leaves
            sides[s].lockNext = false
            sides[s].retreated = true
        }
        sides[s].gaveEnergy = sides[s].attached || hasAll(s) // the one that came in may need Energy
        Sound.play("whoosh")
        note("retreat: \(out) for \(name(s)), \(cost) Energy")
        await say(Say.retreated(lang, out, name(s), paid, kept: sides[s].team[was].energy.count))
        if !sides[s].gaveEnergy { await say(Say.putOn(lang, name(s), nextEnergy(s))) }
        else if turns == 0 { await say(Say.firstTurnRule(lang)) }
        else if usable(s).isEmpty { await say(Say.notEnough(lang)) }
        else { await say(Say.canAttack(lang)) }
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
    /// From level 2 a knocked-out Pokémon's place goes to the first on the bench; in level 3 each side retreats once
    /// early on (so the cloud Mac's games show it) and when its Pokémon is down to half its HP.
    func autoplay() async {
        guard canStart else { return }
        await pause(1)
        choose()
        await pause(0.5)
        await go()
        var moves = 0, retreats = [0, 0]
        while step == .battle && moves < 300 {
            moves += 1
            await pause(fast ? 0.3 : 1.2)
            if let k = choosing, let i = sides[k].bench.first { await pick(k, i); continue }
            let s = turn
            await giveEnergy(s)
            await pause(fast ? 0.2 : 0.4)
            if canRetreat(s), retreats[s] == 0 || (sides[s].hp * 2 < (sides[s].card?.hp ?? 0) && retreats[s] < 3) {
                retreats[s] += 1
                await retreat(s)
                if choosing == s, let i = sides[s].bench.first { await pick(s, i) }
            }
            if turns > 0, !sides[s].locked, let i = usable(s).last { await attack(s, i) } else { await done(s) }
        }
        note("auto: finished, winner \(winner.map { name($0) } ?? "none") after \(moves) moves")
    }
}
