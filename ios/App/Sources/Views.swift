import SwiftUI
import UIKit

// One player's half, in its three moments: the start (then this player's Pokémon), the battle, and the end. All drawn at halfSize, with the
// player at the bottom edge and the middle of the table at the top.

/// The two halves (Jordan, 18 Oct 2026): the parent's at the bottom, calm, with the instructions written out to read and
/// pass on; the child's at the top, turned to face him, with pictures, numbers and single words only ("reading on his
/// side upside down is impossible"). The voice is off unless switched on: the parent does the talking.
let parentSide = 0, childSide = 1

/// Before a battle. The parent's half: the level, then what to tap; once the Poké Ball has chosen, both Pokémon to find
/// and the Energy cards to put next to each. The child's half: READY?, then his Pokémon, big.
struct StartView: View {
    let game: Game
    let side: Int
    var body: some View {
        Group {
            if side == parentSide {
                if game.sides[childSide].card != nil { parentChosen } else { parentIntro }
            } else if let c = game.sides[side].card {
                VStack(spacing: 14) {
                    CardSlot(card: c, lang: game.lang).frame(width: 300, height: 419).onTapGesture { game.read(side) }
                    Text(c.name(game.lang).uppercased()).font(.system(size: 56, weight: .black, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            } else {
                VStack(spacing: 24) {
                    Pokeball().frame(width: 190, height: 190)
                    Text(Say.readyWord(game.lang)).font(.system(size: 80, weight: .black, design: .rounded))
                }
            }
        }
        .frame(width: halfSize.width, height: halfSize.height)
        .foregroundStyle(.white)
    }

    private var parentIntro: some View {
        let l = game.lang
        return VStack(alignment: .leading, spacing: 6) {
            Text(Say.chooseLevel(l)).font(.system(size: 20, weight: .heavy, design: .rounded)).opacity(0.6)
            ForEach(1...Say.levels, id: \.self) { n in
                Button { game.setLevel(n) } label: { LevelRow(n: n, lang: l, on: game.level == n) }.buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            Text(game.levelNote ?? Say.start(l, game.cards.count))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(game.levelNote == nil ? Color.white : .yellow)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
    }

    private var parentChosen: some View {
        let l = game.lang
        return VStack(alignment: .leading, spacing: 16) {
            ForEach([childSide, parentSide], id: \.self) { s in
                if let c = game.sides[s].card {
                    HStack(spacing: 20) {
                        CardSlot(card: c, lang: l).frame(width: 110, height: 153).onTapGesture { game.read(s) }
                        VStack(alignment: .leading, spacing: 10) {
                            Text((s == childSide ? Say.his(l) : Say.yours(l)) + ": " + c.name(l).uppercased())
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                            HStack(spacing: 8) {
                                ForEach(Array(game.energyFor(c).enumerated()), id: \.offset) { _, t in EnergyIcon(type: t, size: 44) }
                            }
                        }
                    }
                }
            }
            Text(Say.setUp(l)).font(.system(size: 24, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A level on the parent's half: built, or not yet.
struct LevelRow: View {
    let n: Int
    let lang: Lang
    let on: Bool
    var body: some View {
        let words = Say.level(lang, n)
        HStack(spacing: 12) {
            Text("\(n)").font(.system(size: 20, weight: .black, design: .rounded))
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(on ? 0.3 : 0.1)))
            Text(words.0).font(.system(size: 21, weight: .heavy, design: .rounded))
            Text(words.1 + (n == 1 ? "" : " · " + Say.notBuilt(lang)))
                .font(.system(size: 17, weight: .medium, design: .rounded)).opacity(0.7)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if on { Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)) }
        }
        .padding(.horizontal, 10).frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(on ? 0.16 : 0.04)))
        .opacity(n == 1 ? 1 : 0.5)
    }
}

/// What to do now, at the top of a half: next to the middle of the table, where the buttons are.
struct Hint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 28).padding(.vertical, 12)
            .background(Capsule().fill(.black.opacity(0.35)))
            .padding(.horizontal, 30)
    }
}

struct BattleView: View {
    let game: Game
    let side: Int
    var body: some View {
        let me = game.sides[side]
        let mine = game.step == .battle && game.turn == side
        let isParent = side == parentSide
        let arena: CGFloat = isParent ? 120 : 220
        VStack(spacing: 0) {
            // the parent's half: what's happening and what to do, written out to read and pass on
            if isParent { Captions(lines: game.captions).frame(height: 100) }
            // By the middle of the table: HP, the Pokémon, its Energy
            HStack(spacing: 0) {
                HPView(hp: me.hp, full: me.card?.hp ?? 0).frame(width: 250)
                ZStack(alignment: .bottom) { // the Pokémon stands on its shadow
                    Ellipse().fill(.black.opacity(0.22)).frame(width: 160, height: 30)
                    SpriteView(dex: me.card?.dex, box: arena - 50)
                        .padding(.bottom, 14)
                        .modifier(Shake(t: CGFloat(game.shakes[side])))
                        .offset(y: game.lunge == side ? -60 : 0)
                }
                .frame(width: 320, height: arena, alignment: .bottom)
                .overlay(alignment: .top) {
                    if let p = game.pop, p.side == side {
                        Text(p.text)
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(p.text.hasPrefix("+") ? Color.green : .white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                            .id(p.id)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                EnergyRow(types: me.energy).frame(width: 244)
            }
            .frame(height: arena)
            // By the player: the card, and what to do
            HStack(alignment: .top, spacing: 18) {
                CardSlot(card: me.card, lang: game.lang)
                    .frame(width: 240, height: 335)
                    .overlay(alignment: .topTrailing) { if me.damage > 0 { DamageBadge(n: me.damage) } }
                    .onTapGesture { game.read(side) }
                Controls(game: game, side: side, calm: isParent)
                    .opacity(mine ? 1 : 0.45)
            }
            .padding(.horizontal, 24)
            .frame(height: 355, alignment: .top)
        }
        .frame(width: halfSize.width, height: halfSize.height)
        .overlay {
            if game.banner == side && !isParent {
                Text(Say.yourTurn(game.lang))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 44).padding(.vertical, 18)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The three things to do on a turn, top to bottom: the Energy, an attack, DONE.
struct Controls: View {
    let game: Game
    let side: Int
    var calm = false // the parent's: nothing pulses
    var body: some View {
        let me = game.sides[side]
        let mine = game.step == .battle && game.turn == side
        let moves = me.card?.moves ?? []
        VStack(spacing: 10) {
            Button { Task { await game.giveEnergy(side) } } label: {
                HStack(spacing: 14) {
                    EnergyIcon(type: game.nextEnergy(side), size: 62)
                    Text(Say.energyWord(game.lang)).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.black)
                    Spacer()
                    if me.gaveEnergy {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 82)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(mine && !me.gaveEnergy ? 1 : 0.7)))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(mine && !me.gaveEnergy ? Color.yellow : .clear, lineWidth: 6))
            }
            .modifier(Pulse(on: !calm && mine && !me.gaveEnergy))
            ForEach(Array(moves.enumerated()), id: \.offset) { i, a in
                Button { Task { await game.attack(side, i) } } label: {
                    AttackRow(attack: a, lang: game.lang, height: moves.count > 2 ? 62 : 78,
                              ready: mine && me.gaveEnergy && game.turns > 0 && !me.locked && game.canPay(a.cost, me.energy))
                }
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button { Task { await game.done(side) } } label: {
                    Text(Say.doneWord(game.lang))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 34)
                        .frame(height: 58)
                        .background(Capsule().fill(.white.opacity(mine && me.gaveEnergy ? 1 : 0.6)))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 528, height: 335)
    }
}

struct AttackRow: View {
    let attack: Attack
    let lang: Lang
    let height: CGFloat
    let ready: Bool
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                ForEach(Array(attack.cost.enumerated()), id: \.offset) { _, t in EnergyIcon(type: t, size: 36) }
            }
            .frame(minWidth: 64, alignment: .leading)
            Text(attack.name(lang).uppercased())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(.black)
            Spacer(minLength: 4)
            Text(attack.label)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(ready ? 1 : 0.6)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ready ? Color.yellow : .clear, lineWidth: 6))
    }
}

struct OverView: View {
    let game: Game
    let side: Int
    var body: some View {
        let won = game.winner == side
        if side == parentSide {
            VStack(spacing: 24) {
                Hint(text: Say.tapBallAgain(game.lang)).padding(.top, 22)
                Spacer()
                Text(Say.wins(game.lang, game.name(game.winner ?? 0)))
                    .font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
            .frame(width: halfSize.width, height: halfSize.height)
        } else {
            child(won)
        }
    }

    private func child(_ won: Bool) -> some View {
        ZStack {
            if won { Confetti() }
            VStack(spacing: 20) {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    SpriteView(dex: game.sides[side].card?.dex, box: 240)
                        .offset(y: won ? -abs(sin(t * 4)) * 40 : 30)
                        .rotationEffect(.degrees(won ? 0 : 90))
                        .saturation(won ? 1 : 0.2)
                }
                .frame(height: 280)
                Text(won ? Say.youWin(game.lang) : Say.goodGame(game.lang))
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
        }
        .frame(width: halfSize.width, height: halfSize.height)
    }
}

/// The parent's half: the last two lines of the game, the newest in full, to read and pass on.
struct Captions: View {
    let lines: [Caption]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if lines.count > 1 {
                Text(lines[lines.count - 2].text)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            if let c = lines.last {
                Text(c.text)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3).minimumScaleFactor(0.6)
                    .id(c.id)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .background(Color.black.opacity(0.35))
    }
}

struct HPView: View {
    let hp: Int
    let full: Int
    var body: some View {
        let f = full > 0 ? CGFloat(hp) / CGFloat(full) : 0
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").foregroundStyle(Color(red: 0.9, green: 0.15, blue: 0.2))
                Text("\(hp)").contentTransition(.numericText()).foregroundStyle(.white)
            }
            .font(.system(size: 56, weight: .black, design: .rounded))
            .shadow(color: .black.opacity(0.35), radius: 3)
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.3))
                Capsule().fill(f > 0.5 ? Color.green : f > 0.25 ? .yellow : .red).frame(width: 190 * f)
            }
            .frame(width: 190, height: 20)
        }
    }
}

struct EnergyRow: View {
    let types: [String]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 6), count: 4), spacing: 6) {
            ForEach(Array(types.prefix(12).enumerated()), id: \.offset) { _, t in
                EnergyIcon(type: t, size: 46).transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(width: 214)
    }
}

struct EnergyIcon: View {
    let type: String
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(Kind.color(type))
            Circle().strokeBorder(.white, lineWidth: size * 0.08)
            Image(systemName: Kind.symbol(type)).font(.system(size: size * 0.46, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

struct DamageBadge: View {
    let n: Int
    var body: some View {
        Text("\(n)")
            .font(.system(size: 30, weight: .black, design: .rounded))
            .contentTransition(.numericText())
            .foregroundStyle(.white)
            .frame(width: 66, height: 66)
            .background(Circle().fill(Color(red: 0.86, green: 0.2, blue: 0.15)))
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .offset(x: 14, y: -14)
    }
}

/// The card as printed, or a stand-in when its picture is missing, or an empty slot.
struct CardSlot: View {
    let card: Card?
    let lang: Lang
    var body: some View {
        Group {
            if let card, let ui = Art.card(card, lang) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
            } else if let card {
                RoundedRectangle(cornerRadius: 16).fill(.white)
                    .overlay {
                        VStack(spacing: 10) {
                            SpriteView(dex: card.dex, box: 130)
                            Text(card.name(lang).uppercased()).font(.system(size: 26, weight: .black, design: .rounded))
                            Text("\(card.hp)").font(.system(size: 40, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.black)
                    }
            } else {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 4, dash: [12, 8]))
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

/// The Pokémon's sprite, at three screen points per sprite pixel (so a Snorlax stays bigger than a Pikachu), within `box`.
struct SpriteView: View {
    let dex: Int?
    var box: CGFloat = 180
    var still = false // the first frame only, where a screen of moving Pokémon would be too much (the add screen)
    var body: some View {
        if let img = Art.sprite(dex) {
            let s = min(box / max(img.size.width, img.size.height, 1), 3.2)
            AnimatedImage(image: still ? img.images?.first ?? img : img).frame(width: img.size.width * s, height: img.size.height * s)
        } else {
            Pokeball().frame(width: box * 0.6, height: box * 0.6)
        }
    }
}

/// UIImageView plays the GIF's frames and keeps the pixels sharp.
struct AnimatedImage: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.layer.magnificationFilter = .nearest
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            v.setContentHuggingPriority(.defaultLow, for: axis)
            v.setContentCompressionResistancePriority(.defaultLow, for: axis)
        }
        return v
    }
    func updateUIView(_ v: UIImageView, context: Context) {
        if v.image !== image { v.image = image }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

struct Confetti: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let colors: [Color] = [.yellow, .red, .blue, .green, .orange, .pink, .white]
                for i in 0..<70 {
                    let seed = Double(i) * 12.9898
                    let x = abs((sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)) * size.width
                    let speed = 70 + Double(i % 7) * 20
                    let y = (t * speed + Double(i) * 37).truncatingRemainder(dividingBy: size.height + 40) - 20
                    let r = CGRect(x: x + sin(t * 3 + seed) * 12, y: y, width: 10, height: 16)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
