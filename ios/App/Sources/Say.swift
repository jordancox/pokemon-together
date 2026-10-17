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

    // Spoken
    static func voiceOn(_ l: Lang) -> String { t(l, "Eccomi!", "I'm back!") }
    static func language(_ l: Lang) -> String { t(l, "Italiano!", "English!") }
    static func pick(_ l: Lang) -> String {
        t(l, "Ognuno sceglie una carta Pokémon e la mette sul tavolo, davanti a sé. Poi toccate lo stesso Pokémon qui.",
          "Each of you, choose a Pokémon card and put it on the table in front of you. Then tap the same Pokémon here.")
    }
    static func picked(_ l: Lang, _ n: String, _ hp: Int) -> String { t(l, "\(n)! \(hp) punti salute.", "\(n)! \(hp) HP.") }
    static func pickedTeach(_ l: Lang, _ n: String, _ hp: Int) -> String {
        t(l, "\(n)! Guarda la carta: il numero grande in alto a destra, \(hp), sono i punti salute. Vuol dire quanti danni può prendere prima di andare KO.",
          "\(n)! Look at the card: the big number at the top right, \(hp), is its HP. That's how much damage it can take before it's knocked out.")
    }
    static func ready(_ l: Lang) -> String {
        t(l, "Ognuno mette qualche carta Energia accanto al suo Pokémon. Se non ne avete, vanno bene dei gettoni. Pronti? Toccate la Poké Ball!",
          "Each of you, put some Energy cards next to your Pokémon. No Energy cards? Coins will do. Ready? Tap the Poké Ball!")
    }
    /// "un'Energia Lampo" / "a Lightning Energy card"; any Energy for a Colorless cost
    static func energyCard(_ l: Lang, _ type: String) -> String {
        type == "Colorless" ? t(l, "un'Energia qualsiasi", "any Energy card") : t(l, "un'Energia \(Kind.name(type, l))", "a \(type) Energy card")
    }
    static func flip(_ l: Lang) -> String { t(l, "Lancio la moneta per vedere chi comincia…", "Let's flip a coin to see who goes first…") }
    static func starts(_ l: Lang, _ n: String) -> String { t(l, "Comincia \(n)!", "\(n) goes first!") }
    static func turnFirst(_ l: Lang, _ n: String, _ e: String) -> String {
        t(l, "Tocca a \(n)! A ogni turno puoi mettere una carta Energia sul tuo Pokémon: è il carburante degli attacchi. Metti \(e) su \(n), poi tocca ENERGIA.",
          "\(n)'s turn! Each turn you can put one Energy card on your Pokémon: Energy powers its attacks. Put \(e) on \(n), then tap ENERGY.")
    }
    static func turn(_ l: Lang, _ n: String, _ e: String) -> String { t(l, "Tocca a \(n)! Metti \(e).", "\(n)'s turn! Put on \(e).") }
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
        t(l, "\(n) aveva \(full) punti salute e ha preso \(taken) danni: gliene restano \(hp). Non serve contare, il conto lo tengo io.",
          "\(n) had \(full) HP and has taken \(taken) damage, so it has \(hp) left. No need to count: I'll keep track.")
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
    static func coinTeach(_ l: Lang) -> String { t(l, "Questo attacco dice di lanciare una moneta. La lancio io!", "This attack says to flip a coin. I'll flip it!") }
    static func wins(_ l: Lang, _ n: String) -> String { t(l, "Vince \(n)! Bella partita!", "\(n) wins! Great game!") }
    static func again(_ l: Lang) -> String {
        t(l, "Un'altra partita? Togliete le Energie, scegliete le carte e toccatele qui.", "Another game? Take the Energy off, choose your cards and tap them here.")
    }
    // The add screen, for a grown-up
    static func hisCards(_ l: Lang) -> String { t(l, "Le sue carte", "His cards") }
    static func addHint(_ l: Lang) -> String {
        t(l, "Inquadra il codice in basso a sinistra della carta (per esempio SVI 038/198), oppure scrivi il nome.",
          "Point the camera at the code at the bottom left of a card (like SVI 038/198), or type the name.")
    }
    static func typeName(_ l: Lang) -> String { t(l, "Nome del Pokémon", "Pokémon name") }
    static func searchWord(_ l: Lang) -> String { t(l, "Cerca", "Search") }
    static func looking(_ l: Lang) -> String { t(l, "Cerco…", "Looking…") }
    static func noneFound(_ l: Lang) -> String { t(l, "Non trovo niente. Prova un altro nome.", "Nothing found. Try another name.") }
    static func tapHis(_ l: Lang) -> String { t(l, "Tocca la sua carta.", "Tap his card.") }
    static func cantRead(_ l: Lang) -> String {
        t(l, "Non riesco a leggerla: avvicina il codice in basso a sinistra, o scrivi il nome.", "Can't read it: bring the code at the bottom left closer, or type the name.")
    }
    static func adding(_ l: Lang) -> String { t(l, "Aggiungo…", "Adding…") }
    static func added(_ l: Lang, _ n: String) -> String { t(l, "\(n) aggiunto! Avanti la prossima.", "\(n) added! Next card.") }
    static func addedForLater(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) aggiunto. È un'evoluzione: entra in gioco in un livello più avanti.", "\(n) added. It's an Evolution card: it joins the game in a later level.")
    }
    static func notPokemon(_ l: Lang, _ n: String) -> String {
        t(l, "\(n) non è un Pokémon: per ora si usano solo le carte Pokémon.", "\(n) isn't a Pokémon: only Pokémon cards for now.")
    }
    static func offline(_ l: Lang) -> String { t(l, "Per aggiungere le carte serve internet.", "Adding cards needs the internet.") }
    static func count(_ l: Lang, _ n: Int) -> String {
        n == 0 ? t(l, "Nessuna ancora: finché non ne aggiungi due, si gioca con le carte di prova.", "None yet: until you add two, the sample cards are used.")
            : t(l, "\(n) carte aggiunte", "\(n) cards added")
    }

    static func card(_ l: Lang, _ c: Card) -> String {
        let w = c.weak.map { t(l, " Debolezza: \(Kind.name($0, l)).", " Weak to \(Kind.name($0, l)).") } ?? ""
        return t(l, "\(c.name(l)). \(c.hp) punti salute. Tipo \(Kind.name(c.type, l)).", "\(c.name(l)). \(c.hp) HP. \(Kind.name(c.type, l)) type.") + w
    }
}
