import SwiftUI
import UIKit
import ImageIO

// The cards (Data/cards.json, made by tools/cards.py from cards.txt and TCGdex), their pictures (Cards/, downloaded on the
// cloud Mac at build time) and the Pokémon sprites (Sprites/, from PokeAPI).

enum Lang: String { case it, en }

struct Words: Codable {
    let en: String
    let it: String
    func callAsFunction(_ l: Lang) -> String { l == .it ? it : en }
}

/// What an attack does besides its damage, read from the card's English text by tools/cards.py ("skip": not played yet).
struct Effect: Codable {
    let kind: String
    let n: Int?
    let each: Int?
}

struct Attack: Codable {
    let name: Words
    let cost: [String]
    let damage: Int
    let mod: String?
    let fx: Effect?
    /// In the game: it does damage, or something the app knows how to play.
    var shown: Bool { damage > 0 || (fx != nil && fx?.kind != "skip") }
    /// As printed on the card: "50", "20+", "10×", or nothing.
    var label: String { damage > 0 ? "\(damage)\(mod ?? "")" : "" }
}

struct Card: Codable, Identifiable {
    let id: String
    let dex: Int?
    let stage: String?
    let hp: Int
    let type: String
    let weak: String?
    let resist: String?
    let resistBy: Int?
    let retreat: Int
    let name: Words
    let attacks: [Attack]
    let img: [String: String]

    var moves: [Attack] { attacks.filter(\.shown) }
    /// Level 1 plays Basic Pokémon with at least one attack that does damage.
    var playable: Bool { stage == "Basic" && moves.contains { $0.damage > 0 } }

    static let all: [Card] = {
        guard let url = Bundle.main.url(forResource: "cards", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url) else { note("no cards.json"); return [] }
        do { return try JSONDecoder().decode([Card].self, from: data) } catch { note("cards.json: \(error)"); return [] }
    }()
}

/// The ten Pokémon types (plus Colorless): their colour, the symbol on their Energy and their name.
enum Kind {
    static func color(_ t: String?) -> Color {
        switch t ?? "" {
        case "Grass": Color(red: 0.36, green: 0.72, blue: 0.36)
        case "Fire": Color(red: 0.93, green: 0.45, blue: 0.20)
        case "Water": Color(red: 0.25, green: 0.56, blue: 0.87)
        case "Lightning": Color(red: 0.96, green: 0.76, blue: 0.13)
        case "Psychic": Color(red: 0.64, green: 0.38, blue: 0.78)
        case "Fighting": Color(red: 0.74, green: 0.38, blue: 0.22)
        case "Darkness": Color(red: 0.24, green: 0.29, blue: 0.36)
        case "Metal": Color(red: 0.55, green: 0.60, blue: 0.66)
        case "Fairy": Color(red: 0.90, green: 0.52, blue: 0.72)
        case "Dragon": Color(red: 0.78, green: 0.62, blue: 0.16)
        case "Colorless": Color(red: 0.72, green: 0.70, blue: 0.66)
        default: Color(white: 0.45)
        }
    }

    static func symbol(_ t: String) -> String {
        switch t {
        case "Grass": "leaf.fill"
        case "Fire": "flame.fill"
        case "Water": "drop.fill"
        case "Lightning": "bolt.fill"
        case "Psychic": "eye.fill"
        case "Fighting": "hand.raised.fill"
        case "Darkness": "moon.fill"
        case "Metal": "gearshape.fill"
        case "Fairy": "sparkles"
        case "Dragon": "tornado"
        default: "star.fill"
        }
    }

    static func name(_ t: String, _ l: Lang) -> String {
        let it = ["Grass": "Erba", "Fire": "Fuoco", "Water": "Acqua", "Lightning": "Lampo", "Psychic": "Psico", "Fighting": "Lotta",
                  "Darkness": "Oscurità", "Metal": "Metallo", "Fairy": "Folletto", "Dragon": "Drago", "Colorless": "Incolore"]
        return l == .it ? it[t] ?? t : t
    }
}

enum Art {
    private static var cards: [String: UIImage] = [:]
    private static var sprites: [Int: UIImage] = [:]
    private static let root = Bundle.main.resourceURL!

    /// The card's picture in that language, or in the other one.
    static func card(_ c: Card, _ l: Lang) -> UIImage? {
        guard let file = c.img[l.rawValue] ?? c.img["en"] ?? c.img["it"] else { return nil }
        if let i = cards[file] { return i }
        let i = UIImage(contentsOfFile: Store.docs.appendingPathComponent("Cards/" + file).path) // added on the iPad
            ?? UIImage(contentsOfFile: root.appendingPathComponent("Cards/" + file).path)
        cards[file] = i
        return i
    }

    /// The Pokémon's sprite, animated if it's a GIF. Its size is in the sprite's own pixels.
    static func sprite(_ dex: Int?) -> UIImage? {
        guard let dex else { return nil }
        if let i = sprites[dex] { return i }
        let fm = FileManager.default
        let places = [Store.docs.appendingPathComponent("Sprites"), root.appendingPathComponent("Sprites")] // added on the iPad, or built in
        let gif = places.map { $0.appendingPathComponent("\(dex).gif") }.first { fm.fileExists(atPath: $0.path) }
        let png = places.map { $0.appendingPathComponent("\(dex).png") }.first { fm.fileExists(atPath: $0.path) }
        var image: UIImage?
        if let gif, let src = CGImageSourceCreateWithURL(gif as CFURL, nil) {
            var frames: [UIImage] = [], total = 0.0
            for i in 0..<CGImageSourceGetCount(src) {
                guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
                frames.append(UIImage(cgImage: cg))
                let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
                let g = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                let d = (g?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (g?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
                total += d < 0.02 ? 0.1 : d
            }
            image = frames.count > 1 ? UIImage.animatedImage(with: frames, duration: total) : frames.first
        } else {
            image = png.flatMap { UIImage(contentsOfFile: $0.path) }
        }
        sprites[dex] = image
        return image
    }
}

/// The app's own messages, for the cloud Mac's logs.
func note(_ s: String) {
    FileHandle.standardError.write(("[insieme] " + s + "\n").data(using: .utf8)!)
}
