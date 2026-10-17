import AVFoundation

/// The voice that runs the game: Kokoro (Kokoro.swift), or, while it can't, the best voice on the iPad for the language
/// (a downloaded Enhanced or Premium one if there is one: Settings → Accessibility → Spoken Content → Voices).
@MainActor final class Voice: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    var lang: Lang = .it
    var fast = false  // -fast on the cloud Mac: lines go to the log only
    var quiet = false // voice off: the line is shown instead, and the game waits about as long as reading it takes
    private(set) var last = ""
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var utterance: AVSpeechUtterance?
    private var line = 0 // goes up with each line, and on stop(): a line still playing checks it's still wanted
    private var waiting: CheckedContinuation<Void, Never>?
    private var waitID = 0
    private var voices: [Lang: AVSpeechSynthesisVoice] = [:]

    override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Says it, and returns once it's said (or cut off by the next line).
    func say(_ text: String) async {
        guard !text.isEmpty else { return }
        cut()
        line += 1
        let me = line
        last = text
        note("say: \(text)")
        if fast { try? await Task.sleep(nanoseconds: 50_000_000); return }
        if quiet { try? await Task.sleep(nanoseconds: UInt64((0.9 + Double(text.count) * 0.04) * 1e9)); return }
        let spoken = Names.spoken(text, lang)
        guard Kokoro.shared.on else { await apple(spoken); return }
        let parts = Kokoro.sentences(spoken)
        Kokoro.shared.ask(parts, lang, .now) // all of them, in order: the next is made while one plays
        for (i, part) in parts.enumerated() {
            guard let url = await Kokoro.shared.get(part, lang) else {
                if line == me { await apple(parts[i...].joined(separator: " ")) }
                return
            }
            guard line == me else { return }
            await play(url)
            guard line == me else { return }
        }
    }

    func speak(_ text: String) { Task { await say(text) } }

    /// Kokoro makes these lines' sentences ahead of time, so they're ready when they're said.
    func prepare(_ lines: [String], _ when: Kokoro.When) {
        guard !fast, !quiet, Kokoro.shared.on else { return }
        Kokoro.shared.ask(lines.flatMap { Kokoro.sentences(Names.spoken($0, lang)) }, lang, when)
    }

    func stop() {
        cut()
        line += 1
    }

    private func cut() {
        synth.stopSpeaking(at: .immediate)
        utterance = nil // so its late "cancelled" can't end the next line
        player?.stop()
        player = nil
        finish()
    }

    private func play(_ url: URL) async {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player?.stop()
        p.delegate = self
        player = p
        await wait(p.duration + 1) { p.play() }
    }

    private func apple(_ text: String) async {
        let u = AVSpeechUtterance(string: text)
        u.voice = voice(lang)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.pitchMultiplier = 1.08
        utterance = u
        // Never wait for ever (no voice installed, no sound).
        await wait(2 + Double(text.count) * 0.12) { synth.speak(u) }
    }

    /// Starts it, and returns when it's done (finish()) or after `limit` seconds.
    private func wait(_ limit: Double, _ start: () -> Void) async {
        finish()
        waitID += 1
        let w = waitID
        Task { try? await Task.sleep(nanoseconds: UInt64(limit * 1e9)); if self.waitID == w { self.finish() } }
        await withCheckedContinuation { c in
            waiting = c
            start()
        }
    }

    private func finish() {
        waiting?.resume()
        waiting = nil
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { ended(ObjectIdentifier(u)) }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { ended(ObjectIdentifier(u)) }
    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) { ended(ObjectIdentifier(p)) }
    nonisolated private func ended(_ id: ObjectIdentifier) {
        Task { @MainActor in
            if self.utterance.map({ ObjectIdentifier($0) }) == id || self.player.map({ ObjectIdentifier($0) }) == id { self.finish() }
        }
    }

    private func voice(_ l: Lang) -> AVSpeechSynthesisVoice? {
        if let v = voices[l] { return v }
        let prefer = l == .it ? ["it-IT"] : ["en-US", "en-GB", "en-AU", "en-IE"]
        let good = ["Alice", "Federica", "Luca", "Emma", "Samantha", "Ava", "Daniel", "Karen"]
        func score(_ v: AVSpeechSynthesisVoice) -> Int {
            v.quality.rawValue * 100 + (prefer.firstIndex(of: v.language).map { 10 * (prefer.count - $0) } ?? 0)
                + (good.contains(v.name) ? 5 : 0) - (v.identifier.contains("eloquence") ? 50 : 0)
        }
        let all = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(l.rawValue) && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        let v = all.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: prefer[0])
        voices[l] = v
        note("voice \(l.rawValue): \(v?.name ?? "none") \(v?.language ?? "") quality \(v?.quality.rawValue ?? 0)")
        return v
    }
}

/// The game's little sounds (Sounds/*.wav, made by tools/sounds.py).
@MainActor enum Sound {
    private static var players: [String: AVAudioPlayer] = [:]

    static func play(_ name: String) {
        if players[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") {
            players[name] = try? AVAudioPlayer(contentsOf: url)
            players[name]?.volume = 0.6
            players[name]?.prepareToPlay()
        }
        guard let p = players[name] else { return }
        p.currentTime = 0
        p.play()
    }
}
