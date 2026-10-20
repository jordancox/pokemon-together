// Everything the app says, and the few words on screen (in capitals, like his school books). Italian first.
// They play with the real cards on the table: the voice says what to do with them, explains each part of a card the
// first time it matters (the "Teach" lines, once each time the app opens), and keeps count of the damage.
enum Say {
    private static func t(_ l: Lang, _ it: String, _ en: String) -> String { l == .it ? it : en }

    // On screen
    static func energyWord(_ l: Lang) -> String { t(l, "ENERGIA", "ENERGY") }
    static func doneWord(_ l: Lang) -> String { t(l, "FINE", "DONE") }
    static func yourTurn(_ l: Lang) -> String { t(l, "TOCCA A TE!", "YOUR TURN!") }
    static func youWin(_ l: Lang) -> String { t(l, "HAI VINTO!", "YOU WIN!") }
    static func goodGame(_ l: Lang) -> String { t(l, "BRAVO!", "WELL PLAYED!") }
    // The start (Jordan, 18 Oct 2026, on build 20's card grid on both halves: "I'm 45 and can't parse what this is").
    // The child's half: one word. The parent's: the level, and what to do.
    static func readyWord(_ l: Lang) -> String { t(l, "PRONTO?", "READY?") }
    static func whoWord(_ l: Lang) -> String { t(l, "CHI?", "WHO?") }
    /// The retreat button: not the card's word, which in Italian is also Squirtle's attack (Withdraw, "Ritirata")
    static func retreatWord(_ l: Lang) -> String { t(l, "CAMBIA", "SWAP") }
    static func chooseLevel(_ l: Lang) -> String { t(l, "LIVELLO", "LEVEL") }
    /// The levels, laddered up by hand as you learn (Jordan, 18 Oct: "Practice battle… up to like level 5? level 10? I
    /// don't know how many steps till we master it"). Each adds one thing from the real game; 8 is all of it.
    static let levels = 8
    static let built = 3 // 1 Practice battle, 2 Team, 3 Retreat
    static func level(_ l: Lang, _ n: Int) -> (String, String) {
        switch n {
        case 1: return (t(l, "Battaglia di prova", "Practice battle"), t(l, "un Pokémon a testa: Energia e attacchi", "one Pokémon each: Energy and attacks"))
        case 2: return (t(l, "Squadra", "Team"), t(l, "tre Pokémon a testa: quando uno va KO, entra il prossimo", "three Pokémon each: when one is knocked out, the next comes in"))
        case 3: return (t(l, "Ritirata", "Retreat"), t(l, "cambiare il Pokémon che combatte", "swap the Pokémon that's fighting"))
        case 4: return (t(l, "Evoluzioni", "Evolution"), t(l, "i Pokémon crescono durante la partita", "Pokémon evolve during the game"))
        case 5: return (t(l, "La mano", "Your hand"), t(l, "un mazzo a testa: si pesca e si giocano le carte", "a deck each: draw and play cards"))
        case 6: return (t(l, "Carte premio", "Prize cards"), t(l, "il modo vero di vincere", "the real way to win"))
        case 7: return (t(l, "Allenatori", "Trainers"), t(l, "strumenti e aiutanti", "items and helpers"))
        default: return (t(l, "Partita vera", "Full game"), t(l, "stati speciali, abilità: tutte le regole", "special conditions, abilities: all the rules"))
        }
    }
    static func notBuilt(_ l: Lang) -> String { t(l, "non ancora pronto", "not built yet") }
    static func levelSoon(_ l: Lang) -> String {
        t(l, "Questo livello non è ancora pronto: per ora, i livelli da 1 a 3.", "That level isn't built yet: for now, levels 1 to 3.")
    }
    static func his(_ l: Lang) -> String { t(l, "IL SUO", "HIS") }
    static func yours(_ l: Lang) -> String { t(l, "IL TUO", "YOURS") }
    static func setUp(_ l: Lang) -> String {
        t(l, "Trovate le due carte. Ognuno mette la sua davanti a sé, con accanto le carte Energia qui sopra (quelle con un solo grande simbolo; se non le avete, vanno bene dei gettoni). Poi toccate la Poké Ball.",
          "Find both cards. Each of you puts yours in front of you, with the Energy cards shown here next to it (the ones with one big symbol; coins will do if you don't have them). Then tap the Poké Ball.")
    }
    /// From level 2: where the cards go on the table, shown under the two teams.
    static func setUpTeam(_ l: Lang) -> String {
        t(l, "La carta grande va davanti a voi: è il Pokémon che combatte. Le altre vanno dietro, in fila: è la panchina, dove aspettano il loro turno. Accanto mettete le carte Energia qui sopra (se non le avete, vanno bene dei gettoni). Poi toccate la Poké Ball.",
          "The big card goes in front of you: that Pokémon fights. The others go in a row behind it: that's the bench, where they wait their turn. Next to them, put the Energy cards shown here (coins will do if you don't have them). Then tap the Poké Ball.")
    }
    /// Choosing who comes in from the bench, on the parent's half.
    static func tapWho(_ l: Lang) -> String { t(l, "Tocca il Pokémon che entra", "Tap the Pokémon that comes in") }
    /// Under a card on the add screen that can't battle.
    static func cantBattle(_ l: Lang) -> String { t(l, "non può combattere", "can't battle") }
    static func tapBallAgain(_ l: Lang) -> String { t(l, "↑  TOCCA LA POKÉ BALL PER RIGIOCARE", "↑  TAP THE POKÉ BALL TO PLAY AGAIN") }
    static func cardsWord(_ l: Lang) -> String { t(l, "CARTE", "CARDS") }

    // Spoken
    static func voiceOn(_ l: Lang) -> String { t(l, "Eccomi!", "I'm back!") }
    static func language(_ l: Lang) -> String { t(l, "Italiano!", "English!") }
    /// What this level is and what to do first; `size` is how many Pokémon each player gets. The app chooses the
    /// Pokémon (the Poké Ball), so nobody needs to know which cards are good.
    static func start(_ l: Lang, _ level: Int, _ size: Int) -> String {
        let n = size == 2 ? t(l, "Due", "Two") : t(l, "Tre", "Three")
        switch level {
        case 1: return t(l, "Battaglia di prova! Un Pokémon a testa. A turno, si mette un'Energia e si attacca. Vince chi manda KO l'altro Pokémon. Toccate la Poké Ball: scelgo io un Pokémon per ognuno.",
                         "Practice battle! One Pokémon each. Take turns: put on an Energy card, then attack. Knock out the other Pokémon to win. Tap the Poké Ball and I'll choose a Pokémon for each of you.")
        case 2: return t(l, "Squadra! \(n) Pokémon a testa. Ne combatte uno alla volta: gli altri aspettano dietro, in panchina. Quando uno va KO, entra il prossimo. Vince chi manda KO tutta la squadra dell'altro. Toccate la Poké Ball: scelgo io una squadra per ognuno.",
                         "Team! \(n) Pokémon each. One fights at a time; the others wait behind it, on the bench. When one is knocked out, the next comes in. Knock out the other's whole team to win. Tap the Poké Ball and I'll choose a team for each of you.")
        default: return t(l, "Ritirata! Squadre di \(n.lowercased()) Pokémon, come nel livello 2. In più, nel tuo turno puoi ritirare il Pokémon che combatte (CAMBIA): torna in panchina ed entra un altro. Costa Energia. Toccate la Poké Ball: scelgo io una squadra per ognuno.",
                          "Retreat! Teams of \(n.lowercased()) Pokémon, as in level 2. And now, on your turn, you can retreat the Pokémon that's fighting (SWAP): it goes back to the bench and another comes in. It costs Energy. Tap the Poké Ball and I'll choose a team for each of you.")
        }
    }
    /// Why the Poké Ball can't start a battle yet, in plain words: how many cards it needs, how many of yours can battle,
    /// which can't, and what to do (Jordan, 20 Oct 2026: "it's not clear why the battle won't start sometimes").
    static func cantStart(_ l: Lang, level: Int, can: Int, need: Int, added: Int, out: [String]) -> String {
        guard added > 0 else { return t(l, "Prima aggiungete le vostre carte Pokémon: toccate CARTE, in mezzo.", "First, add your Pokémon cards: tap CARDS, in the middle.") }
        var s = level == 1 ? t(l, "Per giocare serve un Pokémon a testa: almeno 2.", "You need one Pokémon each: at least 2.")
            : t(l, "Questo livello vuole almeno 2 Pokémon a testa: 4 in tutto.", "This level needs at least 2 Pokémon each: 4 in all.")
        s += " " + (can == 0 ? t(l, "Nessuno dei vostri può combattere.", "None of yours can battle.")
            : can == 1 ? t(l, "Ne avete 1 che può combattere.", "You have 1 that can battle.")
            : t(l, "Ne avete \(can) che possono combattere.", "You have \(can) that can battle."))
        if !out.isEmpty {
            let names = list(l, out.count > 4 ? Array(out.prefix(4)) + ["…"] : out)
            s += " " + (out.count == 1 ? t(l, "\(names) non può ancora combattere: l'app non sa giocare i suoi attacchi.", "\(names) can't battle yet: the app can't play its attacks.")
                : t(l, "\(names) non possono ancora combattere: l'app non sa giocare i loro attacchi.", "\(names) can't battle yet: the app can't play their attacks."))
        }
        s += " " + t(l, "Aggiungete altre carte con CARTE", "Add more with CARDS")
        if level > 1 && can >= 2 { s += t(l, ", oppure giocate al livello 1", ", or play level 1") }
        return s + "."
    }
    /// "A, B e C" / "A, B and C"
    static func list(_ l: Lang, _ words: [String]) -> String {
        words.count < 2 ? words.joined() : words.dropLast().joined(separator: ", ") + t(l, " e ", " and ") + words.last!
    }
    /// One of your cards that can't battle, said when it's added.
    static func notYet(_ l: Lang, _ c: Card) -> String {
        let n = c.name(l)
        return t(l, "\(n) non può ancora combattere: l'app non sa giocare i suoi attacchi.", "\(n) can't battle yet: the app can't play its attacks.")
    }
    static func chosen(_ l: Lang, _ a: String, _ b: String) -> String {
        t(l, "\(a) contro \(b)! Ognuno cerca la carta che vede sulla sua metà dello schermo e la mette davanti a sé.",
          "\(a) against \(b)! Each of you, find the card on your half of the screen and put it in front of you.")
    }
    static func chosenTeam(_ l: Lang) -> String {
        t(l, "Ecco le squadre! Ognuno cerca le carte che vede sulla sua metà dello schermo.", "Here are the teams! Each of you, find the cards on your half of the screen.")
    }
    static func ready(_ l: Lang) -> String {
        t(l, "Accanto mettete le carte Energia che vedete: sono quelle con un solo grande simbolo. Se non le avete, vanno bene dei gettoni. Pronti? Toccate la Poké Ball!",
          "Next to it, put the Energy cards you see: they're the ones with just one big symbol. No Energy cards? Coins will do. Ready? Tap the Poké Ball!")
    }
    /// "un'Energia Lampo" / "a Lightning Energy card"; any Energy for a Colorless cost
    static func energyCard(_ l: Lang, _ type: String) -> String {
        type == "Colorless" ? t(l, "un'Energia qualsiasi", "any Energy card") : t(l, "un'Energia \(Kind.name(type, l))", "a \(type) Energy card")
    }
    /// How to spot that Energy card in the pile: its colour, and the first time its symbol too.
    static func energyLook(_ l: Lang, _ type: String, long: Bool) -> String? {
        let looks: [String: (String, String, String, String)] = [
            "Grass": ("quella verde", "con una foglia", "the green one", "with a leaf"),
            "Fire": ("quella rossa", "con una fiamma", "the red one", "with a flame"),
            "Water": ("quella blu", "con una goccia", "the blue one", "with a drop of water"),
            "Lightning": ("quella gialla", "con un fulmine", "the yellow one", "with a lightning bolt"),
            "Psychic": ("quella viola", "con un occhio", "the purple one", "with an eye"),
            "Fighting": ("quella arancione", "con un pugno", "the orange one", "with a fist"),
            "Darkness": ("quella nera", "", "the black one", ""),
            "Metal": ("quella grigia", "", "the grey one", ""),
            "Fairy": ("quella rosa", "", "the pink one", ""),
        ]
        guard let k = looks[type] else { return nil }
        let (it, itMore, en, enMore) = k
        return long && !itMore.isEmpty ? t(l, "\(it), \(itMore)", "\(en), \(enMore)") : t(l, it, en)
    }
    static func flip(_ l: Lang) -> String { t(l, "Lancio la moneta per vedere chi comincia…", "Let's flip a coin to see who goes first…") }
    static func starts(_ l: Lang, _ n: String) -> String { t(l, "Comincia \(n)!", "\(n) goes first!") }
    static func turnFirst(_ l: Lang, _ n: String, _ type: String) -> String {
        let e = energyCard(l, type), look = energyLook(l, type, long: true).map { ": \($0)" } ?? ""
        return t(l, "Tocca a \(n)! A ogni turno puoi mettere una carta Energia sul tuo Pokémon: è il carburante degli attacchi. Metti \(e) sotto la carta di \(n)\(look). Poi tocca ENERGIA.",
                 "\(n)'s turn! Each turn you can put one Energy card on your Pokémon: Energy powers its attacks. Put \(e) under \(n)'s card\(look). Then tap ENERGY.")
    }
    static func turn(_ l: Lang, _ n: String, _ type: String) -> String {
        let e = energyCard(l, type), look = energyLook(l, type, long: false).map { ": \($0)" } ?? ""
        return t(l, "Tocca a \(n)! Metti \(e)\(look).", "\(n)'s turn! Put on \(e)\(look).")
    }
    static func allEnergy(_ l: Lang, _ n: String) -> String {
        t(l, "Tocca a \(n)! Ha già tutta l'Energia che serve: tocca un attacco.", "\(n)'s turn! It has all the Energy it needs: tap an attack.")
    }
    /// After a retreat, when the Pokémon that came in has no Energy yet this turn.
    static func putOn(_ l: Lang, _ n: String, _ type: String) -> String {
        let e = energyCard(l, type), look = energyLook(l, type, long: false).map { ": \($0)" } ?? ""
        return t(l, "Metti \(e) sotto la carta di \(n)\(look). Poi tocca ENERGIA.", "Put \(e) under \(n)'s card\(look). Then tap ENERGY.")
    }
    static func wait(_ l: Lang, _ n: String) -> String { t(l, "Aspetta! Ora tocca a \(n).", "Wait! It's \(n)'s turn.") }
    static func oneEnergy(_ l: Lang) -> String { t(l, "Solo un'Energia per turno!", "Only one Energy each turn!") }
    static func energyFirst(_ l: Lang) -> String { t(l, "Prima metti un'Energia e tocca ENERGIA!", "First put on an Energy card and tap ENERGY!") }
    static func firstTurnRule(_ l: Lang) -> String {
        t(l, "Chi comincia non può attaccare al primo turno. Tocca FINE.", "Whoever goes first can't attack on the very first turn. Tap DONE.")
    }
    static func canAttackFirst(_ l: Lang, _ n: String) -> String { t(l, "\(n) ha abbastanza Energia! Tocca un attacco.", "\(n) has enough Energy! Tap an attack.") }
    static func canAttack(_ l: Lang) -> String { t(l, "Attacca!", "Attack!") }
    static func notEnoughTeach(_ l: Lang, _ n: String, _ have: Int) -> String {
        t(l, "Ora guarda gli attacchi sulla carta. I cerchi colorati a sinistra di ogni attacco sono le Energie che servono. \(n) ne ha \(have): non basta ancora. Tocca FINE: le Energie restano lì per il prossimo turno.",
          "Now look at the attacks on the card. The coloured circles on the left of each attack are the Energy it needs. \(n) has \(have): not enough yet. Tap DONE: the Energy stays there for next turn.")
    }
    static func canAttackTeach(_ l: Lang, _ n: String) -> String {
        t(l, "Ora guarda gli attacchi sulla carta. I cerchi colorati a sinistra sono le Energie che servono, il numero a destra sono i danni. \(n) ha abbastanza Energia: tocca un attacco!",
          "Now look at the attacks on the card. The coloured circles on the left are the Energy it needs, the number on the right is the damage. \(n) has enough Energy: tap an attack!")
    }
    static func notEnough(_ l: Lang) -> String {
        t(l, "Non basta ancora. Tocca FINE: l'Energia resta per il prossimo turno.", "Not enough yet. Tap DONE: the Energy stays for next turn.")
    }
    static func needs(_ l: Lang, _ a: String, _ k: Int, _ have: Int) -> String {
        t(l, "\(a) ha bisogno di \(k) Energi\(k == 1 ? "a" : "e"). Ne hai \(have).", "\(a) needs \(k) Energy. You have \(have).")
    }
    static func locked(_ l: Lang, _ n: String) -> String { t(l, "\(n) questo turno non può attaccare. Tocca FINE.", "\(n) can't attack this turn. Tap DONE.") }
    static func uses(_ l: Lang, _ n: String, _ a: String) -> String { t(l, "\(n) usa \(a)!", "\(n) uses \(a)!") }
    static func heads(_ l: Lang) -> String { t(l, "Testa!", "Heads!") }
    static func tails(_ l: Lang) -> String { t(l, "Croce!", "Tails!") }
    static func damage(_ l: Lang, _ d: Int) -> String { t(l, "\(d) danni!", "\(d) damage!") }
    static func weakTeach(_ l: Lang, _ n: String, _ type: String, _ d: Int) -> String {
        t(l, "Debolezza! Guarda in basso sulla carta di \(n): c'è scritto debolezza, con il simbolo \(type). Gli attacchi \(type) gli fanno il doppio dei danni: \(d)!",
          "Weakness! Look at the bottom of \(n)'s card: it says weakness, with the \(type) symbol. \(type) attacks do double damage to it: \(d)!")
    }
    static func weak(_ l: Lang, _ n: String, _ type: String, _ d: Int) -> String {
        t(l, "Debolezza! \(n) teme il tipo \(type): danni doppi, \(d)!", "Weakness! \(n) is weak to \(type): double damage, \(d)!")
    }
    static func resisted(_ l: Lang, _ n: String, _ d: Int) -> String { t(l, "\(n) resiste: solo \(d) danni.", "\(n) resists: only \(d) damage.") }
    static func nothing(_ l: Lang) -> String { t(l, "Niente danni!", "No damage!") }
    static func leftTeach(_ l: Lang, _ n: String, _ full: Int, _ taken: Int, _ hp: Int) -> String {
        t(l, "\(n) aveva \(full) punti salute: è il numero grande in alto a destra sulla sua carta. Ha preso \(taken) danni, quindi gliene restano \(hp). A zero va KO. Non serve contare, il conto lo tengo io.",
          "\(n) had \(full) HP: that's the big number at the top right of its card. It has taken \(taken) damage, so it has \(hp) left. At zero it's knocked out. No need to count: I'll keep track.")
    }
    static func left(_ l: Lang, _ n: String, _ hp: Int) -> String { t(l, "A \(n) restano \(hp) punti salute.", "\(n) has \(hp) HP left.") }
    static func heal(_ l: Lang, _ n: String, _ d: Int) -> String { t(l, "\(n) si cura di \(d)!", "\(n) heals \(d)!") }
    static func extraEnergy(_ l: Lang, _ n: String) -> String { t(l, "Prendi un'altra carta Energia e mettila su \(n)!", "Take another Energy card and put it on \(n)!") }
    static func selfHit(_ l: Lang, _ n: String, _ d: Int) -> String { t(l, "Ahi! Anche \(n) si fa \(d) danni.", "Ouch! \(n) takes \(d) damage too.") }
    static func discard(_ l: Lang, _ n: String, _ k: Int) -> String {
        k == 1 ? t(l, "Togli una carta Energia da \(n).", "Take one Energy card off \(n).") : t(l, "Togli \(k) carte Energia da \(n).", "Take \(k) Energy cards off \(n).")
    }
    static func shieldUp(_ l: Lang, _ n: String) -> String { t(l, "\(n) si ripara: al prossimo turno niente danni!", "\(n) takes cover: no damage next turn!") }
    static func shielded(_ l: Lang, _ n: String) -> String { t(l, "\(n) è al riparo: niente danni!", "\(n) is under cover: no damage!") }
    static func braced(_ l: Lang, _ n: String, _ d: Int) -> String {
        t(l, "\(n) si fa duro: \(d) danni in meno al prossimo turno.", "\(n) toughens up: \(d) less damage next turn.")
    }
    static func toughened(_ l: Lang, _ n: String, _ d: Int) -> String {
        d > 0 ? t(l, "\(n) si è fatto duro: solo \(d) danni.", "\(n) toughened up: only \(d) damage.")
            : t(l, "\(n) si è fatto duro: niente danni!", "\(n) toughened up: no damage!")
    }
    static func restNext(_ l: Lang, _ n: String) -> String { t(l, "Al prossimo turno \(n) non potrà attaccare.", "\(n) can't attack next turn.") }
    static func foeLocked(_ l: Lang, _ n: String) -> String { t(l, "\(n) al prossimo turno non potrà attaccare!", "\(n) can't attack next turn!") }
    static func ko(_ l: Lang, _ n: String) -> String { t(l, "\(n) è KO! Mettete la sua carta da parte.", "\(n) is knocked out! Put its card aside.") }
    // The team (from level 2)
    static func koTeam(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) è KO! Mettete da parte la sua carta, e rimettete le sue Energie con le altre.", "\(n) is knocked out! Put its card aside, and its Energy cards back with the others.")
    }
    static func koLast(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) è KO! Era l'ultimo Pokémon della squadra.", "\(n) is knocked out! That was the last Pokémon on the team.")
    }
    static func whoNext(_ l: Lang, _ n: String) -> String {
        t(l, "Chi entra al posto di \(n)? Si sceglie dalla panchina: tocca un Pokémon su quella metà dello schermo.",
          "Who takes \(n)'s place? Choose from the bench: tap a Pokémon on that half of the screen.")
    }
    static func comesIn(_ l: Lang, _ n: String) -> String { t(l, "Entra \(n)! Sposta la sua carta davanti.", "In comes \(n)! Move its card to the front.") }
    static func teamWins(_ l: Lang, _ n: String) -> String { t(l, "Vince la squadra di \(n)! Bella partita!", "\(n)'s team wins! Great game!") }
    // Retreat (level 3)
    static func retreatTeach(_ l: Lang, _ n: String, _ cost: Int) -> String {
        t(l, "CAMBIA è la ritirata: \(n) torna in panchina e un altro Pokémon prende il suo posto. Costa Energia: guarda in basso sulla carta di \(n), accanto a «ritirata». Ogni cerchio è una carta Energia da togliere." + (cost == 0 ? " Non ci sono cerchi: è gratis." : ""),
          "SWAP is a retreat: \(n) goes back to the bench and another Pokémon takes its place. It costs Energy: look at the bottom of \(n)'s card, next to \"retreat\". Each circle is one Energy card to take off." + (cost == 0 ? " There are none: it's free." : ""))
    }
    static func retreatCost(_ l: Lang, _ n: String, _ k: Int, _ have: Int) -> String {
        t(l, "Per ritirarsi \(n) ha bisogno di \(k) Energi\(k == 1 ? "a" : "e"): ne ha \(have).", "\(n) needs \(k) Energy to retreat: it has \(have).")
    }
    static func oneRetreat(_ l: Lang) -> String { t(l, "Solo una ritirata per turno!", "Only one retreat each turn!") }
    static func noBench(_ l: Lang) -> String { t(l, "Non c'è nessuno in panchina con cui scambiarlo.", "There's no one on the bench to swap with.") }
    static func whoIn(_ l: Lang, _ n: String) -> String {
        t(l, "Chi prende il posto di \(n)? Tocca un Pokémon della panchina.", "Who takes \(n)'s place? Tap a Pokémon from the bench.")
    }
    /// The Energy cards to take off, by type: "un'Energia Lampo e 2 Energie Fuoco" / "a Lightning Energy card and 2 Fire Energy cards"
    static func energyList(_ l: Lang, _ types: [String]) -> String {
        var order: [String] = []
        for e in types where !order.contains(e) { order.append(e) }
        return list(l, order.map { e in
            let k = types.filter { $0 == e }.count
            return k == 1 ? energyCard(l, e) : t(l, "\(k) Energie \(Kind.name(e, l))", "\(k) \(e) Energy cards")
        })
    }
    static func retreated(_ l: Lang, _ out: String, _ inn: String, _ paid: [String], kept: Int) -> String {
        let swap = t(l, "scambia le carte: \(out) va in panchina, \(inn) viene davanti.", "swap the cards: \(out) goes to the bench, \(inn) comes to the front.")
        var s = paid.isEmpty ? t(l, "La ritirata di \(out) non costa niente: ", "\(out)'s retreat costs nothing: ") + swap
            : t(l, "Togli \(energyList(l, paid)) da \(out) e \(paid.count == 1 ? "rimettila" : "rimettile") con le altre. Poi ",
                "Take \(energyList(l, paid)) off \(out) and put \(paid.count == 1 ? "it" : "them") back with the others. Then ") + swap
        if kept > 0 { s += t(l, " Le sue altre Energie restano con lui.", " Its other Energy cards stay with it.") }
        return s
    }
    static func retreatTip(_ l: Lang, _ n: String, _ type: String) -> String {
        t(l, "Attenzione: \(n) teme il tipo \(type), che gli fa danni doppi. Con CAMBIA puoi mandarlo in panchina.",
          "Careful: \(n) is weak to \(type), which does double damage to it. SWAP can send it back to the bench.")
    }
    static func coinTeach(_ l: Lang) -> String { t(l, "Questo attacco dice di lanciare una moneta. La lancio io!", "This attack says to flip a coin. I'll flip it!") }
    static func wins(_ l: Lang, _ n: String) -> String { t(l, "Vince \(n)! Bella partita!", "\(n) wins! Great game!") }
    static func again(_ l: Lang) -> String {
        t(l, "Un'altra partita? Rimettete le carte con le altre, poi toccate la Poké Ball: scelgo io i nuovi Pokémon.",
          "Another game? Put the cards back with the others, then tap the Poké Ball: I'll choose new Pokémon.")
    }
    // The add screen, for a grown-up
    /// One pile for both players, whichever half's + opened it (Jordan, 18 Oct: "why does it say 'his cards' even when
    /// I'm adding the ones on the bottom")
    static func yourCards(_ l: Lang) -> String { t(l, "Le vostre carte", "Your cards") }
    static func addHint(_ l: Lang) -> String {
        t(l, "Le carte Pokémon che avete, evoluzioni comprese. A ogni partita l'app sceglie per ognuno Pokémon di forza simile. Inquadra il codice in basso a sinistra di ogni carta (per esempio SVI 038/198), oppure scrivi il numero (38/198) o il nome.",
          "The Pokémon cards you have, evolved ones too. Each game, the app picks Pokémon of about the same strength for each of you. Point the camera at the code at the bottom left of each card (like SVI 038/198), or type the number (38/198) or the name.")
    }
    static func typeName(_ l: Lang) -> String { t(l, "Numero (38/198) o nome", "Number (38/198) or name") }
    static func searchWord(_ l: Lang) -> String { t(l, "Cerca", "Search") }
    static func looking(_ l: Lang) -> String { t(l, "Cerco…", "Looking…") }
    static func noneFound(_ l: Lang) -> String {
        t(l, "Non trovo niente. Scrivi il numero in basso a sinistra (come 38/198), o il nome.", "Nothing found. Type the number at the bottom left (like 38/198), or the name.")
    }
    static func tapCard(_ l: Lang) -> String {
        t(l, "Tocca la carta giusta: il numero sotto è quello stampato in basso a sinistra.", "Tap the right card: the number under it is the one printed at the bottom left.")
    }
    static func cantRead(_ l: Lang) -> String {
        t(l, "Non riesco a leggerla: avvicina il codice in basso a sinistra, o scrivi il nome.", "Can't read it: bring the code at the bottom left closer, or type the name.")
    }
    static func adding(_ l: Lang) -> String { t(l, "Aggiungo…", "Adding…") }
    static func added(_ l: Lang, _ n: String) -> String { t(l, "\(n) aggiunto! Avanti la prossima.", "\(n) added! Next card.") }
    static func addedForLater(_ l: Lang, _ c: Card) -> String { t(l, "Aggiunto. ", "Added. ") + notYet(l, c) }
    static func notPokemon(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) non è un Pokémon: per ora si usano solo le carte Pokémon.", "\(n) isn't a Pokémon: only Pokémon cards for now.")
    }
    static func noPicture(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) aggiunto, ma la sua immagine non si è scaricata: riprovo alla prossima apertura.", "\(n) added, but its picture didn't download: I'll try again next time the app opens.")
    }
    static func offline(_ l: Lang) -> String { t(l, "Per aggiungere le carte serve internet.", "Adding cards needs the internet.") }
    static func count(_ l: Lang, _ n: Int) -> String {
        n == 0 ? t(l, "Nessuna ancora", "None yet")
            : t(l, "\(n) carte aggiunte", "\(n) cards added")
    }

    /// Which voice is speaking, and how fast Kokoro makes speech on this iPad (for Claude, from a screenshot).
    static func voiceInfo(_ l: Lang, _ kokoro: Bool, _ speed: Double?) -> String {
        guard kokoro else { return t(l, "Voce: quella dell'iPad", "Voice: the iPad's own") }
        guard let s = speed else { return t(l, "Voce: Kokoro", "Voice: Kokoro") }
        let n = String(format: "%.1f", s)
        return t(l, "Voce: Kokoro, 1 secondo di voce in \(n.replacingOccurrences(of: ".", with: ",")) secondi",
                 "Voice: Kokoro, 1 second of speech in \(n) seconds")
    }

    static func card(_ l: Lang, _ c: Card) -> String {
        let w = c.weak.map { t(l, " Debolezza: \(Kind.name($0, l)).", " Weak to \(Kind.name($0, l)).") } ?? ""
        return t(l, "\(c.name(l)). \(c.hp) punti salute. Tipo \(Kind.name(c.type, l)).", "\(c.name(l)). \(c.hp) HP. \(Kind.name(c.type, l)) type.") + w
    }
}
