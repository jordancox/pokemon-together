import SwiftUI
import UIKit

// The decks mode on the board (Deck.swift): the parent's half says each step and why, with the buttons; the child's
// half has his job in pictures, numbers and single words. Both drawn at halfSize, like the battle.

struct DeckView: View {
    let game: Game
    let side: Int
    var body: some View {
        Group {
            if side == parentSide { DeckGuide(game: game) } else { DeckJob(game: game) }
        }
        .frame(width: halfSize.width, height: halfSize.height)
        .foregroundStyle(.white)
    }
}

/// The parent's half: whose deck and which step, what to do and why, what to sort out (yellow), and BACK / ADD CARDS /
/// NEXT. Calm: nothing moves.
struct DeckGuide: View {
    let game: Game
    @State private var asking = false
    var body: some View {
        let l = game.lang, d = game.deck, s = game.building
        VStack(alignment: .leading, spacing: 12) {
            Text(Say.deckHeading(l, s, d.step)).font(.system(size: 18, weight: .heavy, design: .rounded)).opacity(0.6)
            Text(Say.deckStep(l, d, s))
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Shake(t: d.step == 1 ? CGFloat(game.nudge) : 0))
            if d.step == 1 { types(d) }
            if d.step == 5 { rules(d) }
            ForEach(Array(d.tips(d.step).prefix(3).enumerated()), id: \.offset) { _, tip in
                Text("• " + Say.tip(l, tip))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                pill(Say.backWord(l), strong: false) { game.deckBack() }
                if d.step == 1 && d.started { pill(Say.startAgainWord(l), strong: false) { asking = true } }
                Spacer()
                if d.step == 2 || d.step == 3 { pill(Say.addCardsWord(l), strong: true) { game.openAdding(deck: s) } }
                pill(d.step == Deck.steps ? Say.doneWord(l) : Say.nextWord(l), strong: true) { game.deckForward() }
            }
        }
        // the top clear of the middle strip, whose Poké Ball reaches over both halves
        .padding(.horizontal, 28).padding(.top, 40).padding(.bottom, 18)
        .confirmationDialog(Say.startAgainAsk(l), isPresented: $asking, titleVisibility: .visible) {
            Button(Say.startAgainYes(l), role: .destructive) { game.clearDeck() }
        }
    }

    /// Step 1: the types, small, so the parent can choose too (for their own deck).
    private func types(_ d: Deck) -> some View {
        HStack(spacing: 14) {
            ForEach(Deck.types, id: \.self) { t in
                Button { game.chooseType(t) } label: {
                    EnergyIcon(type: t, size: 54)
                        .overlay(Circle().strokeBorder(.white, lineWidth: d.type == t ? 4 : 0).padding(-6))
                        .opacity(d.type == nil || d.type == t ? 1 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    /// Step 5: the real rules, each ticked or crossed.
    private func rules(_ d: Deck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(Say.deckRules(game.lang, d).enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: r.0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(r.0 ? Color.green : .yellow)
                    Text(r.1).fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            }
        }
    }

    private func pill(_ word: String, strong: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(word)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 22)
                .frame(height: 54)
                .background(Capsule().fill(.white.opacity(strong ? 1 : 0.6)))
        }
        .buttonStyle(.plain)
    }
}

/// The child's half: his job at this step, in pictures and one word. 1: the type symbols to tap. 2: his Pokémon in
/// families, a gap where one is missing. 3: the Trainers. 4: the Energy cards to count out. 5: 60, ready.
struct DeckJob: View {
    let game: Game
    var body: some View {
        let d = game.deck, l = game.lang
        switch d.step {
        case 1:
            VStack(spacing: 26) {
                Text(d.type.map { Kind.name($0, l).uppercased() } ?? Say.whichWord(l))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 26), count: 4), spacing: 22) {
                    ForEach(Deck.types, id: \.self) { t in
                        Button { game.chooseType(t) } label: {
                            EnergyIcon(type: t, size: 130)
                                .overlay(Circle().strokeBorder(.white, lineWidth: d.type == t ? 8 : 0).padding(-10))
                                .opacity(d.type == nil || d.type == t ? 1 : 0.35)
                                .scaleEffect(d.type == t ? 1.08 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case 2: // in the middle of his half: columns only as many as the families, so a few sit centred
            let families = d.families()
            VStack(spacing: 22) {
                Counter(icon: d.type, word: "POKÉMON", n: d.pokemonCount, of: 20)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(256), spacing: 12), count: min(3, max(1, families.count))), spacing: 12) {
                    ForEach(families) { f in FamilyRow(family: f) }
                }
            }
        case 3:
            VStack(spacing: 22) {
                Counter(icon: nil, word: Say.trainersWord(l), n: d.trainerCount, of: 20)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(68), spacing: 8), count: min(10, max(1, d.trainers.count))), spacing: 12) {
                    ForEach(d.trainers, id: \.card.id) { e in
                        TrainerPicture(t: e.card, lang: l).frame(width: 68, height: 95)
                            .overlay(alignment: .bottomTrailing) { if e.n > 1 { Copies(n: e.n) } }
                    }
                }
            }
        case 4:
            VStack(spacing: 24) {
                Text(Say.energyWord(l)).font(.system(size: 64, weight: .black, design: .rounded))
                HStack(spacing: 50) {
                    ForEach(d.energyCards()) { e in
                        VStack(spacing: 10) {
                            EnergyIcon(type: e.type, size: 150)
                            Text("\(e.n)").font(.system(size: 96, weight: .black, design: .rounded))
                        }
                    }
                }
            }
        default:
            if d.meetsRules {
                ZStack {
                    Confetti()
                    VStack(spacing: 6) {
                        Text("60").font(.system(size: 170, weight: .black, design: .rounded))
                        Text(Say.readyBang(l)).font(.system(size: 76, weight: .black, design: .rounded))
                    }
                    .shadow(color: .black.opacity(0.4), radius: 4)
                }
            } else {
                VStack(spacing: 6) {
                    Text("\(d.total)").font(.system(size: 170, weight: .black, design: .rounded))
                    Text(Say.almostWord(l)).font(.system(size: 76, weight: .black, design: .rounded))
                }
            }
        }
    }
}

/// A big count on the child's half: the Energy symbol of the deck's type (or a card), the word, and so many of about 20.
struct Counter: View {
    let icon: String?
    let word: String
    let n: Int
    let of: Int
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 16) {
            if let icon { EnergyIcon(type: icon, size: 64).alignmentGuide(.lastTextBaseline) { $0[.bottom] - 8 } }
            Text(word).font(.system(size: 46, weight: .black, design: .rounded))
            Text("\(n)").font(.system(size: 84, weight: .black, design: .rounded)).contentTransition(.numericText())
            Text("/ \(of)").font(.system(size: 36, weight: .heavy, design: .rounded)).opacity(0.6)
        }
    }
}

/// One family on the child's half: its Pokémon in order, joined by arrows; a missing one is a dashed circle with a ?
/// and its sprite in grey, to look for.
struct FamilyRow: View {
    let family: Family
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(family.slots.enumerated()), id: \.offset) { i, slot in
                if i > 0 { Image(systemName: "arrow.right").font(.system(size: 18, weight: .heavy)).opacity(0.7) }
                switch slot {
                case .have(let c, let n):
                    SpriteView(dex: c.dex, box: 58, still: true).frame(width: 60, height: 60)
                        .overlay(alignment: .bottomTrailing) { if n > 1 { Copies(n: n) } }
                case .gap(_, let dex):
                    ZStack {
                        Circle().strokeBorder(.yellow, style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                        SpriteView(dex: dex, box: 44, still: true).saturation(0).opacity(0.45)
                        Text("?").font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(.yellow)
                    }
                    .frame(width: 60, height: 60)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.22)))
    }
}

/// "×3" on a card or sprite that's in the deck more than once.
struct Copies: View {
    let n: Int
    var body: some View {
        Text("×\(n)")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(.black.opacity(0.7)))
            .offset(x: 6, y: 4)
    }
}

/// A Trainer card's picture, or its name on a plain card while the picture is missing.
struct TrainerPicture: View {
    let t: Trainer
    let lang: Lang
    var body: some View {
        if let ui = Art.picture(t.img, lang) {
            Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.85))
                .overlay(Text(t.name(lang)).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.black).padding(3))
        }
    }
}

/// The add screen for a deck: its Pokémon and Trainers, each with − and + for how many copies.
struct DeckList: View {
    let game: Game
    let side: Int
    let tell: (String) -> Void
    private var phone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    var body: some View {
        let l = game.lang, d = game.decks[side]
        VStack(alignment: .leading, spacing: 8) {
            Text(Say.deckCount(l, d.pokemonCount, d.trainerCount)).font(.system(size: 20, weight: .semibold, design: .rounded))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: phone ? 3 : 6), spacing: 10) {
                    ForEach(d.pokemon, id: \.card.id) { e in
                        item(e.card.id, e.card.name(l), e.n) { SpriteView(dex: e.card.dex, box: 64, still: true).frame(height: 70) }
                    }
                    ForEach(d.trainers, id: \.card.id) { e in
                        item(e.card.id, e.card.name(l), e.n) { TrainerPicture(t: e.card, lang: l).frame(width: 50, height: 70) }
                    }
                }
            }
        }
    }

    private func item<P: View>(_ id: String, _ name: String, _ n: Int, @ViewBuilder picture: () -> P) -> some View {
        VStack(spacing: 4) {
            picture()
            Text(name).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                Button { if let m = game.deckChange(id, by: -1, in: side) { tell(m) } } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 30)).foregroundStyle(.gray)
                }
                Text("\(n)").font(.system(size: 22, weight: .black, design: .rounded)).frame(minWidth: 26)
                Button { if let m = game.deckChange(id, by: 1, in: side) { tell(m) } } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundStyle(.gray)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.94)))
    }
}

/// The start screen's modes, at the top of the parent's half: the practice levels, or the decks.
struct ModeTabs: View {
    let game: Game
    var body: some View {
        HStack(spacing: 10) {
            tab(.practice, Say.learnWord(game.lang))
            tab(.decks, Say.decksWord(game.lang))
            Spacer()
        }
    }

    private func tab(_ m: Mode, _ word: String) -> some View {
        let on = game.mode == m
        return Button { game.setMode(m) } label: {
            Text(word)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(on ? Color.black : .white)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(Capsule().fill(.white.opacity(on ? 1 : 0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// The decks mode on the start screen's parent half: his deck and yours, how far each has got, and what this is for.
struct DecksPanel: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([childSide, parentSide], id: \.self) { s in row(s) }
            Spacer(minLength: 4)
            Text(Say.decksIntro(game.lang, his: game.decks[childSide].ready, yours: game.decks[parentSide].ready))
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ s: Int) -> some View {
        let l = game.lang, d = game.decks[s]
        return HStack(spacing: 14) {
            Text(Say.deckOwner(l, s)).font(.system(size: 22, weight: .heavy, design: .rounded)).frame(width: 200, alignment: .leading)
            if let t = d.type { EnergyIcon(type: t, size: 38) }
            Text(Say.deckStatus(l, d)).font(.system(size: 18, weight: .medium, design: .rounded)).opacity(0.8).lineLimit(2)
            Spacer(minLength: 8)
            Button { game.openDeck(s) } label: {
                Text(d.ready ? Say.changeWord(l) : d.started ? Say.continueWord(l) : Say.buildWord(l))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
    }
}
