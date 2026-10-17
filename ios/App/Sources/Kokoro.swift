import Foundation
import SherpaOnnx

/// Kokoro, a free voice model (Apache 2.0), run on the iPad itself by sherpa-onnx (Apache 2.0). Jordan, 17 Oct 2026,
/// after hearing it: "it does sound a lot better than the ipad's premium voices". The cloud Mac puts the model in the
/// app (`ios/ci/kokoro.sh`). Making a sentence takes about as long as saying it, so each one is kept once made
/// (Library/Caches/Voice) and the game asks for the ones it will need ahead of time. If the model isn't there or won't
/// load, `on` is false and the iPad's own voice speaks instead.
final class Kokoro: @unchecked Sendable {
    static let shared = Kokoro()
    private static let speakers: [Lang: Int] = [.it: 35, .en: 21] // if_sara, bf_emma
    private static let espeak: [Lang: String] = [.it: "it", .en: "en"] // espeak-ng's "en" is British English

    enum When { case now, soon, later }

    private struct Job {
        let text: String
        let lang: Lang
        let key: String
    }

    private let folder = Bundle.main.url(forResource: "Kokoro", withExtension: nil)
    private let there: Bool // the model is in the app
    private let dir: URL
    private let cond = NSCondition()
    private var now: [Job] = [], soon: [Job] = [], later: [Job] = []
    private var queued = Set<String>()
    private var waiters: [String: [CheckedContinuation<URL?, Never>]] = [:]
    private var tts: SherpaOnnxOfflineTtsWrapper?
    private var broken = false

    private init() {
        there = folder.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("model.onnx").path) } ?? false
        dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Voice")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard there else { note("kokoro: no model in the app"); return }
        let t = Thread { [unowned self] in self.work() }
        t.qualityOfService = .userInitiated
        t.start()
    }

    var on: Bool {
        cond.lock()
        defer { cond.unlock() }
        return there && !broken
    }

    /// Splits a line into sentences: each is made, kept and played on its own, so the next is made while one plays.
    static func sentences(_ text: String) -> [String] {
        var out: [String] = [], cur = ""
        let chars = Array(text)
        for (i, c) in chars.enumerated() {
            cur.append(c)
            if ".!?…".contains(c), i + 1 == chars.count || chars[i + 1] == " " {
                let s = cur.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { out.append(s) }
                cur = ""
            }
        }
        let s = cur.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty { out.append(s) }
        return out
    }

    /// FNV-1a, so a sentence keeps the same file name from one launch to the next (Swift's hashValue doesn't).
    private func key(_ text: String, _ l: Lang) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in "\(l.rawValue)|\(Kokoro.speakers[l]!)|v1|\(text)".utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }

    private func file(_ text: String, _ l: Lang) -> URL { dir.appendingPathComponent(key(text, l) + ".wav") }

    /// Make these sentences ahead of time (now: about to be said; soon: this game; later: when there's nothing else).
    func ask(_ texts: [String], _ l: Lang, _ when: When) {
        guard there else { return }
        cond.lock()
        if broken { cond.unlock(); return }
        for t in texts {
            let k = key(t, l)
            if queued.contains(k) { // already waiting: move it up if it's needed sooner
                if when == .now, let i = soon.firstIndex(where: { $0.key == k }) { now.append(soon.remove(at: i)) }
                else if when == .now, let i = later.firstIndex(where: { $0.key == k }) { now.append(later.remove(at: i)) }
                else if when == .soon, let i = later.firstIndex(where: { $0.key == k }) { soon.append(later.remove(at: i)) }
                continue
            }
            if FileManager.default.fileExists(atPath: file(t, l).path) { continue }
            queued.insert(k)
            let j = Job(text: t, lang: l, key: k)
            switch when {
            case .now: now.append(j)
            case .soon: soon.append(j)
            case .later: later.append(j)
            }
        }
        cond.signal()
        cond.unlock()
    }

    /// The sentence's sound, made now if it isn't yet. Nil when Kokoro can't, and the iPad's own voice says it.
    func get(_ text: String, _ l: Lang) async -> URL? {
        guard there else { return nil }
        let f = file(text, l)
        if FileManager.default.fileExists(atPath: f.path) { return f }
        ask([text], l, .now)
        let k = key(text, l)
        return await withCheckedContinuation { c in
            cond.lock()
            if broken { cond.unlock(); c.resume(returning: nil); return }
            if FileManager.default.fileExists(atPath: f.path) { cond.unlock(); c.resume(returning: f); return }
            waiters[k, default: []].append(c)
            cond.unlock()
        }
    }

    private func work() {
        while true {
            cond.lock()
            while now.isEmpty && soon.isEmpty && later.isEmpty { cond.wait() }
            let j = !now.isEmpty ? now.removeFirst() : !soon.isEmpty ? soon.removeFirst() : later.removeFirst()
            cond.unlock()
            let made = autoreleasepool { make(j) }
            cond.lock()
            queued.remove(j.key)
            var done = waiters.removeValue(forKey: j.key) ?? []
            if broken { // give up on everything: the iPad's voice takes over
                done += waiters.values.flatMap { $0 }
                waiters = [:]
                now = []; soon = []; later = []; queued = []
            }
            cond.unlock()
            let f = file(j.text, j.lang)
            for w in done { w.resume(returning: made && FileManager.default.fileExists(atPath: f.path) ? f : nil) }
        }
    }

    private func make(_ j: Job) -> Bool {
        if tts == nil && !broken { load() }
        guard let tts else { return false }
        let t = Date()
        let config = SherpaOnnxGenerationConfigSwift(speed: 1.0, sid: Kokoro.speakers[j.lang]!, extra: ["lang": Kokoro.espeak[j.lang]!])
        let audio = tts.generateWithConfig(text: j.text, config: config, callback: nil, arg: nil)
        guard audio.n > 0 else { note("kokoro: no sound for \"\(j.text)\""); return false }
        let f = file(j.text, j.lang)
        let part = dir.appendingPathComponent(j.key + ".part.wav")
        guard audio.save(filename: part.path) != 0 else { note("kokoro: couldn't save \"\(j.text)\""); return false }
        try? FileManager.default.removeItem(at: f)
        try? FileManager.default.moveItem(at: part, to: f)
        note(String(format: "kokoro: %.1fs of speech made in %.1fs: %@", Double(audio.n) / Double(audio.sampleRate), Date().timeIntervalSince(t), j.text))
        return true
    }

    private func load() {
        guard let m = folder?.path else { fail(); return }
        let t = Date()
        let threads = min(4, max(1, ProcessInfo.processInfo.activeProcessorCount - 2))
        var config = sherpaOnnxOfflineTtsConfig(model: sherpaOnnxOfflineTtsModelConfig(
            kokoro: sherpaOnnxOfflineTtsKokoroModelConfig(model: m + "/model.onnx", voices: m + "/voices.bin", tokens: m + "/tokens.txt",
                                                          dataDir: m + "/espeak-ng-data", lang: "it"),
            numThreads: threads))
        let w = SherpaOnnxOfflineTtsWrapper(config: &config)
        guard w.tts != nil else { note("kokoro: the model didn't load"); fail(); return }
        tts = w
        note(String(format: "kokoro: loaded in %.1fs, %d threads", Date().timeIntervalSince(t), threads))
    }

    private func fail() {
        cond.lock()
        broken = true
        cond.unlock()
    }
}

/// Pokémon names said the way kids say them (Data/names.json): "Pikaciù" in Italian, "Peekachoo" in English.
enum Names {
    private static let table: [(NSRegularExpression, [String: String])] = {
        guard let url = Bundle.main.url(forResource: "names", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { note("no names.json"); return [] }
        return all.compactMap { name, v in
            guard let say = v as? [String: String],
                  let re = try? NSRegularExpression(pattern: "\\b" + NSRegularExpression.escapedPattern(for: name) + "\\b") else { return nil }
            return (re, say)
        }
    }()

    static func spoken(_ text: String, _ l: Lang) -> String {
        var s = text
        for (re, say) in table {
            guard let r = say[l.rawValue] else { continue }
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: NSRegularExpression.escapedTemplate(for: r))
        }
        return s
    }
}
