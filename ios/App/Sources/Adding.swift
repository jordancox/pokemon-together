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

/// Every printed set (Data/sets.json, from tools/cards.py sets): the code printed on its cards ("SVI"), the number
/// after the slash ("198" in 038/198) and when it came out.
enum Sets {
    struct Info: Decodable {
        let code: String?
        let of: Int?
        let date: String?
    }

    static let all: [String: Info] = {
        guard let url = Bundle.main.url(forResource: "sets", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Info].self, from: data)) ?? [:]
    }()

    /// Code → set id, the newest set when two share a code.
    static let ids: [String: String] = {
        var out: [String: String] = [:]
        for (id, s) in all.sorted(by: { ($0.value.date ?? "") > ($1.value.date ?? "") }) where s.code != nil && out[s.code!] == nil {
            out[s.code!] = id
        }
        return out
    }()

    static func date(_ set: String) -> String { all[set]?.date ?? "" }

    /// The sets whose cards end in this number ("/198"), newest first.
    static func with(total: Int) -> [String] {
        all.filter { $0.value.of == total }.map(\.key).sorted { date($0) > date($1) }
    }

    /// One of these sets' codes in the text. Only those sets: a card is full of words that are some old set's code
    /// ("HP", or Italian "la", "si", "ma"). The language is printed beside the code ("SVI IT"), so it's often read as one
    /// word ("SVIIT"); a 1 can be read for an I.
    static func code(in text: String, among sets: [String]) -> String? {
        let codes = Set(sets.compactMap { all[$0]?.code })
        let words = text.uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 }
        for w in words {
            let i = w.replacingOccurrences(of: "1", with: "I")
            for c in [w, String(w.dropLast(2)), i, String(i.dropLast(2))] where codes.contains(c) { return sets.first { all[$0]?.code == c } }
        }
        return nil
    }

    /// The card's number and the set's: "038" and 198 in "038/198".
    static func number(in text: String) -> (String, Int)? {
        guard let rx = try? NSRegularExpression(pattern: "(\\d{1,3})\\s*/\\s*(\\d{2,3})"),
              let m = rx.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              let total = Int((text as NSString).substring(with: m.range(at: 2))) else { return nil }
        return ((text as NSString).substring(with: m.range(at: 1)), total)
    }

    /// What's printed at the bottom left of the card, to check against his: "SVI 038/198".
    static func label(_ b: TCGdex.Brief) -> String {
        let s = all[b.set]
        let n = s?.of.map { "\(b.number)/\($0)" } ?? b.number
        return [s?.code, n].compactMap { $0 }.joined(separator: " ")
    }
}

enum TCGdex {
    struct Brief: Decodable, Identifiable, Hashable {
        let id: String
        let localId: String?
        let name: String
        let image: String?
        var thumb: URL? { image.flatMap { URL(string: $0 + "/low.webp") } }
        var number: String { localId ?? String(id.split(separator: "-").last ?? "") }
        /// "sv01" for "sv01-038" (a set id can have a dash in it too: "30th-c-001")
        var set: String { String(id.dropLast(number.count + 1)) }
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

    /// Looking cards up gives up after a few seconds: with no limit, one that hung kept the camera from reading the next
    /// card (Jordan, 18 Oct: "I load four and then can't load anymore. Have to close the app").
    private static let net = session(request: 10, total: 25)
    /// Pictures download in the background, and TCGdex can take more than ten seconds to start sending one (two came
    /// back missing on the cloud Mac with the lookups' limits), so they get a minute.
    private static let pictures = session(request: 60, total: 120)

    private static func session(request: Double, total: Double) -> URLSession {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = request
        c.timeoutIntervalForResource = total
        return URLSession(configuration: c)
    }

    private static func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [URLQueryItem] = []) async -> T? {
        var c = URLComponents(string: "https://api.tcgdex.net/v2/" + path)
        if !query.isEmpty { c?.queryItems = query }
        guard let url = c?.url, let r = try? await net.data(from: url),
              (r.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: r.0)
    }

    /// Printed cards only, not the Pokémon TCG Pocket game's.
    private static func printed(_ id: String) -> Bool { id.range(of: "^(A\\d|B\\d|P-A)", options: .regularExpression) == nil }

    /// With a picture, newest sets first: his cards are most likely the latest.
    private static func newest(_ list: [Brief]) -> [Brief] {
        Array(list.filter { printed($0.id) && $0.image != nil }.sorted { Sets.date($0.set) > Sets.date($1.set) }.prefix(60))
    }

    /// One set's card with this number (printed "038", "38" or "TG05").
    private static func card(_ set: String, _ number: String) async -> Brief? {
        let n = Int(number)
        var tried = Set<String>()
        for local in [number, n.map { String(format: "%03d", $0) }, n.map(String.init)].compactMap({ $0 }) where tried.insert(local).inserted {
            if let c = await get(Brief.self, "en/cards/\(set)-\(local)") { return c }
        }
        return nil
    }

    /// What a parent typed: a name ("pikachu"), the number at the bottom left ("38/198", "SVI 38/198"), a set code and
    /// a number ("SVI 38"), or a name and a number ("pikachu 38").
    static func search(_ q: String) async -> [Brief] {
        if case let (n, total)? = Sets.number(in: q) { return await match(number: n, of: total, line: q, text: q) }
        let words = q.split(separator: " ").map(String.init)
        let name = words.filter { Int($0) == nil }.joined(separator: " ")
        if let n = words.first(where: { Int($0) != nil }), let k = Int(n) {
            if let set = Sets.ids[name.uppercased()] { return await card(set, n).map { [$0] } ?? [] }
            var query = [URLQueryItem(name: "localId", value: String(k))]
            if !name.isEmpty { query.append(URLQueryItem(name: "name", value: name)) }
            var list = await get([Brief].self, "en/cards", query) ?? []
            if list.isEmpty, !name.isEmpty { list = await get([Brief].self, "it/cards", query) ?? [] }
            return newest(list.filter { Int($0.number) == k })
        }
        var list = await get([Brief].self, "en/cards", [URLQueryItem(name: "name", value: q)]) ?? []
        if list.isEmpty { list = await get([Brief].self, "it/cards", [URLQueryItem(name: "name", value: q)]) ?? [] }
        return newest(list)
    }

    /// The card with this number: in the set whose code is printed beside it, or else in each set whose cards end in
    /// the same "/198" (keeping those whose name was read too, when there are some).
    static func match(number: String, of total: Int, line: String, text: String) async -> [Brief] {
        let sets = Sets.with(total: total)
        if let set = Sets.code(in: line, among: sets) ?? Sets.code(in: text, among: sets), let c = await card(set, number) { return [c] }
        var found: [Brief] = []
        for set in sets.prefix(6) { if let c = await card(set, number) { found.append(c) } }
        found = found.filter { printed($0.id) && $0.image != nil }
        let seen = text.lowercased()
        let named = found.filter { seen.contains($0.name.lowercased().replacingOccurrences(of: " ex", with: "")) }
        return named.isEmpty ? found : named
    }

    /// Downloads again the pictures a card is missing (Yanma's didn't download on Jordan's iPad, 18 Oct, and nothing
    /// said so). True when none are missing after.
    static func repair(_ c: Card) async -> Bool {
        for (lang, file) in Art.missing(c) {
            guard let f = await get(Full.self, "\(lang)/cards/\(c.id)"), let base = f.image else { continue }
            await download(base + "/high.webp", to: Store.docs.appendingPathComponent("Cards/" + file))
        }
        return Art.missing(c).isEmpty
    }

    /// The whole card in both languages. Its pictures and sprite come after (`finish`), so adding it doesn't wait for them.
    static func fetch(_ id: String) async -> Fetched {
        guard let en = await get(Full.self, "en/cards/\(id)") else { return .offline }
        guard en.category == "Pokemon" || en.category == "Pokémon" else { return .notPokemon(en.name) }
        let it = await get(Full.self, "it/cards/\(id)")
        return .ok(make(en, it))
    }

    /// The card's pictures and sprite, saved on the iPad. True when its pictures are all there.
    static func finish(_ c: Card) async -> Bool {
        let ok = await repair(c)
        if let dex = c.dex, Art.sprite(dex) == nil {
            let pokeapi = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
            if !(await download(pokeapi + "other/showdown/\(dex).gif", to: Store.docs.appendingPathComponent("Sprites/\(dex).gif"))) {
                await download(pokeapi + "\(dex).png", to: Store.docs.appendingPathComponent("Sprites/\(dex).png"))
            }
        }
        return ok
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
        guard let url = URL(string: s), let r = try? await pictures.data(from: url),
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
    var busy = false   // a search or an add: the result buttons wait
    @ObservationIgnored private(set) var adding = false
    @ObservationIgnored private(set) var lookups = 0 // camera lookups, for -scantest
    @ObservationIgnored private var lastKey = ""   // the number last looked up: once per card in view
    @ObservationIgnored private var lastTime = Date.distantPast
    @ObservationIgnored private var seen = ""      // the number on the last frames, and how many in a row
    @ObservationIgnored private var seenCount = 0
    @ObservationIgnored private var frames = 0     // what the camera has sent, for the grey line under it
    @ObservationIgnored private var lookupID = 0
    @ObservationIgnored private var lookupStart = Date.distantPast
    @ObservationIgnored private var looking = false
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
        note("search \"\(q)\": \(found.count) found: " + found.prefix(8).map { "\($0.id) (\(Sets.label($0)))" }.joined(separator: ", "))
        message = found.isEmpty ? Say.noneFound(game.lang) : Say.tapCard(game.lang)
        busy = false
    }

    /// What the camera reads, many times a second: each line of text it sees. A card is looked up once, when its number
    /// has read the same on three frames in a row (a blurry frame can misread a digit). Build 20 looked it up again
    /// whenever the line read a little differently, so "Looking…" and the pictures flickered (Jordan, 18 Oct, on the
    /// iPhone: "headache inducing with this constant popping up on screen stuff").
    /// A lookup that has taken more than 12 seconds doesn't hold up the next card: its answer is dropped.
    func scan(_ texts: [String]) {
        frames += 1
        let stuck = looking && Date().timeIntervalSince(lookupStart) > 12
        guard !adding, !looking || stuck, let line = texts.first(where: { Sets.number(in: $0) != nil }),
              case let (number, total)? = Sets.number(in: line) else { return }
        let key = "\(Int(number) ?? 0)/\(total)"
        if key == seen { seenCount += 1 } else { seen = key; seenCount = 1 }
        // a card not found is tried again after 5 seconds, not on every frame
        guard seenCount >= 3, key != lastKey || stuck || (found.isEmpty && Date().timeIntervalSince(lastTime) > 5) else { return }
        lastKey = key
        lastTime = Date()
        lookups += 1
        lookupID += 1
        let id = lookupID
        looking = true
        lookupStart = Date()
        if found.isEmpty { message = Say.looking(game.lang) }
        Task {
            let r = await TCGdex.match(number: number, of: total, line: line, text: texts.joined(separator: " "))
            guard id == lookupID else { return } // a newer lookup took over
            found = r
            message = r.isEmpty ? Say.cantRead(game.lang) : Say.tapCard(game.lang)
            looking = false
        }
    }

    /// The grey line under the camera: what it's reading, for a screenshot when it seems stuck.
    var cameraInfo: String {
        let state = adding ? "adding" : looking ? "looking \(Int(Date().timeIntervalSince(lookupStart)))s" : "ready"
        return "camera: \(frames) reads · \(seen.isEmpty ? "no number yet" : seen + " ×\(seenCount)") · \(lookups) lookups · \(state)"
    }

    func add(_ b: TCGdex.Brief) async {
        busy = true
        adding = true
        message = Say.adding(game.lang)
        switch await TCGdex.fetch(b.id) {
        case .ok(let c):
            game.add(c)
            message = c.playable ? Say.added(game.lang, c.name(game.lang)) : Say.addedForLater(game.lang, c)
            found = []
            query = ""
            lastTime = .distantFuture // the card just added, still under the camera, isn't looked up again
            Task { // its pictures, while the next card is read
                let ok = await TCGdex.finish(c)
                game.pictures += 1
                if !ok { message = Say.noPicture(game.lang, c.name(game.lang)) }
            }
        case .notPokemon(let n): message = Say.notPokemon(game.lang, n)
        case .offline: message = Say.offline(game.lang)
        }
        adding = false
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
                Text(Say.yourCards(l)).font(.system(size: phone ? 28 : 34, weight: .heavy, design: .rounded))
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
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(adder.cameraInfo).font(.system(size: 13, design: .monospaced)).foregroundStyle(.gray)
                }
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
                                VStack(spacing: 4) {
                                    AsyncImage(url: b.thumb) { img in img.resizable().aspectRatio(contentMode: .fit) } placeholder: {
                                        RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.2))
                                    }
                                    .frame(width: phone ? 110 : 150, height: phone ? 153 : 209)
                                    .overlay(alignment: .topTrailing) {
                                        if game.mine.contains(where: { $0.id == b.id }) {
                                            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(.green, .white).padding(6)
                                        }
                                    }
                                    // the code and number printed at the bottom left, to check against his card
                                    Text(Sets.label(b)).font(.system(size: phone ? 14 : 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                                        .frame(width: phone ? 110 : 150)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(adder.busy)
                        }
                    }
                }
                .frame(height: phone ? 182 : 240)
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
                            if !c.playable { Text(Say.cantBattle(l)).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.red) }
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
        // no boxes drawn round the text it reads, and no "Slow down" tips: they popped up all the time (build 20)
        let vc = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate, recognizesMultipleItems: true,
                                           isHighFrameRateTrackingEnabled: false, isGuidanceEnabled: false, isHighlightingEnabled: false)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning { try? vc.startScanning() }
        context.coordinator.vc = vc
    }

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onText: ([String]) -> Void
        weak var vc: DataScannerViewController?
        init(onText: @escaping ([String]) -> Void) {
            self.onText = onText
            super.init()
            // back from another app or the lock screen: the camera may have stopped
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                if let vc = self?.vc, !vc.isScanning { try? vc.startScanning() }
            }
        }

        func dataScanner(_ s: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            note("camera stopped: \(error)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if !s.isScanning { try? s.startScanning() } }
        }

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
