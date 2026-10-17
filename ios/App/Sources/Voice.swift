import AVFoundation

/// The voice that runs the game. It uses the best voice on the iPad for the language: a downloaded Enhanced or Premium
/// one if there is one (Settings → Accessibility → Spoken Content → Voices).
@MainActor final class Voice: NSObject, AVSpeechSynthesizerDelegate {
    var lang: Lang = .it
    var fast = false  // -fast on the cloud Mac: lines go to the log only
    var quiet = false // voice off: the line is shown instead, and the game waits about as long as reading it takes
    private(set) var last = ""
    private let synth = AVSpeechSynthesizer()
    private var current: ObjectIdentifier?
    private var waiting: CheckedContinuation<Void, Never>?
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
        finish()
        last = text
        note("say: \(text)")
        if fast { try? await Task.sleep(nanoseconds: 50_000_000); return }
        synth.stopSpeaking(at: .immediate)
        if quiet { try? await Task.sleep(nanoseconds: UInt64((0.9 + Double(text.count) * 0.04) * 1e9)); return }
        let u = AVSpeechUtterance(string: text)
        u.voice = voice(lang)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.pitchMultiplier = 1.08
        let id = ObjectIdentifier(u)
        current = id
        // Never wait for ever (no voice installed, no sound).
        let limit = 2 + Double(text.count) * 0.12
        Task { try? await Task.sleep(nanoseconds: UInt64(limit * 1e9)); if self.current == id { self.finish() } }
        await withCheckedContinuation { c in
            waiting = c
            synth.speak(u)
        }
    }

    func speak(_ text: String) { Task { await say(text) } }

    func stop() {
        finish()
        synth.stopSpeaking(at: .immediate)
    }

    private func finish() {
        current = nil
        waiting?.resume()
        waiting = nil
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { ended(u) }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { ended(u) }
    nonisolated private func ended(_ u: AVSpeechUtterance) {
        let id = ObjectIdentifier(u)
        Task { @MainActor in if self.current == id { self.finish() } }
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
