import SwiftUI
import UIKit
import AVFoundation
import VisionKit

// Adding his cards on the iPad. The camera reads the set code and number printed at the bottom left of a card
// ("SVI 038/198"), or a parent types the name; TCGdex has the card in Italian and English. The card's pictures and
// sprite are saved on the iPad (Documents), with the list of his cards (Documents/collection.json).

/// What an attack's English text does in the game: the same rules as tools/cards.py, from Data/effects.json.
enum Effects {
    private struct Rule: Decodable {
        let re: String
        let kind: String
        let n: String?
        let each: String?
    }

    private static let rules: [(NSRegularExpression, Rule)] = {
        guard let url = Bundle.main.url(forResource: "effects", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Rule].self, from: data) else { return [] }
        return list.compactMap { r in (try? NSRegularExpression(pattern: "^(?:" + r.re + ")$")).map { ($0, r) } }
    }()

    static func read(_ text: String?) -> Effect? {
        let text = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        for (rx, r) in rules {
            guard let m = rx.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { continue }
            func value(_ v: String?) -> Int? {
                guard let v else { return nil }
                var s = v
                if v.hasPrefix("$"), let k = Int(v.dropFirst()), k < m.numberOfRanges, m.range(at: k).location != NSNotFound {
                    s = ns.substring(with: m.range(at: k))
                }
                return ["a": 1, "an": 1, "all": 99][s] ?? Int(s)
            }
            return Effect(kind: r.kind, n: value(r.n), each: value(r.each))
        }
        return Effect(kind: "skip", n: nil, each: nil)
    }
}

/// The codes printed on cards (SVI, MEW, MEG…) → TCGdex set ids (Data/sets.json, from tools/cards.py sets).
enum Sets {
    static let ids: [String: String] = {
        guard let url = Bundle.main.url(forResource: "sets", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }()

    /// The set code among what the camera read. The language is printed beside it ("SVI IT"), so it's often read as
    /// one word ("SVIIT"); a 1 can be read for an I.
    static func code(in texts: [String]) -> String? {
        let words = texts.flatMap { $0.uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted) }.filter { $0.count >= 2 }
        for w in words {
            for c in [w, String(w.dropLast(2)), w.replacingOccurrences(of: "1", with: "I"), String(w.replacingOccurrences(of: "1", with: "I").dropLast(2))]
            where c.count >= 2 && ids[c] != nil { return c }
        }
        return nil
    }

    /// The card's number: "038" in "038/198".
    static func number(in text: String) -> String? {
        guard let rx = try? NSRegularExpression(pattern: "(\\d{1,3})\\s*/\\s*(\\d{2,3})"),
              let m = rx.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) else { return nil }
        return (text as NSString).substring(with: m.range(at: 1))
    }
}

enum TCGdex {
    struct Brief: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let image: String?
        var thumb: URL? { image.flatMap { URL(string: $0 + "/low.webp") } }
    }

    struct Full: Decodable {
        let id: String
        let name: String
        let category: String?
        let hp: Int?
        let types: [String]?
        let stage: String?
        let dexId: [Int]?
        let attacks: [Move]?
        let weaknesses: [TypeValue]?
        let resistances: [TypeValue]?
        let retreat: Int?
        let image: String?
    }

    struct Move: Decodable {
        let name: String
        let cost: [String]?
        let damage: Flex?
        let effect: String?
    }

    struct TypeValue: Decodable {
        let type: String
        let value: String?
    }

    /// A number or a string in the JSON ("damage": 30, or "30+").
    struct Flex: Decodable {
        let text: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { text = String(i) } else { text = (try? c.decode(String.self)) ?? "" }
        }
    }

    enum Fetched {
        case ok(Card)
        case notPokemon(String)
        case offline
    }

    private static func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [URLQueryItem] = []) async -> T? {
        var c = URLComponents(string: "https://api.tcgdex.net/v2/" + path)
        if !query.isEmpty { c?.queryItems = query }
        guard let url = c?.url, let r = try? await URLSession.shared.data(from: url),
              (r.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: r.0)
    }

    /// Printed cards only, not the Pokémon TCG Pocket game's.
    private static func printed(_ id: String) -> Bool { id.range(of: "^(A\\d|B\\d|P-A)", options: .regularExpression) == nil }

    /// Newest sets first: his cards are most likely Mega Evolution or Scarlet & Violet.
    private static func rank(_ id: String) -> Int { id.hasPrefix("me") ? 3 : id.hasPrefix("sv") ? 2 : id.hasPrefix("swsh") ? 1 : 0 }

    static func search(_ name: String) async -> [Brief] {
        var list = await get([Brief].self, "en/cards", [URLQueryItem(name: "name", value: name)]) ?? []
        if list.isEmpty { list = await get([Brief].self, "it/cards", [URLQueryItem(name: "name", value: name)]) ?? [] }
        return Array(list.filter { printed($0.id) && $0.image != nil }.sorted { rank($0.id) > rank($1.id) }.prefix(60))
    }

    /// The card the camera saw: by set code and number, or else the cards with that number whose name it also read.
    static func match(code: String?, number: String, text: String) async -> [Brief] {
        if let code, let set = Sets.ids[code], let n = Int(number) {
            for local in Set([number, String(format: "%03d", n), String(n)]) {
                if let c = await get(Brief.self, "en/cards/\(set)-\(local)") { return [c] }
            }
        }
        let list = await get([Brief].self, "en/cards", [URLQueryItem(name: "localId", value: number)]) ?? []
        let seen = text.lowercased()
        return list.filter { b in
            printed(b.id) && b.image != nil && seen.contains(b.name.lowercased().replacingOccurrences(of: " ex", with: ""))
        }.sorted { rank($0.id) > rank($1.id) }
    }

    /// The whole card in both languages, with its pictures and sprite saved on the iPad.
    static func fetch(_ id: String) async -> Fetched {
        guard let en = await get(Full.self, "en/cards/\(id)") else { return .offline }
        guard en.category == "Pokemon" || en.category == "Pokémon" else { return .notPokemon(en.name) }
        let it = await get(Full.self, "it/cards/\(id)")
        let card = make(en, it)
        for (lang, f) in [("en", Optional(en)), ("it", it)] {
            if let base = f?.image, let path = card.img[lang] {
                await download(base + "/high.webp", to: Store.docs.appendingPathComponent("Cards/" + path))
            }
        }
        if let dex = card.dex, Art.sprite(dex) == nil {
            let pokeapi = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
            if !(await download(pokeapi + "other/showdown/\(dex).gif", to: Store.docs.appendingPathComponent("Sprites/\(dex).gif"))) {
                await download(pokeapi + "\(dex).png", to: Store.docs.appendingPathComponent("Sprites/\(dex).png"))
            }
        }
        return .ok(card)
    }

    /// Like tools/cards.py: the English card's numbers and effects, with the Italian names.
    private static func make(_ e: Full, _ i: Full?) -> Card {
        let ia = i?.attacks ?? []
        let attacks = (e.attacks ?? []).enumerated().map { (k, a) -> Attack in
            let d = a.damage?.text ?? ""
            let digits = String(d.prefix { $0.isNumber })
            let mod = d.dropFirst(digits.count).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "x", with: "×")
            return Attack(name: Words(en: a.name, it: k < ia.count ? ia[k].name : a.name), cost: a.cost ?? [],
                          damage: Int(digits) ?? 0, mod: mod.isEmpty ? nil : mod, fx: Effects.read(a.effect))
        }
        let file = e.id.replacingOccurrences(of: ".", with: "_") + ".webp"
        var img: [String: String] = [:]
        if e.image != nil { img["en"] = "en/" + file }
        if i?.image != nil { img["it"] = "it/" + file }
        let r = e.resistances?.first
        return Card(id: e.id, dex: e.dexId?.first, stage: e.stage, hp: e.hp ?? 0, type: e.types?.first ?? "Colorless",
                    weak: e.weaknesses?.first?.type, resist: r?.type, resistBy: r?.value.flatMap { Int($0.filter(\.isNumber)) },
                    retreat: e.retreat ?? 0, name: Words(en: e.name, it: i?.name ?? e.name), attacks: attacks, img: img)
    }

    @discardableResult
    private static func download(_ s: String, to dest: URL) async -> Bool {
        guard let url = URL(string: s), let r = try? await URLSession.shared.data(from: url),
              (r.1 as? HTTPURLResponse)?.statusCode == 200 else { return false }
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? r.0.write(to: dest)) != nil
    }
}

/// His cards, kept on the iPad.
enum Store {
    static let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private static var file: URL { docs.appendingPathComponent("collection.json") }
    static func load() -> [Card] { (try? JSONDecoder().decode([Card].self, from: Data(contentsOf: file))) ?? [] }
    static func save(_ cards: [Card]) { try? JSONEncoder().encode(cards).write(to: file, options: .atomic) }
}

/// The add screen's state: what the camera or the search found, and what to tell the parent.
@MainActor @Observable final class Adder {
    var query = ""
    var found: [TCGdex.Brief] = []
    var message = ""
    var busy = false
    @ObservationIgnored private var lastKey = ""
    @ObservationIgnored private var lastTime = Date.distantPast
    @ObservationIgnored let game: Game

    init(game: Game) {
        self.game = game
        message = Say.addHint(game.lang)
    }

    func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        busy = true
        message = Say.looking(game.lang)
        found = await TCGdex.search(q)
        message = found.isEmpty ? Say.noneFound(game.lang) : Say.tapHis(game.lang)
        busy = false
    }

    /// What the camera reads, many times a second.
    func scan(_ texts: [String]) {
        let all = texts.joined(separator: " ")
        guard !busy, let number = Sets.number(in: all) else { return }
        let code = Sets.code(in: texts)
        let key = "\(code ?? "?") \(number)"
        guard key != lastKey || Date().timeIntervalSince(lastTime) > 3 else { return }
        lastKey = key
        lastTime = Date()
        Task {
            busy = true
            message = Say.looking(game.lang)
            let r = await TCGdex.match(code: code, number: number, text: all)
            if !r.isEmpty { found = r }
            message = r.isEmpty ? Say.cantRead(game.lang) : Say.tapHis(game.lang)
            busy = false
        }
    }

    func add(_ b: TCGdex.Brief) async {
        busy = true
        message = Say.adding(game.lang)
        switch await TCGdex.fetch(b.id) {
        case .ok(let c):
            game.add(c)
            message = c.playable ? Say.added(game.lang, c.name(game.lang)) : Say.addedForLater(game.lang, c.name(game.lang))
            found = []
            query = ""
            lastKey = ""
        case .notPokemon(let n): message = Say.notPokemon(game.lang, n)
        case .offline: message = Say.offline(game.lang)
        }
        busy = false
    }
}

/// The add screen: the camera on top (on an iPad that has one), a name to type, what was found, and his cards.
/// For a grown-up, upright, over the whole screen.
struct AddView: View {
    let game: Game
    @State private var adder: Adder
    @State private var camera = false

    init(game: Game) {
        self.game = game
        _adder = State(initialValue: Adder(game: game))
    }

    private let phone = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        let l = game.lang
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Say.hisCards(l)).font(.system(size: phone ? 28 : 34, weight: .heavy, design: .rounded))
                Spacer()
                Button { game.closeAdding() } label: {
                    Text(Say.doneWord(l)).font(.system(size: 22, weight: .bold, design: .rounded)).padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            if camera {
                ScannerView { adder.scan($0) }
                    .frame(height: phone ? 220 : 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            HStack {
                TextField(Say.typeName(l), text: $adder.query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 22))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await adder.search() } }
                Button { Task { await adder.search() } } label: {
                    Text(Say.searchWord(l)).font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                if adder.busy { ProgressView() }
                Text(adder.message).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            if !adder.found.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(adder.found) { b in
                            Button { Task { await adder.add(b) } } label: {
                                AsyncImage(url: b.thumb) { img in img.resizable().aspectRatio(contentMode: .fit) } placeholder: {
                                    RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.2))
                                }
                                .frame(width: phone ? 110 : 150, height: phone ? 153 : 209)
                                .overlay(alignment: .topTrailing) {
                                    if game.mine.contains(where: { $0.id == b.id }) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(.green, .white).padding(6)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(adder.busy)
                        }
                    }
                }
                .frame(height: phone ? 159 : 215)
            }
            Divider()
            Text(Say.count(l, game.mine.count)).font(.system(size: 20, weight: .semibold, design: .rounded))
            TimelineView(.periodic(from: .now, by: 2)) { _ in
                Text(Say.voiceInfo(l, Kokoro.shared.on, Kokoro.shared.speed)).font(.system(size: 14, design: .rounded)).foregroundStyle(.gray)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: phone ? 3 : 6), spacing: 10) {
                    ForEach(game.mine) { c in
                        VStack(spacing: 2) {
                            SpriteView(dex: c.dex, box: 64).frame(height: 70)
                            Text(c.name(l)).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.94)))
                        .opacity(c.playable ? 1 : 0.5)
                        .overlay(alignment: .topTrailing) {
                            Button { game.remove(c.id) } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.gray)
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
        .padding(phone ? 16 : 24)
        .background(Color.white)
        .preferredColorScheme(.light)
        .task {
            camera = ScannerView.supported ? await ScannerView.allowed() : false
            if let q = UserDefaults.standard.string(forKey: "query") {
                adder.query = q
                await adder.search()
            }
        }
    }
}

/// The live camera that reads text (VisionKit), on iPads from 2018 on.
struct ScannerView: UIViewControllerRepresentable {
    let onText: ([String]) -> Void

    static var supported: Bool { DataScannerViewController.isSupported }

    static func allowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate, recognizesMultipleItems: true,
                                           isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning { try? vc.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onText: ([String]) -> Void
        init(onText: @escaping ([String]) -> Void) { self.onText = onText }

        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) { send(allItems) }
        func dataScanner(_ s: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) { send(allItems) }

        private func send(_ items: [RecognizedItem]) {
            let texts = items.compactMap { (item: RecognizedItem) -> String? in
                if case .text(let t) = item { return t.transcript }
                return nil
            }
            onText(texts)
        }
    }
}
