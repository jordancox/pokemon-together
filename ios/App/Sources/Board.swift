import SwiftUI

// The iPad lies flat between the two players, upright for the one at the bottom. Each gets half the screen, the top
// half turned round to face the other player. Each half is designed at one size (half an 11-inch iPad) and scaled to fit.
let halfSize = CGSize(width: 834, height: 575)

@main
struct InsiemeApp: App {
    @State private var game = Game()
    var body: some Scene {
        WindowGroup { Board(game: game) }
    }
}

struct Board: View {
    let game: Game
    var body: some View {
        VStack(spacing: 0) {
            Half(game: game, side: 1).rotationEffect(.degrees(180))
            Seam(game: game).frame(height: 44).zIndex(2)
            Half(game: game, side: 0)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear { game.boot() }
    }
}

struct Half: View {
    let game: Game
    let side: Int
    var body: some View {
        Fit(size: halfSize) {
            ZStack {
                Backdrop(type: game.sides[side].card?.type, lit: game.step == .battle && game.turn == side)
                switch game.step {
                case .pick: PickView(game: game, side: side)
                case .coin, .battle: BattleView(game: game, side: side)
                case .over: OverView(game: game, side: side)
                }
                CoinView(angle: game.coinAngle, pokemon: game.coinPokemon, front: game.sides[0].card?.dex, back: game.sides[1].card?.dex)
                    .position(x: halfSize.width / 2, y: 230)
                    .opacity(game.coinOut ? 1 : 0)
                    .allowsHitTesting(false)
                if game.zoom[side] { Zoom(game: game, side: side) }
            }
        }
        .clipped()
    }
}

/// The strip across the middle: the Poké Ball (start, say it again, play again; hold it to stop a game), the languages
/// and the voice switch.
struct Seam: View {
    let game: Game
    var body: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.07))
            HStack(spacing: 18) {
                flag(.it, "🇮🇹")
                flag(.en, "🇬🇧")
                Spacer()
                Button { game.setQuiet(!game.quiet) } label: {
                    Image(systemName: game.quiet ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(game.quiet ? 0.5 : 0.9))
                        .frame(width: 56, height: 44)
                }
            }
            .padding(.horizontal, 24)
            Pokeball(top: Kind.color(game.sides[1].card?.type), bottom: Kind.color(game.sides[0].card?.type))
                .frame(width: 96, height: 96)
                .modifier(Pulse(on: (game.step == .pick && game.sides.allSatisfy { $0.card != nil }) || game.step == .over))
                .contentShape(Circle())
                .onTapGesture { game.ball() }
                .onLongPressGesture(minimumDuration: 1.2) { game.quit() }
        }
    }

    private func flag(_ l: Lang, _ emoji: String) -> some View {
        Button { game.setLang(l) } label: {
            Text(emoji).font(.system(size: 30)).opacity(game.lang == l ? 1 : 0.35).frame(width: 48, height: 44)
        }
    }
}

/// The half's background: the colour of the Pokémon's type, with a glowing edge on the side whose turn it is.
struct Backdrop: View {
    let type: String?
    let lit: Bool
    var body: some View {
        let c = Kind.color(type)
        ZStack {
            LinearGradient(colors: [c, c.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            if lit {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.55 + 0.35 * sin(t * 4)), lineWidth: 9)
                }
            }
        }
    }
}

/// Draws its content at one size and scales it to fit the space it's given.
struct Fit<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width / size.width, g.size.height / size.height)
            content
                .frame(width: size.width, height: size.height)
                .scaleEffect(s)
                .frame(width: g.size.width, height: g.size.height)
        }
    }
}

struct Pulse: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !on)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            content.scaleEffect(on ? 1 + 0.06 * sin(t * 5) : 1)
        }
    }
}

/// Shakes sideways three times as `t` goes up by one.
struct Shake: GeometryEffect {
    var t: CGFloat
    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 16 * sin(t * .pi * 6), y: 0))
    }
}

struct Pokeball: View {
    var top: Color = .red
    var bottom: Color = .white
    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(bottom)
                Circle().trim(from: 0.5, to: 1).fill(top)
                Rectangle().fill(.black).frame(height: d * 0.1)
                Circle().fill(.white).frame(width: d * 0.36, height: d * 0.36)
                    .overlay(Circle().stroke(.black, lineWidth: d * 0.07))
                Circle().stroke(.black, lineWidth: d * 0.07)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.5), radius: 6)
        }
    }
}

/// The coin: the two Pokémon on its faces when it decides who starts, a Poké Ball (heads) and a plain face (tails) in attacks.
struct CoinView: View, Animatable {
    var angle: Double
    let pokemon: Bool
    let front: Int?
    let back: Int?
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    var body: some View {
        let a = angle.truncatingRemainder(dividingBy: 360)
        let showFront = a < 90 || a >= 270
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.35), Color(red: 0.88, green: 0.62, blue: 0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Color(red: 0.72, green: 0.5, blue: 0.08), lineWidth: 9)
            if pokemon { SpriteView(dex: showFront ? front : back, box: 120) }
            else if showFront { Pokeball().frame(width: 96, height: 96) }
            else { Circle().strokeBorder(.white.opacity(0.8), lineWidth: 10).frame(width: 80, height: 80) }
        }
        .frame(width: 180, height: 180)
        .scaleEffect(x: 1, y: showFront ? 1 : -1)
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
        .shadow(color: .black.opacity(0.4), radius: 12)
    }
}

/// A card shown big over its half (tap anywhere to put it back).
struct Zoom: View {
    let game: Game
    let side: Int
    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
            if let c = game.sides[side].card { CardSlot(card: c, lang: game.lang).frame(width: 395, height: 550) }
        }
        .contentShape(Rectangle())
        .onTapGesture { game.read(side) }
        .transition(.opacity)
    }
}
