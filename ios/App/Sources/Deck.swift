import SwiftUI

// Building a deck of 60 for the real game, a mode of its own beside the practice levels (Jordan, 1 Nov 2026, after the
// Prima Lotta box had taught his son a hand and Trainers: "teaching him how to assemble a deck. and teaching me as
// well"; "Just separate modes"). Five steps on the board: a type, the Pokémon (in whole families), the Trainers, the
// Energy that fills it up to 60, and a check against the real rules. The parent's half says each step and why; the
// child's half shows his job (the type symbols to choose from, the families with a gap where one is missing, the
// counts). Pokémon and Trainers go in with the camera (AddView for a deck); Energy cards are only counted. Kept on
// the iPad (Documents/decks.json): his deck and the parent's.

/// The start screen's modes: the practice levels, or building the decks (the real game will be a third).
enum Mode: String { case practice, decks }

/// So many copies of one card in a deck.
struct InDeck<T: Codable>: Codable {
    var card: T
    var n: Int
}

/// A Pokémon that isn't in the deck but one of its evolutions is: what it evolves from, and its Pokédex number for the
/// sprite in the gap on the child's half (from TCGdex, `TCGdex.lineage`).
struct Lineage: Codable {
    let from: String?
    let dex: Int?
}

/// A line of Pokémon on the child's half: Charmander → Charmeleon → Charizard ex, with a gap where one is missing.
struct Family: Identifiable {
    enum Slot {
        case have(Card, Int)
        case gap(String, Int?) // its name, and its Pokédex number when known
    }
    let id: String
    let slots: [Slot]
}

/// The Energy cards to put in, of one type.
struct EnergyNeed: Identifiable {
    let type: String
    var n: Int
    var id: String { type }
}

/// Something to sort out, written in yellow on the parent's half.
enum Tip: Equatable {
    case gap(String, String) // this Pokémon evolves from one that isn't in the deck
    case noBasic
    case fewBasics(Int)
    case noDraw
    case fewEnergy(Int)
    case manyEnergy(Int)
    case tooMany(Int) // Pokémon and Trainers already past 60
}

struct Deck: Codable {
    /// The types to choose from: those with a basic Energy card.
    static let types = ["Grass", "Fire", "Water", "Lightning", "Psychic", "Fighting", "Darkness", "Metal"]
    static let size = 60
    static let steps = 5 // 1 type, 2 Pokémon, 3 Trainers, 4 Energy, 5 the check

    var type: String?
    var pokemon: [InDeck<Card>] = []
    var trainers: [InDeck<Trainer>] = []
    var links: [String: Lineage] = [:]
    var step = 1
    var finished = false // the five steps gone through once

    init() {}

    /// Each field when it's there: a deck saved by an older build still opens (a missing field must never lose one).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        pokemon = try c.decodeIfPresent([InDeck<Card>].self, forKey: .pokemon) ?? []
        trainers = try c.decodeIfPresent([InDeck<Trainer>].self, forKey: .trainers) ?? []
        links = try c.decodeIfPresent([String: Lineage].self, forKey: .links) ?? [:]
        step = try c.decodeIfPresent(Int.self, forKey: .step) ?? 1
        finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
    }

    var pokemonCount: Int { pokemon.reduce(0) { $0 + $1.n } }
    var trainerCount: Int { trainers.reduce(0) { $0 + $1.n } }
    /// Energy fills the deck up to 60.
    var energyCount: Int { max(0, Deck.size - pokemonCount - trainerCount) }
    var total: Int { pokemonCount + trainerCount + energyCount }
    var started: Bool { type != nil || pokemonCount + trainerCount > 0 }
    var basics: Int { pokemon.filter { $0.card.isBasic }.reduce(0) { $0 + $1.n } }

    /// Copies of cards with this name (two prints of Charmander count together, as in the rules).
    func copies(_ name: String) -> Int {
        pokemon.filter { $0.card.name.en == name }.reduce(0) { $0 + $1.n } + trainers.filter { $0.card.name.en == name }.reduce(0) { $0 + $1.n }
    }
    func has(_ id: String) -> Bool { pokemon.contains { $0.card.id == id } || trainers.contains { $0.card.id == id } }
    func named(_ name: String) -> Card? { pokemon.first { $0.card.name.en == name }?.card }
    var aces: Int { trainers.filter { $0.card.ace }.reduce(0) { $0 + $1.n } }
    var radiants: Int { pokemon.filter { $0.card.name.en.hasPrefix("Radiant ") }.reduce(0) { $0 + $1.n } }

    // The real rules: exactly 60 cards, no more than 4 with the same name (basic Energy apart), at least one Basic
    // Pokémon, one ACE SPEC and one Radiant Pokémon at most.
    var fits: Bool { pokemonCount + trainerCount <= Deck.size }
    var fourOK: Bool { (pokemon.map(\.card.name.en) + trainers.map(\.card.name.en)).allSatisfy { copies($0) <= 4 } }
    var meetsRules: Bool { pokemonCount > 0 && fits && basics > 0 && fourOK && aces <= 1 && radiants <= 1 }
    var ready: Bool { finished && meetsRules }

    /// The Energy that fills the deck up to 60, by type: shared between the types its attacks need, by how many of their
    /// circles are of each type (a Colorless circle takes any Energy), the deck's own type first.
    func energyCards() -> [EnergyNeed] {
        let n = energyCount
        guard n > 0 else { return [] }
        var weight: [String: Int] = [:]
        for e in pokemon { for t in e.card.attacks.flatMap(\.cost) where t != "Colorless" { weight[t, default: 0] += e.n } }
        let own = type ?? weight.max { $0.value < $1.value }?.key ?? "Colorless"
        if weight.isEmpty { weight[own] = 1 }
        let sum = weight.values.reduce(0, +)
        var out = weight.map { EnergyNeed(type: $0.key, n: n * $0.value / sum) }.sorted { a, b in
            if a.type == own { return b.type != own }
            if b.type == own { return false }
            return a.n != b.n ? a.n > b.n : a.type < b.type
        }
        out[0].n += n - out.reduce(0) { $0 + $1.n } // what the rounding left goes to the first
        return out.filter { $0.n > 0 }
    }

    /// The deck's Pokémon in families, each from the first stage to the last, with a gap for one that's missing.
    func families() -> [Family] {
        var byName: [String: (card: Card, n: Int)] = [:], order: [String] = []
        for e in pokemon {
            let k = e.card.name.en
            if let had = byName[k] { byName[k] = (had.card, had.n + e.n) } else { byName[k] = (e.card, e.n); order.append(k) }
        }
        func from(_ name: String) -> String? { byName[name]?.card.from ?? links[name]?.from }
        var lines: [String: [String]] = [:], roots: [String] = []
        for k in order {
            var chain = [k], seen: Set<String> = [k], up = from(k)
            while let f = up, seen.insert(f).inserted {
                chain.insert(f, at: 0)
                up = from(f)
            }
            let root = chain[0]
            if lines[root] == nil { roots.append(root); lines[root] = [] }
            for name in chain where !(lines[root] ?? []).contains(name) { lines[root, default: []].append(name) }
        }
        return roots.map { r in
            Family(id: r, slots: (lines[r] ?? []).map { name -> Family.Slot in
                if let have = byName[name] { return .have(have.card, have.n) }
                return .gap(name, links[name]?.dex)
            })
        }
    }

    /// For the cloud Mac's log: "Fuecoco×4>Crocalor×3 | Charmander×4>Charmeleon?>Charizard ex×2".
    var familyLine: String {
        families().map { f in
            f.slots.map { s -> String in
                switch s {
                case .have(let c, let n): return "\(c.name.en)×\(n)"
                case .gap(let name, _): return name + "?"
                }
            }.joined(separator: ">")
        }.joined(separator: " | ")
    }

    /// What to sort out at this step, most important first.
    func tips(_ step: Int) -> [Tip] {
        var out: [Tip] = []
        if step == 2 || step == 5 {
            for e in pokemon {
                if let f = e.card.from, named(f) == nil, !out.contains(.gap(e.card.name.en, f)) { out.append(.gap(e.card.name.en, f)) }
            }
            if pokemonCount > 0 && basics == 0 { out.append(.noBasic) } else if pokemonCount >= 12 && basics < 8 { out.append(.fewBasics(basics)) }
        }
        let helpers = trainers.filter { ["draw", "search"].contains($0.card.does ?? "") }.count
        if helpers == 0 && ((step == 3 && trainerCount >= 8) || step == 5) { out.append(.noDraw) }
        if step >= 3 && !fits { out.append(.tooMany(pokemonCount + trainerCount)) }
        else if step >= 4 && energyCount < 10 { out.append(.fewEnergy(energyCount)) }
        else if step >= 4 && energyCount > 26 { out.append(.manyEnergy(energyCount)) }
        return out
    }
}

/// His deck and the parent's, kept on the iPad.
enum Decks {
    private static var file: URL { Store.docs.appendingPathComponent("decks.json") }

    static func load() -> [Deck] {
        guard let data = try? Data(contentsOf: file) else { return [Deck(), Deck()] }
        do {
            let d = try JSONDecoder().decode([Deck].self, from: data)
            return d.count == 2 ? d : [Deck(), Deck()]
        } catch { // kept aside, so the next save can't wipe decks a newer build could still read
            note("decks.json unreadable, kept as decks-unreadable.json: \(error)")
            try? data.write(to: Store.docs.appendingPathComponent("decks-unreadable.json"))
            return [Deck(), Deck()]
        }
    }

    static func save(_ d: [Deck]) { try? JSONEncoder().encode(d).write(to: file, options: .atomic) }
}

extension Game {
    var deck: Deck { decks[building] }
    /// The deck the Poké Ball opens in decks mode: his first, until it's ready.
    var nextToBuild: Int { [childSide, parentSide].first { !decks[$0].ready } ?? childSide }

    func saveDecks() { Decks.save(decks) }

    func setMode(_ m: Mode) {
        guard step == .pick, !busy else { return }
        Sound.play("pop")
        mode = m
        UserDefaults.standard.set(m.rawValue, forKey: "mode")
        levelNote = nil
        sides = [Side(), Side()]
    }

    func openDeck(_ s: Int) {
        guard step == .pick, !busy else { return }
        voice.stop()
        building = s
        step = .deck
        Sound.play("pop")
        note("deck: \(s == childSide ? "his" : "yours"), step \(deck.step), \(deck.pokemonCount) Pokémon, \(deck.trainerCount) Trainers")
    }

    func chooseType(_ t: String) {
        guard step == .deck else { return }
        decks[building].type = t
        saveDecks()
        Sound.play("energy")
    }

    /// NEXT (or the Poké Ball): the next step; at the check, DONE.
    func deckForward() {
        guard step == .deck else { return }
        if deck.step == 1 && deck.type == nil { // a type first: the line saying so shakes
            Sound.play("pop")
            withAnimation(.linear(duration: 0.5)) { nudge += 1 }
            return
        }
        guard deck.step < Deck.steps else { finishDeck(); return }
        decks[building].step += 1
        saveDecks()
        Sound.play("turn")
        note("deck: step \(deck.step), \(deck.pokemonCount) Pokémon, \(deck.trainerCount) Trainers, \(deck.energyCount) Energy")
    }

    func deckBack() {
        guard step == .deck else { return }
        guard deck.step > 1 else { leaveDeck(); return }
        decks[building].step -= 1
        saveDecks()
        Sound.play("pop")
    }

    /// Holding the Poké Ball, or BACK from the first step: back to the start, the deck kept as it is.
    func leaveDeck() {
        guard step == .deck else { return }
        saveDecks()
        step = .pick
        Sound.play("pop")
    }

    func finishDeck() {
        decks[building].finished = true
        saveDecks()
        note("deck: done, \(deck.total) cards, rules \(deck.meetsRules ? "met" : "not met")")
        step = .pick
        Sound.play(deck.ready ? "win" : "pop")
    }

    /// START AGAIN on the first step (after asking): an empty deck.
    func clearDeck() {
        decks[building] = Deck()
        saveDecks()
        Sound.play("pop")
    }

    /// A Pokémon into a deck (the camera, or + on the add screen), unless the rules stop it; what to tell the parent.
    func deckAdd(_ c: Card, to s: Int) -> String {
        let l = lang, n = c.name(l)
        if decks[s].copies(c.name.en) >= 4 { return Say.fourMax(l, n) }
        if c.name.en.hasPrefix("Radiant "), decks[s].radiants >= 1 { return Say.oneRadiant(l) }
        if let i = decks[s].pokemon.firstIndex(where: { $0.card.id == c.id }) { decks[s].pokemon[i].n += 1 }
        else { decks[s].pokemon.append(InDeck(card: c, n: 1)) }
        saveDecks()
        var line = Say.inDeck(l, n)
        if decks[s].copies(c.name.en) == 1 { // the first copy: what kind of Pokémon it is
            if let f = c.from {
                let has = decks[s].named(f) != nil
                line += " " + (told.insert("evolves").inserted ? Say.evolvesTeach(l, f, has) : Say.evolves(l, f, has))
                if !has { Task { await learn(f, s) } }
            } else if told.insert("basic").inserted {
                line += " " + Say.basicTeach(l)
            }
            if let t = decks[s].type, c.type != t, c.type != "Colorless" { line += " " + Say.offType(l, c.type) }
        }
        note("deck add: \(c.id) \(c.name.en) ×\(decks[s].copies(c.name.en))")
        return line + " " + Say.soFar(l, decks[s].pokemonCount, decks[s].trainerCount)
    }

    /// A Trainer into a deck: what its kind means (once each), and what it does.
    func deckAdd(_ t: Trainer, to s: Int) -> String {
        let l = lang, n = t.name(l)
        if decks[s].copies(t.name.en) >= 4 { return Say.fourMax(l, n) }
        if t.ace, decks[s].aces >= 1 { return Say.oneAce(l) }
        if let i = decks[s].trainers.firstIndex(where: { $0.card.id == t.id }) { decks[s].trainers[i].n += 1 }
        else { decks[s].trainers.append(InDeck(card: t, n: 1)) }
        saveDecks()
        var line = Say.inDeck(l, n)
        if decks[s].copies(t.name.en) == 1 {
            line += " " + Say.kind(l, t.kind, teach: told.insert("kind-" + t.kind).inserted)
            if let d = t.does { line += " " + Say.does(l, d) }
            if t.ace { line += " " + Say.aceNote(l) }
        }
        note("deck add: \(t.id) \(t.name.en) (\(t.kind), \(t.does ?? "-")) ×\(decks[s].copies(t.name.en))")
        return line + " " + Say.soFar(l, decks[s].pokemonCount, decks[s].trainerCount)
    }

    /// − and + under a card on the add screen. A message only when there's something to say.
    func deckChange(_ id: String, by k: Int, in s: Int) -> String? {
        if k > 0 {
            if let c = decks[s].pokemon.first(where: { $0.card.id == id })?.card { return deckAdd(c, to: s) }
            if let t = decks[s].trainers.first(where: { $0.card.id == id })?.card { return deckAdd(t, to: s) }
            return nil
        }
        if let i = decks[s].pokemon.firstIndex(where: { $0.card.id == id }) {
            decks[s].pokemon[i].n -= 1
            if decks[s].pokemon[i].n <= 0 { decks[s].pokemon.remove(at: i) }
        } else if let i = decks[s].trainers.firstIndex(where: { $0.card.id == id }) {
            decks[s].trainers[i].n -= 1
            if decks[s].trainers[i].n <= 0 { decks[s].trainers.remove(at: i) }
        }
        saveDecks()
        Sound.play("pop")
        return Say.soFar(lang, decks[s].pokemonCount, decks[s].trainerCount)
    }

    /// A Pokémon one of the deck's evolves from, not in the deck: what it looks like (its sprite, in the gap on his half)
    /// and what it evolves from in turn, so the family shows whole.
    func learn(_ name: String, _ s: Int, depth: Int = 0) async {
        guard depth < 3, decks[s].links[name] == nil, decks[s].named(name) == nil, learning.insert(name).inserted else { return }
        defer { learning.remove(name) }
        guard let link = await TCGdex.lineage(name) else { note("deck: couldn't look up \(name)"); return }
        decks[s].links[name] = link
        saveDecks()
        note("deck: learned \(name) from \(link.from ?? "nothing"), dex \(link.dex.map(String.init) ?? "?")")
        if let dex = link.dex {
            await TCGdex.sprite(dex)
            pictures += 1
        }
        if let f = link.from { await learn(f, s, depth: depth + 1) }
    }

    /// Adds a card to a deck so many times, as the add screen would (the cloud Mac: -deckadd, -decktest).
    @discardableResult
    func deckPut(_ id: String, _ k: Int, _ s: Int) async -> String {
        let got = await TCGdex.fetchAny(id)
        var line = ""
        for _ in 0..<max(1, k) {
            switch got {
            case .pokemon(let c): line = deckAdd(c, to: s)
            case .trainer(let t): line = deckAdd(t, to: s)
            case .energy(let n): line = "energy card: " + Say.energyScanned(lang, n)
            case .offline: line = "offline"
            }
        }
        switch got {
        case .pokemon(let c): _ = await TCGdex.finish(c)
        case .trainer(let t): _ = await TCGdex.repair(id: t.id, img: t.img)
        default: break
        }
        pictures += 1
        note("deck put \(id) ×\(k): \(line)")
        return line
    }

    /// -decktest (the cloud Mac): his deck built from real cards, as on the add screen. Charizard ex goes in before
    /// Charmeleon (a gap, looked up so the family shows whole), a fifth Charmander and an Energy card are refused, and
    /// the deck must come out at 60 with every rule met and nothing to sort out. ios/ci/sim-shots.sh checks the log.
    func deckTest() async {
        mode = .decks
        building = childSide
        decks[childSide] = Deck()
        step = .deck
        chooseType("Fire")
        decks[childSide].step = 2
        for (id, k) in [("sv01-036", 4), ("sv01-037", 3), ("sv01-038", 2), ("sv03.5-004", 4), ("sv03.5-006", 2)] { await deckPut(id, k, childSide) }
        for _ in 0..<60 where deck.links["Charmeleon"] == nil || !learning.isEmpty { await pause(0.25) }
        let gap = deck.familyLine
        await deckPut("sv03.5-005", 3, childSide)
        let fifth = await deckPut("sv03.5-004", 1, childSide)
        let energy = await deckPut("sve-002", 1, childSide)
        decks[childSide].step = 3
        for (id, k) in [("sv01-189", 4), ("sv01-196", 4), ("sv01-181", 4), ("sv01-194", 2), ("sv01-188", 2), ("sv02-172", 2), ("sv02-185", 2)] {
            await deckPut(id, k, childSide)
        }
        decks[childSide].step = 5
        let d = deck
        let refused = d.copies("Charmander") == 4 && fifth == Say.fourMax(lang, "Charmander")
        let skipped = energy.hasPrefix("energy card") && d.total == 60
        let energyLine = d.energyCards().map { "\($0.type) \($0.n)" }.joined(separator: ", ")
        let tips = d.tips(5).isEmpty ? "none" : "\(d.tips(5))"
        let parts: [String] = [
            "\(d.pokemonCount) Pokémon, \(d.trainerCount) Trainers, Energy \(energyLine)",
            "with the gap: \(gap)",
            "families: \(d.familyLine)",
            "fifth Charmander refused \(refused ? "yes" : "no")",
            "energy card not added \(skipped ? "yes" : "no")",
            "tips \(tips)",
            "ready \(d.meetsRules && d.total == 60 ? "yes" : "no")",
        ]
        note("decktest: " + parts.joined(separator: "; "))
        finishDeck()
    }
}
