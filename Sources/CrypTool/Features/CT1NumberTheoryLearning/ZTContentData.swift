// Generated from the content recovered out of ZT.exe (Martin Ramberger, Authorware 4).
// Page texts are verbatim; \u{E000}…\u{E001} = superscript, \u{E002}…\u{E003} = subscript.

extension ZTContent {
    static func lesson1() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "1.1", title: "Teilbarkeit", pages: [
            ZTPage(id: "1.1 - 01", title: "Teiler und Komplementärteiler", tool: .divisorPairs, blocks: [
                "    ·  d ist ein Teiler von n, wenn eine Zahl z ∈ ℕ existiert mit d·z = n.\n    ·  Ist d ein Teiler von n, dann heißt      Komplementärteiler zu d.\nAuf der Suche nach Teilern von n muss man nur die Teiler ≤ √n bestimmen,\ndie übrigen Teiler sind deren Komplementärteiler.",
                "Die Anzahl der Teiler ist bei Quadratzahlen ungerade, weil ein Teiler \"doppelt auftritt\",\nbei allen anderen Zahlen gerade.",
            ]),
            ZTPage(id: "1.1 - Teiler in Z", title: "Teiler in ℤ", tool: .divides, blocks: [
                "Man kann den Begriff des Teilers auf ganze Zahlen ausdehnen:\nDefinition: Seien a, b ∈ ℤ.\n    a ist ein Teiler von b, wenn z ∈ ℤ existiert mit a·z = b.\n    Schreibweise: a | b. Man sagt auch: a teilt b, b ist durch a teilbar, b ist ein Vielfaches von a.\n\nBeispiel:      5 | –15,  denn es existiert –3 ∈ ℤ mit 5·(–3) = –15",
                "Satz: Für alle a, b, c ∈ ℤ gelten die folgenden Regeln der Teilbarkeit:\n    1.  ±1 | a  und  ±a | a,    denn    1·a = a = (–1)·(–a)  und  a·1 = a = (–a)·(–1).\n    2.  a | 1  ⇒  a = ±1,    \"    für a ≠ ±1 existiert kein z ∈ ℤ mit a·z = ±1.\n    6.  a | b  ⇒  a·c | b·c,    \"    a·z = b  ⇒  b·c = (a·z)·c = (a·c)·z.\n    7.  a | b  ∧  b ≠ 0  ⇒  |a| ≤ |b|,    \"    a·z = b  ∧  z ≠ 0  ⇒  |a·z| ≥ |a|.\n    8.  a | b  ∧  b | a  ⇒  |a| = |b|,    \"    falls a = 0, dann ist b = 0 und umgekehrt,\n            sonst ist |a| ≤ |b| und |b| ≤ |a|, also |a| = |b|.\n    3.  a | 0,    \"    a·0 = 0.\n    4.  0 | b  ⇒  b = 0,    \"    0·z = b  ⇒  b = 0.\n    5.  a | b  ∧  b | c  ⇒  a | c,    \"    a·z\u{E002}1\u{E003} = b  ∧  b·z\u{E002}2\u{E003} = c  ⇒  c = (a·z\u{E002}1\u{E003})·z\u{E002}2\u{E003} = a·(z\u{E002}1\u{E003}·z\u{E002}2\u{E003}).",
                " 1 teilt a,      a teilt a,\n–1 teilt a,    –a teilt a.",
                "Wenn a Teiler von 1 ist, dann ist a gleich 1 oder –1.\nDas heißt: Die einzigen Teiler von 1 sind 1 und –1.",
                "Jede Zahl teilt 0. Auch 0 teilt 0, denn 0·z = 0 gilt sogar mit beliebigem z ∈ ℤ.\nTrotzdem ist die Division 0 durch 0 verboten, denn kein z ist als Ergebnis definiert.",
                "Wenn 0 eine Zahl teilt, dann ist diese Zahl gleich 0.\nDas heißt: Nur 0 wird von 0 geteilt.\nOder: Das einzige Vielfache von 0 ist 0 selbst.",
                "Ist a Teiler von b, und ist b Teiler von c, dann ist a Teiler von c.\nMan sagt deshalb auch: Teilbarkeit ist transitiv.\n\"Transitiv\" könnte man hier mit \"überbrückend\" übersetzen.",
                "Ist a Teiler von b, dann ist a·c Teiler von b·c.",
                "Wenn a Teiler von b ist und b ungleich 0, dann ist a dem Betrage nach kleiner als b.",
                "Ist a Teiler von b, und ist b Teiler von a, dann sind a und b dem Betrage nach gleich.",
            ]),
            ZTPage(id: "1.1 - Teilermenge", title: "Die Teilermenge", tool: .divisorSet, blocks: [
                "Mit jeder Zahl a ist auch –a ein Teiler von b:   a | b  ⇔  –a | b.\nDeshalb reicht es, wenn man die positiven Teiler sammelt:\n\nDefinition:     Für a ∈ ℤ heißt \u{E002}T\u{E003}a = { x ∈ ℕ  |  x | a } Teilermenge von a.",
                "Dieser Strich bedeutet:\n\"mit folgender Eigenschaft\"",
                "d | a  ⇔  d | –a,    denn   a = d·z  ⇔  –a = d·(–z)",
                "Teibarkeitsregel 3",
                "Teibarkeitsregel 7",
                "Teibarkeitsregel 1",
                "Keine Teilermenge ist leer:  T\u{E002}a\u{E003} ≠ ∅  für alle a.\nDie Teilermenge von 0 enthält alle natürlichen Zahlen:  T\u{E002}0\u{E003} = ℕ.\nDie Teilermengen für a ≠ 0 sind endlich.\n\nWegen T\u{E002}a\u{E003} = T\u{E002}–a\u{E003} kann man die Untersuchung von Teilermengen auf a ∈ ℕ beschränken.",
            ]),
            ZTPage(id: "1.1 - Def ggT", title: "Der größte gemeinsame Teiler", tool: .gcdSets, blocks: [
                "Definition: Sind die Zahlen a, b ∈ ℤ nicht beide gleich 0, dann heißt\n    die größte Zahl aus T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}  größter gemeinsamer Teiler von a und b, kurz ggT(a, b).\nDer ggT existiert, denn jede Teilermenge enthält die Zahl 1, \nund mindestens eine Teilermenge ist endlich, also auch der Schnitt der Teilermengen;\nweil man alle natürlichen Zahlen bezüglich Größe miteinander vergleichen kann,\nenthält jede endliche nicht-leere Menge natürlicher Zahlen ein größtes Element.",
                "HSatz: Folgende Regeln gelten für den ggT:\n    1. ggT(a, b) = ggT(±a, ±b),     denn  \u{E002}T\u{E003}a = \u{E002}T–\u{E003}a  und  \u{E002}T\u{E003}b = \u{E002}T–\u{E003}b\n    2. ggT(a, 0) = |a|  für a ≠ 0,    denn  \u{E002}T\u{E003}0 = ℕ    und  \u{E002}T\u{E003}a ∩ ℕ = \u{E002}T\u{E003}a = \u{E002}T|a\u{E003}|\n    3. ggT(a, 1) = 1,    denn  \u{E002}T\u{E003}1 = {1}  und  Ta ∩ {1} = {1}\nWegen Regel 1 kann man sich bei der Bestimmung von ggT(a, b) auf a, b ∈ ℕ beschränken.\nDefinition: Zwei Zahlen a, b ∈ ℤ heißen teilerfremd oder prim zueinander, wenn ggT(a, b) = 1.\nmehr Beispiele\nBeispiel:     T–6 = {1, 2, 3, 6},  T15 = {1, 3, 5, 15},\n    T\u{E002}–6\u{E003} ∩ T\u{E002}15\u{E003} = {1, 3}  ⇒  ggT(–6, 15) = 3",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.2", title: "Primzahlen", pages: [
            ZTPage(id: "1.2 - 01", title: "Primzahlen", tool: .trialDivision, blocks: [
                "Definition:    Eine Primzahl p ist eine natürliche Zahl mit genau zwei positiven Teilern,\n    nämlich 1 und p selbst. Die Menge aller Primzahlen heißt ℙ.\n\nBeachten Sie, dass 1 keine Primzahl ist. Die Primzahlen < 100 sind:\n2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97.",
                "Definition:    Teilt eine Primzahl p eine ganze Zahl a, dann heißt p Primteiler von a.\nSatz:     Jede natürliche Zahl n > 1 hat mindestens einen Primteiler.    Beweis",
                "Daraus gewann schon Euklid Einsicht in die Anzahl der Primzahlen:\nSatz:     Es gibt unendlich viele Primzahlen.    Beweis",
                "Definition:     Die natürlichen Zahlen zwischen den Primzahlen heißen zusammengesetzte Zahlen.\nSatz:     Jede zusammengesetzte Zahl n hat einen Primteiler p ≤ \u{E002}Ö\u{E003} n.    Beweis",
                "Ist also eine natürliche Zahl n > 1 durch keine Primzahl p ≤ √n teilbar, dann ist n eine Primzahl.\nBeispiel:     89 ist Primzahl, denn 2, 3, 5, 7 teilen 89 nicht,  und 11 > √89.",
            ]),
            ZTPage(id: "1.2 - Eratosthenes", title: "Das Sieb des Eratosthenes", tool: .sieve, blocks: [
                "Jede zusammengesetzte Zahl n hat einen Primteiler ≤ √n. Das macht man sich zunutze beim\nSieb des Eratosthenes. Es findet alle Primzahlen bis zu einer Grenze g",
            ]),
            ZTPage(id: "1.2 - Erat mit Einsen", title: "Probedivision", tool: .trialDivision, blocks: [
                "Jede p-te Zahl ist ein Vielfaches von p: Man kann sie unbesehen streichen. Daher reicht es,\nwenn man das Sieb am Anfang mit Einsen füllt, um Platz zu sparen.\nAußerdem lässt man die geraden Zahlen gleich weg. Dann vertritt das i-te Feld die Zahl 2·i – 1.\nAm Ende markieren die Einsen die Primzahlen > 2.\nISiebgröße =    {{, .., {} enthält { Primzahlen.",
            ]),
            ZTPage(id: "1.2 - Fundamentalsatz", title: "Der Fundamentalsatz", tool: .factorize, blocks: [
                "Die zusammengesetzten Zahlen kann man als Produkte natürlicher Zahlen > 1 darstellen.\n\nBeispiele:    ·  4 = 2·2\n    ·  60 = 6·10 = 2·3·2·5  oder  60 = 4·15 = 2·2·3·5\n\nEine solche Darstellung heißt Faktorzerlegung. Ein Faktor ∈ ℙ heißt Primfaktor.\nEine Primfaktorzerlegung enthält nur Primfaktoren.\nDie Primfaktorzerlegung einer Primzahl p besteht aus einem einzigen Faktor: p selbst.",
                "Satz:     Teilt p ∈ ℙ ein Produkt ganzer Zahlen, dann teilt p mindestens einen Faktor.\nBewiesen wird der Satz gegen Ende von Abschnitt 1.3.\nAnmerkung: Für p ∉ ℙ gibt es Gegenbeispiele, etwa: p = 4 teilt 2·10, aber weder 2 noch 10.",
                "Damit gilt der Fundamentalsatz der Zahlentheorie:\n\nSatz:     Jede natürliche Zahl n > 1 hat eine eindeutige Primfaktorzerlegung,\n    wenn man die Reihenfolge der Primfaktoren außer Acht lässt.\nBeweis",
            ]),
            ZTPage(id: "1.2 - Zahlenmenge 4n+1", title: "Die Zahlenmenge 4n+1", tool: .hilbert, blocks: [
                "∅Der Satz, dass jede natürliche Zahl > 1 eine eindeutige Primfaktorzerlegung hat, scheint trivial. Aber er gilt nicht in jeder Zahlenmenge.\nBeispiel:     Betrachten Sie H = {4·n + 1 | n ∈ I\u{E002}N\u{E003}0} = {1, 5, 9, 13, 17, 21, 25, 29, 33, ...}.",
                "    H ist multiplikativ abgeschlossen, das heißt:  a, b ∈ H  ⇒  a·b ∈ H.\n    Denn:  (4·a+1)·(4·b+1)  =  16·a·b + 4·a + 4·b + 1  =  4·(4·a·b+a+b) + 1",
                "Primzahlen sind in H definiert als Zahlen mit genau zwei Teilern ∈ H.\nIst a ∈ H Primzahl in ℕ, dann ist a auch Primzahl in H.",
                "    Zusätzlich gibt es in H Primzahlen, die in ℕ keine Primzahlen sind,\n    zum Beispiel:\n    ·  9    ist Primzahl in H. Die Zerlegung 9 = 3·3 existiert in H nicht, denn 3 ∉ H.\n    ·  77    ist Primzahl in H. Die Zerlegung 7 = 7·11 existiert in H nicht, denn 7 ∉ H.",
                "    Und in H gibt es Zahlen mit mehr als einer Primfaktorzerlegung,\n    zum Beispiel:\n    ·  441 = 21·21 = 9·49    ·  1089 = 33·33 = 9·121\n    ·  3249 = 57·57 = 9·361    ·  5929 = 77·77 = 49·121",
            ]),
            ZTPage(id: "1.2 - kanonische PFZ", title: "Kanonische Primfaktorzerlegung", tool: .factorize, blocks: [
                "Gewöhnlich ordnet man die Faktoren einer Primfaktorzerlegung nach ihrer Größe\nund fasst gleiche Faktoren zu Potenzen zusammen, zum Beispiel:  200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001}",
                "Nummeriert man die Primzahlen nach ihrer Größe,\n    p\u{E002}1\u{E003} = 2,   p\u{E002}2\u{E003} = 3,   p\u{E002}3\u{E003} = 5,   p\u{E002}4\u{E003} = 7,   p\u{E002}5\u{E003} = 11,  ...",
                "und kommt in der Primfaktorzerlegung einer Zahl a die i-te Primzahl a\u{E002}i\u{E003} mal vor,",
                "        a = ∏ p\u{E002}i\u{E003}\u{E000}a\u{E001}i   =  p\u{E002}1\u{E003}\u{E000}a\u{E001}1 · p\u{E002}2\u{E003}\u{E000}a\u{E001}2 · p\u{E002}3\u{E003}\u{E000}a\u{E001}3 · ....\n\nBeispiel:       200 = 2\u{E000}3\u{E001}·3\u{E000}0\u{E001}·5\u{E000}2\u{E001}·7\u{E000}0\u{E001}·11\u{E000}0\u{E001}·13\u{E000}0\u{E001}·...\ndann ist",
                "Dieses Produkt hat nur endlich viele Faktoren,\ndenn alle Primzahlen, die a nicht teilen, werden durch den Exponenten a\u{E002}i\u{E003} = 0 neutralisiert.\n =  2\u{E000}3\u{E001}·1·5\u{E000}2\u{E001}·1·1·1·...  =  2\u{E000}3\u{E001}·5\u{E000}2\u{E001}",
                "p\u{E000}0\u{E001} = 1, und der Faktor 1 ändert nichts am Produkt.",
                "Definition:       a = ∏ p\u{E002}i\u{E003}\u{E000}a\u{E001}i   heißt kanonische Primfaktorzerlegung von a.\n\nIn der kanonischen Primfaktorzerlegung von 1 sind alle Exponenten a\u{E002}i\u{E003} = 0.",
            ]),
            ZTPage(id: "1.2 - Anzahl Teiler", title: "Anzahl der Teiler", tool: .divisorCount, blocks: [
                "Mit der kanonischen Primfaktorzerlegung kann man die Teiler einer Zahl a ∈ ℕ bestimmen.\nDie Zahl  d = ∏ p\u{E002}i\u{E003}\u{E000}d\u{E001}i   ist genau dann ein Teiler von  a = ∏ p\u{E002}i\u{E003}\u{E000}a\u{E001}i  , wenn d\u{E002}i\u{E003} ≤ a\u{E002}i\u{E003} für alle i ∈ ℕ.",
                "Beispiel:     Die positiven Teiler d von a = 200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001} sind:\n    2\u{E000}0\u{E001}·5\u{E000}0\u{E001} = 1    2\u{E000}0\u{E001}·5\u{E000}1\u{E001} = 5    2\u{E000}0\u{E001}·5\u{E000}2\u{E001} = 25\n    2\u{E000}1\u{E001}·5\u{E000}0\u{E001} = 2    2\u{E000}1\u{E001}·5\u{E000}1\u{E001} = 10    2\u{E000}1\u{E001}·5\u{E000}2\u{E001} = 50\n    2\u{E000}2\u{E001}·5\u{E000}0\u{E001} = 4    2\u{E000}2\u{E001}·5\u{E000}1\u{E001} = 20    2\u{E000}2\u{E001}·5\u{E000}2\u{E001} = 100\n    2\u{E000}3\u{E001}·5\u{E000}0\u{E001} = 8     2\u{E000}3\u{E001}·5\u{E000}1\u{E001} = 40    2\u{E000}3\u{E001}·5\u{E000}2\u{E001} = 200",
                "Die negativen Teiler unterscheiden sich nur durch ihr Vorzeichen von den positiven.",
                "Die positiven Teiler entstehen durch Kombination der Primfaktoren. Dabei darf\nin jeder Kombination der Primfaktor p\u{E002}i\u{E003} maximal a\u{E002}i\u{E003} mal vorkommen oder auch fehlen.\nDas ergibt insgesamt (a\u{E002}1\u{E003}+1)·(a\u{E002}2\u{E003}+1)·(a\u{E002}3\u{E003}+1)·.... mögliche Kombinationen.\nWegen der Eindeutigkeit der Primfaktorzerlegung in ℕ ist jede Kombination ein neuer Teiler.\n(3+1) Möglichkeiten für Primfaktor 2\n(2+1) Möglichkeiten für Primfaktor 5",
                "Die Anzahl der positiven Teiler von a ∈ ℕ ist also P (a\u{E002}i\u{E003}+1).\nBeispiel:     200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001}  hat  (3+1)·(2+1) = 12  positive Teiler.",
            ]),
            ZTPage(id: "1.2 - ggT mit Hilfe PFZ", title: "ggT mit Hilfe der PFZ", tool: .gcdFactor, blocks: [
                "Kennt man die Primfaktorzerlegungen zweier Zahlen a, b ∈ ℕ,\nso kann man den ggT(a, b) auch ohne T\u{E002}a\u{E003} und T\u{E002}b\u{E003} bestimmen.",
                "⇒min(x, y) ist das Minimum von x und y,\nalso x, falls x ≤ y; andernfalls y.",
                "Taucht der Primteiler p\u{E002}i\u{E003} in a a\u{E002}i\u{E003} mal und in b b\u{E002}i\u{E003} mal auf, so im ggT(a, b) min(a\u{E002}i \u{E003}, b\u{E002}i\u{E003}) mal:\n∩a = P \u{E002}p\u{E003}\u{E000}i\u{E001}ai   ∧  b = P \u{E002}p\u{E003}\u{E000}i\u{E001}bi    ⇒    ggT(a, b) = P \u{E002}p\u{E003}imin(ai\u{E000} ,\u{E001} b\u{E000}i\u{E001}) ",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.3", title: "Euklids Algorithmus", pages: [
            ZTPage(id: "1.3 - 01", title: "Vielfachsummen", tool: .linearCombination, blocks: [
                "Definition:    Seien a, b ∈ ℤ.\n    Dann heißt  a·x + b·y mit x, y ∈ ℤ Vielfachsumme von a und b.\n    Die Zahlen x und y heißen Koeffizienten der Vielfachsumme.",
                "Beispiel:    a und b sind anklickbar.",
                "Satz:    Seien a, b \u{E002}∈\u{E003} Z. Dann gilt für alle x, y \u{E002}∈\u{E003} Z:\n    d | a  ∧  d | b    ⇒    d | a·x + b·y\n    Jeder gemeinsame Teiler der Zahlen a, b teilt jede Vielfachsumme von a, b.   Beweis\nAlso nur Vielfache der gemeinsamen Teiler von a, b können Vielfachsumme von a, b sein.",
                "Satz:    Jede Vielfachsumme hat unendlich viele Darstellungen.     Beweis",
            ]),
            ZTPage(id: "1.3 - ggT(a,b)=ggT(b,a-b)", title: "ggT(a, b) = ggT(b, a – b)", tool: .subtractiveGcd, blocks: [
                "Seien a, b ∈ ℤ.\nSubtrahiert man von a ein Vielfaches von b, so erhält man als Vielfachsumme von a und b:\na – x·b = c\nEs gilt also:     d | a  ∧  d | b  ⇒  d | c",
                "Formt man die Gleichung um, so erhält man a als Vielfachsumme von b und c:\na = x·b + c\nEs gilt also auch:     d | b  ∧  d | c  ⇒  d | a",
                "Insgesamt gilt also:    d | a  ∧  d | b  ⇔  d | b  ∧  d | c\nDas heißt für die Teilermengen:    T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}     =     T\u{E002}b\u{E003} ∩ T\u{E002}c\u{E003}\nUnd damit gilt:    ggT(a, b)     =     ggT(b, c)\nBeispiele:      ·  1024    – 10·100    = 24,     also ist  ggT(1024, 100)  =  ggT(100, 24)\n    ·  100    – 4·24    = 4,      also ist  ggT(100, 24)  =  ggT(24, 4)\n    ·  24    – 6·4    = 0,      also ist  ggT(24, 4)  =  ggT(4, 0)  =  4",
            ]),
            ZTPage(id: "1.3 - Euklid Ablauf", title: "Ablauf des Euklidischen Algorithmus", tool: .euclid, blocks: [
                "a – z·b = r   ⇔   a = z·b + r\nWeil r Vielfachsumme von a und b ist, gilt:     d | a  ∧  d | b     ⇒     d | b  ∧  d | r\nWeil a Vielfachsumme von b und r ist, gilt:    d | b  ∧  d | r     ⇒     d | a  ∧  d | b\nAlso gilt:    d | a  ∧  d | b     ⇔     d | b  ∧  d | r\nalso:    T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}     =     T\u{E002}b\u{E003} ∩ T\u{E002}r\u{E003}\nund damit:    ggT(a, b)     =     ggT(b, r)",
                "ggT(a, b) = ggT(±a, ±b)",
                "Euklid: \"Subtrahiere von der ersten Zahl a ein solches Vielfaches der zweiten Zahl b,",
                "Beim Rest = 0 hört man auf. Der letzte Rest > 0 ist der gesuchte ggT.",
            ]),
            ZTPage(id: "1.3 - die Teiler des ggT", title: "Die Teiler des ggT", tool: .gcdSets, blocks: [
                "a–x·b ist Vielfachsumme von a und b.",
                "Man subtrahiert von der ersten Zahl immer ein solches Vielfaches der zweiten,\ndass ein möglichst kleiner Rest ≥ 0 bleibt.",
                "Irgendwann tritt der Rest 0 auf.",
                "⇔r ist die größte Zahl ∈ \u{E002}T\u{E003}r = \u{E002}Ta\u{E003} ∩ \u{E002}Tb\u{E003}",
                "Dem euklidischen Algorithmus entsprechen folgende Gleichungen mit r als letztem Rest > 0:\nT\u{E002}a \u{E003}∩ T\u{E002}b\u{E003}  =  T\u{E002}b \u{E003}∩ T\u{E002}a–x·b\u{E003}  =  ...  =  T\u{E002}r \u{E003}∩ T\u{E002}0\u{E003}  =  T\u{E002}r\u{E003}  =  TggT(a,b)\nDie gemeinsamen Teiler von a und b sind also genau die Teiler des ggT(a, b).",
                "Deshalb kann man ggT(a, b) auch so definieren:\nDefinition:     Die Zahl d ∈ ℕ\u{E002}0\u{E003} heißt größter gemeinsamer Teiler von a und b, wenn gilt:\n    1. d | a  und  d | b    d ist gemeinsamer Teiler.\n    2. t | a und t | b  ⇒  t | d    Jeder gemeinsame Teiler teilt d.\n\nNach dieser Definition ist ggT(0, 0) = 0 sinnvoll, denn:\n    1. 0 ist gemeinsamer Teiler.\n    2. Jeder gemeinsame Teiler – also jede ganze Zahl – teilt 0.",
                "Noch einmal zur Frage, welche Zahlen können Vielfachsumme von a und b sein?\nBisher galt:     nur Vielfache aller gemeinsamen Teiler von a und b\nDas heißt jetzt kurz:     nur Vielfache des ggT(a, b)\n\nEs bleibt die Frage: Ist ggT(a, b) immer als Vielfachsumme von a und b darstellbar?",
            ]),
            ZTPage(id: "1.3 - ggT als Vielfachsumme", title: "Der ggT als Vielfachsumme", tool: .extEuclid, blocks: [
                "Der euklidische Algorithmus berechnet ggT(a, b). Dabei kann man alle auftretenden Reste als Vielfachsummen von a und b schreiben und ihre Koeffizienten berechnen:",
                "ggT(a, b) = ggT(±a, ±b)\nDie Koeffizienten reagieren mit ihren Vorzeichen.",
                "Man erhält ggT(a, b) als Vielfachsumme von |a| und |b|.\nFalls a < 0 oder b < 0, so multipliziert man den entsprechenden Koeffizienten mit –1\nund erhält ggT(a, b) als Vielfachsumme von a und b:",
            ]),
            ZTPage(id: "1.3 - Eigenschaften ggT", title: "Eigenschaften des ggT", tool: .extEuclid, blocks: [
                "Aus dem euklidischen Algorithmus folgt also:\nSatz:   Die Teiler des ggT(a, b) sind die gemeinsamen Teiler von a und b.    Demonstration\nSatz:   ggT(a, b) lässt sich als Vielfachsumme von a und b darstellen.    Demonstration",
                "Auch jedes Vielfache des ggT(a, b) lässt sich als Vielfachsumme von a und b darstellen:\n    ggT(a, b)  =  a·x + b·y    ⇒    ggT(a, b)·z  =  a·x·z + b·y·z\nWeil nur Vielfache des ggT(a, b) Vielfachsumme von a und b sein können, erhält man als\nFolgerung:    ggT(a, b) | d     ⇔    Es gibt x, y \u{E002}∈\u{E003} Z, so dass  d = a·x + b·y.",
                "Satz:   ggT(a, b) = d   ⇔   ggT(   ,   ) = 1    Beweis\nMit Vielfachsummen lassen sich bequem weitere Eigenschaften beweisen:\nSatz:   ggT(a, c) = 1  ∧  ggT(b, c) = 1   ⇒   ggT(a·b, c) = 1    Beweis\nSatz:   ggT(a, b) = 1  ∧  a | b·c   ⇒   a | c    Beweis",
                "In Abschnitt 1.2 wurde der Fundamentalsatz der Zahlentheorie bewiesen mit dem Satz:\n    Teilt eine Primzahl ein Produkt ganzer Zahlen, so teilt sie mindestens einen Faktor.\nHier ist der Beweis dieses Satzes.",
            ]),
            ZTPage(id: "1.3 - ggT von mehr als 2 Zahlen", title: "ggT von mehr als 2 Zahlen", tool: .gcdMany, blocks: [
                "Man kann den ggT von mehr als 2 Zahlen definieren:\nDefinition:     Seien k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k\u{E003} ∈ ℤ und k > 2. Dann ist      \u{E000}ggT( a\u{E001}1\u{E000},\u{E001} \u{E000}a\u{E001}2\u{E000},\u{E001} ..., ak ) = größte Zahl ∈ Ta\u{E002}1\u{E003} \u{E000}∩ T\u{E001}a\u{E002}2\u{E003} ∩ ... ∩ Ta\u{E002}k\u{E003}\u{E000} ,\u{E001} falls nicht alle a = 0,\n    ggT( 0, 0, ..., 0 ) = 0.",
                "Teilerfremde Zahlen sind nicht unbedingt paarweise teilerfremd.   Beispiel\n    Ist ggT(a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003}) = 1, dann heißen a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003} teilerfremd.",
                "Satz:      ggT( a, ggT(b, c) )  =  ggT( ggT(a, b), c )    Beweis\n    ggT( a\u{E002}1\u{E003}, ..., a\u{E002}k+1\u{E003} )  =  ggT( ggT( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} ), a\u{E002}k+1\u{E003} )  für k ≥ 2    Beweis\nMit der Eigenschaft T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003} = T\u{E002}ggT(a, b)\u{E003} kann man zeigen:",
                "Man kann auch Vielfachsummen von mehr als zwei Zahlen \u{E002}a\u{E003}1, \u{E002}a\u{E003}2, ..., \u{E002}a\u{E003}k definieren und\nmit vollständiger Induktion zeigen, dass sich mit ihnen ggT( \u{E002}a\u{E003}1, \u{E002}a\u{E003}2, ..., \u{E002}a\u{E003}k ) darstellen lässt.\nDer Kürze halber gibt es hier nur den Beweis für k = 3.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.4", title: "Das kgV", pages: [
            ZTPage(id: "1.4 - 01", title: "Das kleinste gemeinsame Vielfache", tool: .lcm, blocks: [
                "Definition:  Seien a, b ∈ ℤ.\n    Die Zahl v ∈ ℕ\u{E002}0\u{E003} heißt kleinstes gemeinsames Vielfaches von a und b, kurz kgV(a, b),\n    wenn gilt:    1. a | v  und  b | v    v ist gemeinsames Vielfaches,\n        2. a | w und b | w  ⇒  v | w    v teilt jedes gemeinsame Vielfache.",
                "Das Produkt a·b ist ein gemeinsames Vielfaches von a und b, aber nicht immer das kleinste.\n\nSatz:   kgV(a, b) =    für a, b ≠ 0      Beweis    Beispiel\nggT(a, b)\nkgV(a, 0) = 0,  denn 0 hat nur sich selbst als Vielfaches.",
                "Definition:  Man bezeichnet die Menge aller positiven Vielfachen von a ∈ ℤ mit V\u{E002}a\u{E003} .\nAlso ist V\u{E002}0\u{E003} = ∅.",
                "Für a, b ≠ 0 gilt:    kgV(a, b) ist die kleinste Zahl ∈ V\u{E002}a\u{E003} ∩ V\u{E002}b\u{E003} , und\n    V\u{E002}a\u{E003} ∩ V\u{E002}b\u{E003} = V\u{E002}kgV(a, b)\u{E003} .",
                "Damit kann man zeigen:\nSatz:     kgV(  a, kgV(b, c)  )  =  kgV(  kgV(a, b), c  )    Beweis",
            ]),
            ZTPage(id: "1.4 - kgV von mehr als 2 Zahlen", title: "kgV von mehr als 2 Zahlen", tool: .lcm, blocks: [
                "Man kann auch das kgV von mehr als 2 Zahlen definieren:\n\nDefinition:    Für k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k\u{E003} ∈ ℤ und k > 2 ist\ndie kleinste Zahl ∈ V\u{E002}1\u{E003} ∩ V\u{E002}2\u{E003} ∩ ... ∩ V\u{E002}k \u{E003},  falls alle a ≠ 0,\n0,  falls mindestens ein a = 0.\nkgV( a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003} )",
                "Satz:    Für k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k \u{E003}, a\u{E002}k+1\u{E003} ∈ ℤ und k > 2 gilt:\n\n    1.  Va\u{E002}1\u{E003} ∩ ... ∩ Va\u{E002}k\u{E003}  =  VkgV( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} )    Beweis\n         Die gemeinsamen Vielfachen sind die Vielfachen des kgV.\n         Der Beweis zeigt auch:\n         kgV( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} )  =  kgV(  kgV( a\u{E002}1\u{E003}, ..., a\u{E002}k–1\u{E003} ), a\u{E002}k\u{E003}  )\n         Man kann also das kgV von mehr als 2 Zahlen rekursiv berechnen.\n\n    2.  a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} paarweise teilerfremd  ⇒  kgV( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} ) = |a\u{E002}1\u{E003}·...· a\u{E002}k \u{E003}|    Beweis",
                "Ende des Kapitels",
            ]),
        ]))
        return ZTLesson(number: 1, title: "Ganze Zahlen", chapters: chapters)
    }
    static func lesson2() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "2.1", title: "Rechnen mit Kongruenzen", pages: [
            ZTPage(id: "2.1 - 01", title: "Algebraische Begriffe", tool: nil, blocks: [
                "algebraische Sruktur\n\n\nHalbgruppe\nMonoid    neutrales Element\nGruppe     inverses Element\n\nRing    Nullelement    Einselement\n    Nullteiler    Einheit\nKörper\nIn dieser Lektion werden einige Begriffe aus der Algebra gebraucht,\ndie Sie jeweils vor Ort oder hier gesammelt studieren können:\nIsomorphismus\ninjektiv  surjektiv  bijektiv",
            ]),
            ZTPage(id: "2.1 - Division mit Rest", title: "Division mit Rest", tool: .divRest, blocks: [
                "Dividiert man zwei ganze Zahlen, so erhält man nicht immer eine ganze Zahl,\nzum Beispiel:     \u{E002}∉\u{E003} Z.\nGanzzahlige Ergebnisse erhält man bei der Division mit Rest:",
                "Definition: Seien a, b ∈ ℤ, b > 0.\n    Als Division von a durch b mit Rest bezeichnet man die Darstellung:\n    a = q·b + r    mit q, r \u{E002}∈\u{E003} Z   und   0 ≤ r < b.\n    Dabei heißt  q  ganzzahliger Quotient und  r  Rest der Division.",
                "keine Einschränkung, denn",
                "Satz:  Ganzzahliger Quotient und Rest sind eindeutig bestimmt:  q = ⌊   ⌋  und  r = a – q·b.\nBeweis        Anmerkung",
            ]),
            ZTPage(id: "2.1 - Kongruenz", title: "Kongruenz", tool: .congruence, blocks: [
                "Definition: Sei m ∈ ℕ.\n    Zwei ganze Zahlen a und b heißen kongruent modulo m, wenn m die Differenz a – b teilt.\n    Man schreibt dann a ≡ b mod m. Die Zahl m nennt man den Modul.\n\nBegriff und Schreibweise der Kongruenz wurden von Gauß eingeführt.\n\nBeispiele:\n    · Uhrzeiten:  13 ≡ 1 mod 12,  24 ≡ 0 mod 12\n    · ungerade Zahlen:  –25 ≡ 3 mod 2",
                "Satz:   a ≡ b mod m  ⇔  a und b lassen bei Division durch m den gleichen Rest.\nBeweis",
                "    Die Kongruenz modulo m ist eine Äquivalenzrelation in ℤ, es gilt:\n    1. Reflexivität:     a ≡ a mod m  für alle a ∈ ℤ\n    2. Symmetrie:     a ≡ b mod m  ⇒  b ≡ a mod m\n    3. Transitivität:     a ≡ b mod m  ∧  b ≡ c mod m  ⇒  a ≡ c mod m",
            ]),
            ZTPage(id: "2.1 - Restklassen", title: "Restklassen", tool: .residueClass, blocks: [
                "Die Kongruenz modulo m teilt ℤ in Äquivalenzklassen ein, die man Restklassen nennt.\nDefinition:\n    Die Menge [a]m = { x ∈ ℤ | x ≡ a mod m } heißt Restklasse a modulo m, kurz: a mod m.\n    Die Zahl a bezeichnet man als Vertreter der Restklasse.",
                "ÁAlle Elemente von [a]m lassen bei Division durch m den gleichen Rest wie der Vertreter a.\nWeil sie sich von a und untereinander durch ganzzahlige Vielfache des Moduls m unterscheiden, findet man auch die Bezeichnung a+mZ =    [a]m = { x ∈ ℤ | x = a + z·m, z ∈ ℤ }.\n    ·  [1]10 = {1, 1±10, 1±2·10, 1±3·10, ...} = {1, –9, 11, –19, 21, –29, 31, ...}\n    ·  [1\u{E002}]\u{E003}2 ist die Menge aller ungeraden Zahlen.\n    ·  [0\u{E002}]\u{E003}2 ist die Menge aller geraden Zahlen.",
                "Jede Zahl kann ihre Restklasse vertreten:  a ≡ b mod m  ⇔  [a]\u{E002}m\u{E003} = [b]\u{E002}m\u{E003}\nBeispiele:  ·  [1]\u{E002}10\u{E003} = [11]\u{E002}10\u{E003}                ·  [1]\u{E002}2\u{E003} = [–1]\u{E002}2\u{E003}                ·  [0]\u{E002}12\u{E003} = [24]\u{E002}12\u{E003}",
            ]),
            ZTPage(id: "2.1 - Standardvertreter", title: "Standardvertreter", tool: .residueClass, blocks: [
                "kleinste nicht-negative,    kleinste positive,    größte negative,    absolut kleinste Vertreter\n    [0]\u{E002}4\u{E003}     =     [4]\u{E002}4\u{E003}     =     [–4]\u{E002}4\u{E003}     =     [0]\u{E002}4\u{E003}\n    [1]\u{E002}4\u{E003}     =     [1]\u{E002}4\u{E003}     =     [–3]\u{E002}4\u{E003}     =     [1]\u{E002}4\u{E003}\n    [2]\u{E002}4\u{E003}     =     [2]\u{E002}4\u{E003}     =     [–2]\u{E002}4\u{E003}     =     [2]\u{E002}4\u{E003}\n    [3]\u{E002}4\u{E003}     =     [3]\u{E002}4\u{E003}     =     [–1]\u{E002}4\u{E003}     =     [–1]\u{E002}4\u{E003}\nAm Beispiel der Restklassen modulo 4 seien einige besondere Vertreter vorgestellt:",
                "Die kleinsten nicht-negativen Vertreter heißen Standardvertreter.\nSie sind die möglichen Reste bei Division durch den Modul.\nIst x der Standardvertreter von [a]\u{E002}m\u{E003}, dann schreibt man  x = a (mod m).\nDas Ersetzen einer Zahl a durch a (mod m) heißt Reduktion mod m.",
                "Es gilt:       x = a (mod m)   ⇒   x ≡ a mod m\nDie Umkehrung ist falsch, zum Beispiel:      3 ≡ 5 mod 2,  aber  3 ≠ 5 (mod 2) = 1",
                "In vielen Programmiersprachen berechnet die Funktion mod(a, b) einen Vertreter von a mod b,\ngewöhnlich den Standard-, in manchen Sprachen den größten negativen Vertreter, falls a < 0.",
            ]),
            ZTPage(id: "2.1 - Summe, Produkt", title: "Summe und Produkt", tool: .modTables, blocks: [
                "Definition:     Die Menge aller Restklassen mod m bezeichnet man mit ℤm oder Z/m.\nℤm enthält m Restklassen, weil bei der Division durch m die Reste 0, 1, 2, ..., m – 1 auftreten.\nBeispiel:    ℤ3 = { [0], [1], [2] }\nErgibt sich der Modul aus dem Kontext, so kann man die Indizes der Restklassen weg lassen.\nIst klar, dass Restklassen gemeint sind, so kann man auch die eckigen Klammern weg lassen.",
                "  1. Die Summe zweier Restklassen ist [a] + [b] = [a+b].\n  2. Das Produkt zweier Restklassen ist [a] · [b] = [a·b].\nIn der endlichen Menge Z\u{E002}m\u{E003} kann man eine Addition + und eine Multiplikation · definieren,\nso dass (Z\u{E002}m\u{E003}, +, ·) eine algebraische Struktur ist.",
                "Satz: Diese Verknüpfungen sind wohldefiniert, das heißt:\n        Sie führen unabhängig von der Wahl der Vertreter a und b immer zum gleichen Ergebnis.\n        Aus  [a] = [a']  und  [b] = [b']  folgt  [a+b] = [a'+b']  und  [a·b] = [a'·b'].\nBeweis\nDass Wohldefiniertheit nicht selbstverständlich ist, zeigt ein Gegenbeispiel.",
            ]),
            ZTPage(id: "2.1 - Restklassenring", title: "Der Restklassenring", tool: .modTables, blocks: [
                "Satz:    Assoziativität, Kommutativität, Existenz des neutralen Elements, Invertierbarkeit und     Distributivität übertragen sich von (ℤ, +, ·) auf (Z\u{E002}m \u{E003}, +, ·).\nBeweis",
                "Satz:    Assoziativität, Kommutativität, Existenz des neutralen Elements, Invertierbarkeit und     Distributivität übertragen sich von (ℤ, +, ·) auf (Z\u{E002}m \u{E003}, +, ·).\nBeweis\nFolgerung:\n    (\u{E002}ℤm\u{E003} , +) ist eine kommutative Gruppe. Neutrales Element ist [0], invers zu [a] ist [m–a].\n    (\u{E002}ℤm\u{E003} , ·) ist eine kommutative Halbgruppe. Neutrales Element ist [1].",
                "Folgerung und Definition:    (Z\u{E002}m \u{E003}, +, ·) ist ein kommutativer Ring mit Einselement: der Restklassenring modulo m.",
            ]),
            ZTPage(id: "2.1 - Wozu mod", title: "Wozu modulo rechnen?", tool: .checkNine, blocks: [
                "prominentes Beispiel\nDem Rechnen im Restklassenring entspricht das Rechnen mit Kongruenzen.\nDa es dabei nur auf die Klassen ankommt, kann man immer die \"handlichsten\" Vertreter wählen.\n\nBeispiel:  Welchen Rest hat 13·14 bei Division durch 16?\n    Im Restklassenring modulo 16 ist [13·14] = [13]·[14] = [–3]·[–2] = [(–3)·(–2)] = [6].\n    Dem entsprechen die Kongruenzen                    13·14 ≡ (–3)·(–2) ≡ 6 mod 16.\n    Statt 13·14 dividiert man (–3)·(–2) durch 16 und erhält sofort den Rest 6.\n    Machen Sie die Probe.",
                "Das nutzt man bei der Rechenkontrolle über die Endziffern. Man rechnet modulo 10.\nBeispiel:      5461958 · 987459187 ≠ 434756195619242, denn [8]·[7] = [6].\nDas Ergebnis kann falsch sein, auch wenn die Endziffern überein stimmen.\nDie Differenz zum richtigen Ergebnis ist dann ein Vielfaches von 10.\nDie Rechenkontrolle geht auch mit anderen Moduln. Wenn die Restklassen überein stimmen, ist\ndie Differenz zum richtigen Ergebnis ein Vielfaches des Moduls.",
            ]),
            ZTPage(id: "2.1 - Quersummen", title: "Quersummen", tool: .crossSums, blocks: [
                "Für alle Exponenten z ist 10\u{E000}z\u{E001}  ≡  1 mod 3.\n10 ≡ 1 mod 3",
                "Von rechts nach links fasst man Päckchen von jeweils k Ziffern zu neuen Zahlen zusammen.\nDas Päckchen ganz links darf auch weniger als k Ziffern haben.",
                "Man gibt den Päckchen wechselnde Vorzeichen.\nDabei fängt man rechts mit + an.",
                "mit x = 5214\nJedes andere x täte es auch.",
                "Für gerade Exponenten z ist 10\u{E000}z\u{E001}  ≡  1 mod 11,\nfür ungerade z ist 10\u{E000}z\u{E001}  ≡  –1 mod 11.\n10 ≡ –1 mod 11",
                "Für alle Exponenten z ist (10\u{E000}2\u{E001})\u{E000}z\u{E001}  ≡  1 mod 11.\n10\u{E000}2\u{E001} ≡ 1 mod 11",
                "Vielleicht kennen Sie die Regel:    3 | x    ⇔     3 | Q(x) = Quersumme von x\nBeispiel:      3 | 5214, denn    3 | 5+2+1+4 = 12",
                "Im 10er-System ist  5214 =    5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}.\n10 ≡ 1 mod 3    ⇒    5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}  ≡  5+2+1+4 mod 3\n        Bei Division durch 3 lässt x den selben Rest wie Q(x).",
                "Betrachten Sie k-stufige Quersummen Q\u{E002}k\u{E003} und alternierende Quersummen Q'\u{E002}k\u{E003}:",
                "Für Teilbarkeit durch 11 gilt:    11 | x      ⇔      11 | Q'\u{E002}1\u{E003}(x)    und    11 | x      ⇔      11 | Q\u{E002}2\u{E003}(x),    denn\n10 ≡ –1 mod 11    ⇒     5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}  ≡  –5+2–1+4 mod 11\n10\u{E000}2\u{E001} ≡ 1 mod 11    ⇒     52·10\u{E000}2\u{E001} + 14·10\u{E000}0\u{E001}  ≡  52+14 mod 11\n        Bei Division durch 11 lässt x den selben Rest wie Q'\u{E002}1\u{E003}(x) und Q\u{E002}2\u{E003}(x).\nmehr Beispiele      Verallgemeinerung",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.2", title: "prime Restklassen", pages: [
            ZTPage(id: "2.2 - 01", title: "Einheiten und Nullteiler", tool: .modTables, blocks: [
                "Betrachten Sie die Gleichung      3 + x = 5.\nMan kann sie lösen, indem man 3 subtrahiert, also das Inverse von 3 addiert.\n    3 + x = 5   |  + (– 3)\n          x = 2",
                "hier bezüglich ·",
                "Betrachten Sie nun die Gleichung    3 · x = 5.\nMan kann sie lösen, indem man durch 3 dividiert, also mit dem Inversen von 3 multipliziert.\n    3 · x = 5   |  ·",
                "Man rechnet hier im Ring (Q, +, ·), denn    ∉ ℤ.\nIm Ring der ganzen Zahlen (Z, +, ·) ist 3 nicht multiplikativ invertierbar.",
                "Bezüglich Addition ist jedes Element eines Ringes invertierbar,\nbezüglich Multiplikation sind nur einige invertierbar, sie heißen Einheiten.\nIst 0 eine Einheit, so hat der Ring nur ein Element. Beweis",
                "Manche Ringe enthalten Elemente a, b ≠ 0, aber a·b = 0. Sie heißen Nullteiler und sind niemals Einheiten.",
            ]),
            ZTPage(id: "2.2 - Zm*", title: "Prime Restklassen ℤm*", tool: .units, blocks: [
                "die nicht invertierbar sind:\n(Dargestellt sind die Standardvertreter.)\nDie Elemente eines Ringes, die bezüglich Multiplikation invertierbar sind, heißen Einheiten.",
                "Beobachtung: Genau die Vertreter der Einheiten sind prim zum Modul.\nDefinition:    Die Einheiten im Restklassenring heißen prime Restklassen.\n    Sie bilden die prime Restklassengruppe modulo m, kurz Z\u{E002}m\u{E003}* oder (Z/m)*.",
                "Beobachtung: Die anderen Restklassen außer [0] sind Nullteiler.",
                "Die Einheiten haben eine\n1 in Zeile und Spalte.",
                "≠ 0, haben mehr als eine 0 in Zeile und Spalte",
            ]),
            ZTPage(id: "2.2 - prim zum Modul", title: "Prim zum Modul", tool: .units, blocks: [
                "Satz:     [a]\u{E002}m\u{E003} ist prime Restklasse  ⇔  ggT(a, m) = 1.\nBeweis\n\"⇒\"    [a]\u{E002}m\u{E003}·[b]\u{E002}m\u{E003} = [1]\u{E002}m\u{E003}   ⇒   a·b ≡ 1 mod m  ⇒  m | a·b – 1\n    ⇒     ggT(a, m) | a·b – 1\n    Außerdem:    ggT(a, m) | a\n ⇒  ggT(a, m) | 1  ⇒  ggT(a, m) = 1",
                "invertierbar bezüglich Multiplikation",
                "\"Ü\"    Sei ggT(a, m) = 1.    ⇒    Es gibt Koeffizienten x, y ∈ ℤ mit a·x + m·y = 1.\n    ⇒  a·x – 1 = –m·y    ⇒    m | a·x – 1\n    ⇒  a·x ≡ 1 mod m    ⇒    [a]\u{E002}m\u{E003}·[x]\u{E002}m\u{E003} = [1]\u{E002}m\u{E003}\n    Die Koeffizienten x und y – und damit [x\u{E002}]\u{E003}m – findet man mit dem euklidischen Algorithmus.\nDer Beweis der Gegenrichtung stützt sich auf Vielfachsummen:",
                "Auch die zweite Beobachtung lässt sich beweisen:\nSatz:     [a]\u{E002}m\u{E003} ist ein Nullteiler   ⇔   1 < ggT(a, m) < m.      Beweis",
                "Ist der Modul m eine Primzahl, so sind alle Restklassen außer [0] prime Restklassen.\nDer Restklassenring modulo einer Primzahl ist also ein Körper.",
            ]),
            ZTPage(id: "2.2 - invertieren mit Euklid", title: "Invertieren mit Euklid", tool: .inverse, blocks: [
                "Die multiplikativ Inverse [x]\u{E002}m\u{E003} zu einer Restklasse [a]\u{E002}m\u{E003}\nkann man durch Ausprobieren finden ...",
                "... oder mit Hilfe des euklidischen Algorithmus,\nindem man ggT(a, m) als Vielfachsumme darstellt:",
                "a·x ≡ 1 mod m  ⇔  a·x + m·y = 1",
            ]),
            ZTPage(id: "2.2 - Kongruenzen lösen", title: "Kongruenzen lösen", tool: .linearCongruence, blocks: [
                "Definition:     Gilt a·x ≡ b mod m für ein x\u{E002}0\u{E003} ∈ ℤ, so sagt man: x\u{E002}0\u{E003} erfüllt die Kongruenz,\n    und die Restklasse [x\u{E002}0\u{E003}]\u{E002}m\u{E003} heißt dann Lösung der Kongruenz.\nIst [a]\u{E002}m\u{E003} prime Restklasse mit [a']\u{E002}m\u{E003}·[a]\u{E002}m\u{E003} = [1]\u{E002}m \u{E003}, dann ist [a']\u{E002}m\u{E003}·[b]\u{E002}m\u{E003} die eindeutige Lösung.\nAuch sonst kann es Lösungen geben:",
                "Satz:      1. Die Kongruenz  a·x ≡ b mod m  ist lösbar  ⇔  ggT(a, m) | b.\n    2. Gibt es Lösungen zu  a·x ≡ b mod m,  dann ist ihre Anzahl = ggT(a, m).\nBeweis",
                "¡Beispiel:    4·x ≡ 6 mod 10  ist lösbar, denn ggT(4, 10) = 2 | 6.\n    Es gibt 2 Lösungen. Also kürzt man durch 2 und löst die neue Kongruenz\n    2·x ≡ 3 mod 5.\n    Deren Lösung ist [4\u{E002}]\u{E003}5 = {4 + 5·z | z ∈ Z} = {..., –6, –1, 4, 9, 14, 19, ...}.\n    Modulo 10 zerfällt diese Klasse in die beiden Klassen\n        [4]10 = {4 + 10·z | z ∈ Z} = {..., –6, 4, 14, ...}  und\n        [9]10 = {9 + 10·z | z ∈ Z} = {..., –1, 9, 19, ...}.\n    Das sind die beiden Lösungen der ursprünglichen Kongruenz 4·x ≡ 6 mod 10.",
            ]),
            ZTPage(id: "2.2 - Euler-Funktion", title: "Die Euler-Funktion", tool: .phiTable, blocks: [
                "der griechische Buchstabe Phi",
                "Die Anzahl der primen Restklassen modulo n bezeichnet man mit φ(n).\nDefinition: Euler-Funktion φ\n    Sei n ∈ ℕ. Dann ist φ(n) die Anzahl der zu n teilerfremden natürlichen Zahlen ≤ n.",
                "einige Werte der Euler-Funktion:\n  n    1    2    3    4    5    6    7    8    9    10    11    12    13    14    15    16    17    18    19    20    ...    n\n φ(n)    1    1    2    2    4    2    6    4    6     4    10     4    12     6     8     8    16     6    18     8    ...    ?",
                "Satz:  Für alle n ∈ ℕ ist n = Σ φ(d).",
                "d =     t    \u{E002}A\u{E003}t     x ∈ {1, ..., n} mit ggT(x, n) = t             ∈ {1, ...,   } mit ggT(  ,   ) = 1    φ(d)",
                "Für jedes x gibt es eine Menge A\u{E002}t\u{E003}.\nKein x ist in mehr als einer Menge A\u{E002}t\u{E003}.\nEs gibt n verschiedene x.",
                "^At enthält alle x ∈ {1, 2, ..., n} mit ggT(x, n) = t.\nDas sind genau die x ∈ {1, 2, ..., n}, für die     teilerfremd zu     ist,\ndabei ist     ∈ {1, 2, ...,   }.\nGenau φ(   ) Zahlen ∈ {1, 2, ...,   } sind teilerfremd zu    .",
                "Beweis:  Σ φ(d) = n       mit φ(n) = Anzahl der zu n teilerfremden natürlichen Zahlen ≤ n.\n^Für jeden Teiler t von n sei At die Menge aller x ∈ {1, 2, ..., n} mit ggT(x, n) = t.\n⇒    Σ |\u{E002}A\u{E003}t|  =  n.     Denn zu jedem x gibt es genau ein t = ggT(x, n).",
                "Außerdem gilt:   ggT(x, n) = t  ⇔  ggT(   ,   ) = 1",
                "⇒      |A\u{E002}t\u{E003}|  =  φ(   )\n⇒      n = Σ    |A\u{E002}t\u{E003}|  =  Σ φ(   )",
                "Setze d =    = Komplementärteiler zu t, dann folgt die Behauptung.",
            ]),
            ZTPage(id: "2.2 - Berechnung Euler 1", title: "Berechnung der Euler-Funktion (1)", tool: .phi, blocks: [
                "Folgende Werte der Euler-Funktion kann man sofort angeben:\n\nSatz:      Für Primzahlen p ist  φ(p) = p – 1.\nBeweis:     Alle natürlichen Zahlen < p sind teilerfremd zu p.\nBeispiele:      φ(2) = 1,    φ(5) = 4,    φ(11) = 10,    φ(97) = 96",
                "Beispiele:       φ(8) = φ(2\u{E000}3\u{E001}) = 1·2\u{E000}2\u{E001} = 4\n    φ(81) = φ(3\u{E000}4\u{E001}) = 2·3\u{E000}3\u{E001} = 54\n    φ(121) = φ(11\u{E000}2\u{E001}) = 10·11\u{E000}1\u{E001} = 110\nSatz:    Für Primzahlpotenzen p\u{E000}a\u{E001} ist  φ(p\u{E000}a\u{E001}) = p\u{E000}a\u{E001} – p\u{E000}a–1\u{E001} = (p – 1)·p\u{E000}a–1\u{E001}.\nBeweis:    Jede p-te Zahl ∈ {1, 2, ..., \u{E000}p\u{E001}a} ist durch p teilbar, das sind       = \u{E000}pa–\u{E001}1  Zahlen.\n⇔pa\nanderer Beweis\n    Die Anzahl der zu  p\u{E000}a\u{E001}  teilerfremden Zahlen ist also  p\u{E000}a\u{E001} – p\u{E000}a–1\u{E001}.",
                "Und wenn eine Zahl keine Primzahlpotenz ist?\nFür diesen Fall muss man ein bisschen weiter ausholen.",
            ]),
            ZTPage(id: "2.2 - Uhren verstellen", title: "Uhren verstellen", tool: .crt, blocks: [
                "Unter jeder Uhr steht ein Bruch:\nDer Zähler zeigt die aktuelle Stunde,\nder Nenner zeigt die Größe des Zifferblattes.\n\nDie Uhren lassen sich nur gemeinsam verstellen,\nund zwar alle um die gleiche Stundenzahl.",
                "Verstellen Sie diese Uhren:",
                "Uhren in Schritten verstellen:",
            ]),
            ZTPage(id: "2.2 - Chinesischer Restsatz", title: "Der Chinesische Restsatz", tool: .crt, blocks: [
                "Kongruenzen, für die man gemeinsame Lösungen sucht",
                "Das simultane Uhrenverstellen demonstriert den Chinesischen Restsatz:\n\nSatz:    Seien     m\u{E002}1\u{E003} , m\u{E002}2\u{E003} , ... , m\u{E002}k\u{E003} ∈ ℕ  paarweise teilerfremd,\n         a\u{E002}1\u{E003} ,  a\u{E002}2\u{E003} , ... ,  a\u{E002}k\u{E003} ∈ ℤ,     n = m\u{E002}1\u{E003} · m\u{E002}2\u{E003} · ... · m\u{E002}k\u{E003} ,\n    dann löst genau eine Restklasse x\u{E002}0\u{E003} mod n die simultane Kongruenz\n        x ≡ a\u{E002}1\u{E003} mod m\u{E002}1\u{E003} ,   x ≡ a\u{E002}2\u{E003} mod m\u{E002}2\u{E003} ,  ... ,   x ≡ a\u{E002}k\u{E003} mod m\u{E002}k\u{E003} .\nBeweis",
                "Die Zahlen  m\u{E002}1\u{E003}, ..., m\u{E002}k\u{E003}  entsprechen den Uhren.\nDie Restklassen  a\u{E002}1\u{E003} mod m\u{E002}1\u{E003}, ...,  a\u{E002}k\u{E003} mod m\u{E002}k\u{E003}  entsprechen den Vorgabezeiten.\nZu jedem x mod n gibt es eine Kombination ( x mod m\u{E002}1 \u{E003}, ... ,  x mod m\u{E002}k\u{E003} ) von Uhrzeiten.",
                "Jede dieser Kombinationen ist ein Element von    ℤm\u{E002}1\u{E003} ×   ...   ×  ℤm\u{E002}k\u{E003} .\nDer Chinesische Restsatz besagt nun, dass es auch umgekehrt\nzu jeder solchen Kombination genau eine Restklasse x mod n gibt.\nEs gibt also eine bijektive Abbildung f von Zn nach  ℤm\u{E002}1\u{E003}× ... ×  ℤm\u{E002}k\u{E003}\u{E000} .\u{E001}\nBeispiel",
                "die Menge aller Restklassen mod n",
            ]),
            ZTPage(id: "2.2 - Zerlegung Ring", title: "Zerlegung des Restklassenrings", tool: .crtMap, blocks: [
                "Sind R\u{E002}1\u{E003}, R\u{E002}2\u{E003}, ... , R\u{E002}k\u{E003} Ringe, dann bezeichnet man als ihr direktes Produkt die Menge aller Tupel\n(r\u{E002}1\u{E003}, r\u{E002}2\u{E003}, ... , r\u{E002}k\u{E003}) ∈ R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} mit komponentenweiser Addition und Multiplikation.\nBeispiel",
                "Das direkte Produkt ist wieder ein Ring. Sind die R\u{E002}i\u{E003} kommutative Ringe mit Einselementen e\u{E002}i\u{E003} , 1≤ i ≤ k, so ist das direkte Produkt ein kommutativer Ring mit Einselement (e\u{E002}1\u{E003}, ... , e\u{E002}k\u{E003}).",
                "Satz:    Seien  m1 , m2 , ... , mk ∈ ℕ paarweise teilerfremd,  n = m1 · m2 · ... · mk .  Dann ist\n    die Abbildung       f:  Zn   →   ℤm1×  ℤm2× ... ×  ℤmk     mit\n    ein Isomorphismus von Ringen.\nBeweis        Beispiel\nf( [x]n ) = ( [x]m1 ,  [x]m2 , ... ,  [x]mk )",
                "Ist R @ R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} , so nennt man R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} eine Zerlegung von R.\nMan kann also Z\u{E002}n\u{E003} zerlegen und statt in einem großen in vielen kleinen Ringen rechnen;\ndas Ergebnis-Tupel übersetzt man mit dem Chinesischen Restsatz zurück nach Z\u{E002}n\u{E003} .",
            ]),
            ZTPage(id: "2.2 - Berechnung Euler 2", title: "Berechnung der Euler-Funktion (2)", tool: .phi, blocks: [
                "Dank der Zerlegung des Restklassenringes kann man die Euler-Funktion auch\nfür Produkte teilerfremder Zahlen berechnen – sofern man ihre Primfaktoren kennt:\nWiederholung:  Für Primzahlpotenzen  p\u{E000}a\u{E001}  ist  φ(p\u{E000}a\u{E001}) = (p – 1)·p\u{E000}a–1\u{E001}.",
                "Satz:     Sei  n = m\u{E002}1 \u{E003}· m\u{E002}2 \u{E003}· ... · m\u{E002}k \u{E003} mit paarweise teilerfremden Zahlen  m\u{E002}1 \u{E003}, m\u{E002}2 \u{E003}, ... , m\u{E002}k\u{E003} ∈ ℕ.\n    Dann ist      φ(n) = φ(m\u{E002}1\u{E003}) · φ(m\u{E002}2\u{E003}) · ... · φ(m\u{E002}k\u{E003}).\nBeweis",
                "Ist n = ∏ p\u{E000}e(p)\u{E001}    die Primfaktorzerlegung von n, wobei p je e(p) mal in n vorkommt, dann ist\n\nφ(n) = P φ(p\u{E000}e(p)\u{E001} ).   Setzt man hier die Formel für Primzahlpotenzen ein, so ergibt sich die\nFormel zur Euler-Funktion:\nφ(n) = P (p – 1)·p\u{E000}e(p)–1A\u{E001}\nandere Darstellungen",
            ]),
            ZTPage(id: "2.2 - Fermat, Euler", title: "Die Sätze von Fermat und Euler", tool: .eulerFermat, blocks: [
                "Euler verallgemeinerte einen Satz von Fermat zu einem der wichtigsten Sätze der Zahlentheorie:\n\nSatz:    \"Euler-Fermat\"\n    Sei n ∈ ℕ, a teilerfremd zu n. Dann ist  a\u{E000}φ(n)\u{E001} ≡ 1 mod n.\nIllustration    Beweis",
                "Den Spezialfall mit φ(p) = p – 1 für Primzahlen p kannte schon Fermat:\nSatz:    \"kleiner Fermat\"\n    Sei p eine Primzahl, a teilerfremd zu p. Dann ist  a\u{E000}p–1\u{E001} ≡ 1 mod p.",
                "Folgerung:  Sei n ∈ ℕ, a teilerfremd zu n. Dann gilt:\n    b ≡ c mod φ(n)  ⇒  a\u{E000}b\u{E001} ≡ a\u{E000}c\u{E001} mod n    Beweis\nDie Umkehrung gilt nicht, z.B.  3\u{E000}2\u{E001} ≡ 3\u{E000}4\u{E001} mod 8,\naber 2 ≡ 4 mod 4.",
                "Beim Rechnen mit primen Restklassen modulo n\nkann man also ihre     ·  Vertreter     modulo n,\n    ·  Exponenten     modulo φ(n)    beliebig ersetzen.     Beispiel 1\n            Beispiel 2",
            ]),
            ZTPage(id: "2.2 - schnelle Potenz", title: "Schnelles Potenzieren", tool: .squareMultiply, blocks: [
                "    ⌊Hälfte⌋     (97)    48    24    12    6     3     1    0 \n    Rest      1    0    0    0     0     1    1",
                "Vergleichen Sie die Anzahl der Multiplikationen (einschließlich Quadraturen) mit dem Exponenten.",
                "Manchmal helfen keine Tricks, man muss eine Potenz ausrechnen. Dann aber geschickt:\n    Quadriere die Basis \"mehrmals\", dadurch entsteht \"Baumaterial\". \n    Wähle das richtige Baumaterial aus und setze es zur Potenz zusammen.\nDas wird am Beispiel  3\u{E000}97\u{E001} erklärt:",
                "Quadriere 3 mehrmals:    3,    9,    81,    81\u{E000}2\u{E001},    (81\u{E000}2\u{E001})\u{E000}2\u{E001},    ((81\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001},    (((81\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001} ...\nNun gilt:  (a\u{E000}k\u{E001})\u{E000}2\u{E001} = a\u{E000}2·k\u{E001}\nDas Baumaterial ist also:    3\u{E000}1\u{E001},    3\u{E000}2\u{E001},    3\u{E000}4\u{E001},    3\u{E000}8\u{E001},    3\u{E000}16\u{E001},    3\u{E000}32\u{E001},    3\u{E000}64\u{E001} ...",
                "Was man davon braucht, zeigt die Zerlegung des Exponenten in verschiedene Zweierpotenzen:\n    97  =      1 +    0 +    0  +    0   +     0    +     32     +    64\nAlso ist      3\u{E000}97\u{E001} =     3\u{E000}1\u{E001} ·    1  ·    1   ·    1   ·    1     ·    3\u{E000}32\u{E001}    ·     3\u{E000}64\u{E001}.\ngeschickt",
                "Die Zerlegung des Exponenten entspricht seiner Binärdarstellung 1100001 rückwärts,\nman findet sie durch fortgesetztes Halbieren mit Rest. Damit ergibt sich folgender\nAlgorithmus:      Potenz := 1\n    Solange Exponent > 0:    Exponent := ⌊Exponent / 2⌋\n                    Wenn Rest = 1, dann  Potenz := Potenz · Basis\n                     Basis := Basis\u{E000}2\u{E001}",
            ]),
            ZTPage(id: "2.2 - modulare Potenz", title: "Modulares Potenzieren", tool: .squareMultiply, blocks: [
                "durch den Standardvertreter ersetzt",
                "Basis, Quadrate und (in Klammern) Zwischenergebnisse werden sofort reduziert.",
                "Die Basis ist nicht invertierbar.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.3", title: "Untergruppen", pages: [
            ZTPage(id: "2.3 - 01", title: "Gruppen", tool: nil, blocks: [
                "€Der Kürze halber werden ab hier\n\n·  bekannte Gruppen ohne Verknüpfung angegeben,\n    zum Beispiel  ℤ statt (ℤ, +),\n\n·  Restklassen bei bekanntem Modul durch Vertreter dargestellt,\n    zum Beispiel  \u{E002}Z1\u{E003}0* = {1, 3, 7, 9},\n\nwenn der Sinn aus dem Zusammenhang klar wird.\nDie ausführliche Schreibweise kann noch hier und da der Verdeutlichung dienen.",
            ]),
            ZTPage(id: "2.3 - |G|", title: "Ordnung einer Gruppe, Untergruppen", tool: .order, blocks: [
                "Definition:  Die Anzahl der Elemente einer Gruppe G heißt Ordnung der Gruppe, kurz |G|.\nBeispiele:    ·  ℤ    hat unendliche Ordnung.\n    ·  Z\u{E002}10\u{E003}    hat die Ordnung 10.    ·  Z\u{E002}10\u{E003}*   hat die Ordnung φ(10) = 4.",
                "¼Definition:    Sei (G, *) eine Gruppe, U ⊆ G.\n    Ist (U, *) eine Gruppe, dann bezeichnet man sie als Untergruppe von (G, *).\nBeispiele:    ·  In Z bilden die geraden Zahlen eine Untergruppe.\n    ·  Das neutrale Element und G selbst sind die so genannten trivialen Untergruppen.\n    ·  Die Untergruppen in ℤ8* sind: {1}, {1, 3}, {1, 5}, {1, 7}, Z8* selbst.",
                "Satz:    Sei (G, *) eine Gruppe, U ⊆ G, U ≠ ∅.\n    Ist U endlich und abgeschlossen bezüglich *,\n    dann ist (U, *) eine Untergruppe von (G, *).    Beweis\n\nBeachte:    Abgeschlossenheit allein reicht nicht, so ist (ℕ\u{E002}0\u{E003}, +) keine Untergruppe von (ℤ, +).",
            ]),
            ZTPage(id: "2.3 - ord(a)", title: "Ordnung eines Elements", tool: .order, blocks: [
                "Nach dem Satz von Euler-Fermat gilt für alle a ∈ Z\u{E002}m\u{E003}*:  a\u{E000}φ(m)\u{E001} = 1.\nDas kann man erweitern:",
                "Satz:      Sei G eine endliche Gruppe mit neutralem Element e.\n        Dann gilt für alle a ∈ G:      a\u{E000}|G|\u{E001} = e.\nBeispiel:    In Z\u{E002}10\u{E003} gilt:  [2]\u{E000}10\u{E001} = [2]+[2]+[2]+[2]+[2]+[2]+[2]+[2]+[2]+[2] = [20] = [0] = e.\nBeweis:      Ersetze im Beweis zu Euler-Fermat Z\u{E002}m\u{E003}* durch G,  φ(m) durch |G| usw.",
                "Es geht hier auch mit kleinerem Exponenten:\n[2]\u{E000}5\u{E001} = [2]+[2]+[2]+[2]+[2] = [10] = [0] = e.",
                "Definition:    Sei G eine Gruppe mit neutralem Element e, a ∈ G.\n    Die kleinste Zahl n ∈ ℕ mit a\u{E000}n\u{E001} = e heißt Ordnung von a in G, kurz ord(a).\n    Existiert keine solche Zahl, so heißt die Ordnung von a in G unendlich.\nBeispiele:    ·  In ℤ ist ord(2) = ∞.\n    ·  In Z\u{E002}10\u{E003} ist ord(2) = 5.    ·  In Z\u{E002}10\u{E003}* ist ord(9) = 2.",
                "wenn G bekannt ist",
            ]),
            ZTPage(id: "2.3 - ord( Potenz )", title: "Ordnung einer Potenz", tool: .order, blocks: [
                "Sei G eine Gruppe mit neutralem Element e, a \u{E000}∈\u{E001} \u{E000}G, z\u{E001} \u{E000}∈\u{E001} \u{E000}Z und ord(a)\u{E001} \u{E000}∈\u{E001} ℕ. Dann gilt:\nSatz:    a\u{E000}z\u{E001} = e  ⇔  ord(a) | z\n    \"Potenz neutral  ⇔  Ordnung der Basis teilt Exponent\"    Beweis\nBeispiel",
                "Folgerungen:\n    1. Wegen    a\u{E000}|G|\u{E001} = e   gilt:   ord(a) teilt |G|.\n\"Element-Ordnung teilt Gruppen-Ordnung.\"\n\n    2. Wegen    a\u{E000}x–y\u{E001} = e  ⇔  ord(a) | (x–y)     gilt:\n        a\u{E000}x\u{E001} = a\u{E000}y\u{E001}  ⇔  x ≡ y mod ord(a)    Beispiel\nin endlichen Gruppen",
                "ggT(a, z)\nord(a\u{E000}z\u{E001})\nSatz:\nBeispiel\nKennt man die Ordnung von a, so erhält man leicht die Ordnung jeder Potenz von a:\nUmit a = ord(a)",
            ]),
            ZTPage(id: "2.3 - Erzeugnis", title: "Erzeugnis, zyklische Gruppen", tool: .order, blocks: [
                "/Definition:    Sei G eine Gruppe.\n    ·  Für jedes a ∈ G heißt <a> = {\u{E000}a\u{E001}z | z ∈ Z} das Erzeugnis von a.\n        Man sagt: a erzeugt <a>, a ist Erzeuger oder erzeugendes Element von <a>.\n    ·  Gibt es ein a ∈ G mit <a> = G, dann heißt G zyklisch.\nManche Gruppen kann man durch Potenzieren aus einem ihrer Elemente erzeugen:",
                "…Beispiele:    ·  ℤ ist zyklisch mit den Erzeugern 1 und –1.\n        Die geraden Zahlen sind <2> = <–2> = {2·z | z ∈ Z}\u{E002}.\u{E003}\n    ·  Die Erzeugnisse in ℤ8* sind:     <1> = {1},",
                "·Satz:    Jedes Erzeugnis ist eine Untergruppe.     Beweis\nDie Umkehrung des Satzes ist falsch, denn zum Beispiel\n    ℤ8* ist nicht zyklisch, aber Untergruppe von sich selbst,\n    Z20* hat die nicht-zyklische Untergruppe {1, 9, 11, 19}.",
            ]),
            ZTPage(id: "2.3 - Lagrange", title: "Der Satz von Lagrange", tool: .order, blocks: [
                "Satz:     Sei G eine Gruppe, a ∈ G, dann gilt:\n        |<a>| = ord(a)    Beweis\nJedes Element einer Gruppe erzeugt eine Untergruppe.\nDie Ordnung dieser Untergruppe ist nun gerade die Ordnung des erzeugenden Elements.",
                "In endlichen Gruppen gilt:    ord(a)  teilt  |G|.\nFolgerung für endliche Gruppen:     |<a>|  teilt  |G|.\n\"Erzeugnis-Ordnung teilt Gruppen-Ordnung.\"",
                "Lagrange gelang folgende Verallgemeinerung:\nSatz von Lagrange:      Ist U ist Untergruppe einer endlichen Gruppe G, dann gilt:              |U| teilt |G|.    Beweis\n\"Untergruppen-Ordnung teilt Gruppen-Ordnung.\"\nBeachte:     Lagrange sagt nicht, es müsse zu jedem Teiler von |G| eine Untergruppe geben.",
            ]),
            ZTPage(id: "2.3 - ord(a) berechnen", title: "ord(a) berechnen", tool: .order, blocks: [
                "Sei G eine endliche Gruppe mit neutralem Element e, a ∈ G.\nBei der Bestimmung von ord(a) kommen nur die Teiler von |G| in Betracht.\nGesucht ist der kleinste Teiler d von |G|, so dass a\u{E000}d\u{E001} = e.",
                "Weil die Teiler aus den Primteilern von |G| bestehen,\nhilft die Kenntnis der Primfaktorzerlegung von |G|.\nMan fängt an mit d = |G| und verkleinert d so lange wie möglich:",
                "Algorithmus:     1. d := |G|\n    2. Nimm einen Primteiler p von |G|, der noch nicht dran war.    3. Wenn a\u{E000}d/p\u{E001} = e, dann        d := d / p         Wenn p öfter in |G| vorkommt, als er dran war, dann gehe zu 3.    4. Wenn noch nicht alle Primteiler dran waren, dann gehe zu 2.    5. Ausgabe: ord(a) = d.",
                "Die Frage, ob a ein Erzeuger ist, kann der Algorithmus schneller beantworten, denn\na erzeugt die Gruppe  ⇔  ord(a) = |G|.\nSobald also der Algorithmus d verkleinern kann, kann a kein Erzeuger mehr sein.\n a ist kein Erzeuger von G.",
            ]),
            ZTPage(id: "2.3 - zyklisch iso", title: "Zyklische Gruppen sind isomorph", tool: .order, blocks: [
                "·Beispiele:    ·  (ℤ, +) @ (<2>, +)  mit f(x) = 2·x\n    ·  (\u{E002}Z4\u{E003} , +) @ (ℤ5*, ·)  mit f( [x] ) = [2\u{E000}]\u{E001}x , denn ℤ5* = <[2]> = {[2], [4], [3], [1]}\nJedes Erzeugnis ist eine zyklische Gruppe und umgekehrt, und es gilt:\nSatz:    Jede zyklische Gruppe ist isomorph zu einer Restklassengruppe Z\u{E002}n\u{E003} oder zu ℤ.\nBeweis",
                "Tabellen zyklischer Gruppen\nkann man so anordnen, dass\nin allen steigenden Diagonalen\njeweils gleiche Elemente stehen.",
                "Das nächste Elemente der Kopfzeile soll immer das Element links darunter sein.\nWenn das nicht geht, fangen Sie die Kopfzeile mit einem anderen Element an.",
                "kann man gar nicht anders als verlangt anordnen.",
            ]),
            ZTPage(id: "2.3 - zyklisch Sätze", title: "Sätze über zyklische Gruppen", tool: nil, blocks: [
                "¯Dank Isomorphie lernt man aus ℤ und ℤn alles über zyklische Gruppen.\n\nDie Untergruppen von ℤ sind <a> = <–a> = {0, ±a, ±2·a, ±3·a, ...} mit a ∈ ℤ.\nFür a ≠ 0 ist <a> unendlich und isomorph zu ℤ mit f(x) = a·x.\nDagegen ist <0> = {0} endlich und isomorph zu Z1.",
                "In Z\u{E002}n\u{E003} gelten folgende Sätze:\nSatz:  <a> = <ggT(a, n)>      Beweis\nSatz:  Zu jedem Teiler d von n gibt es genau eine zyklische Untergruppe: <d>    Beweis\nSatz:  Zu jedem Teiler d von n gibt es genau φ(d) Elemente der Ordnung d.    Beweis\nSatz:  Alle Untergruppen sind zyklisch.    Beweis\nUm die Sätze zu übertragen auf zyklische Gruppen G mit Erzeuger g, ersetzt man n durch |G|\nund die Erzeugnisse < x > durch < g\u{E000}x \u{E001}>.",
            ]),
            ZTPage(id: "2.3 - pos Erz", title: "Positives Erzeugnis", tool: .order, blocks: [
                "In einer Halbgruppe muss es weder ein neutrales, noch invertierbare Elemente geben.\nAber Potenzen mit positiven Exponenten sind immer möglich.\n\nDefinition:  Sei H eine Halbgruppe, h ∈ H.\n    Als positives Erzeugnis von g bezeichnet man <h\u{E000}>\u{E001}+ = {hn | n ∈ ℕ}.",
                "Satz:      Sei H eine Halbgruppe, h ∈ H, n ∈ ℕ.\n    h\u{E000}n\u{E001} = h für n > 1  ⇔  <h>\u{E000}+\u{E001} ist eine Gruppe.    Beweis\nDas positive Erzeugnis kann eine Gruppe sein.",
                "Beispiele:    ·  In H = (ℤn , ·) bildet <0>+ = {0} eine Gruppe mit neutralem Element 0.\n    ·  In H = (Z\u{E002}6\u{E003} , ·) bildet <2>\u{E000}+\u{E001} = {2, 4} eine Gruppe mit neutralem Element 4.\n    Beide Male ist <h>+ keine Untergruppe von H, denn H ist keine Gruppe.\nJede Gruppe <h>\u{E000}+\u{E001} der Ordnung n ist zyklisch und damit isomorph zu Z\u{E002}n\u{E003}.\nIn <h>\u{E000}+\u{E001} kann es ein neutrales Element geben, das in H nicht neutral ist,\nund eben solche invertierbaren Elemente.",
            ]),
            ZTPage(id: "2.3 - sterne", title: "Erzeugnisse als Sterne", tool: .order, blocks: [
                "Betrachten Sie positive Erzeugnisse <a>\u{E000}+\u{E001} von Restklassen modulo\n\nVerknüpfung:",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.4", title: "primitive Restklassen", pages: [
            ZTPage(id: "2.4 - 01", title: "Primitive Restklassen", tool: .primitiveRoots, blocks: [
                "Nun wird untersucht, welche primen Restklassengruppen zyklisch sind.\n\nBeispiele:    ·  Z\u{E002}8\u{E003}* = {1, 3, 5, 7} ist nicht zyklisch.\n    ·  Z10* = {1, 3, 7, 9} ist zyklisch mit den Erzeugern 3 und 7.",
                "Definition:    ·  Eine prime Restklasse, die Z\u{E002}m\u{E003}* erzeugt, heißt primitive Restklasse mod m.\n    ·  Ein Vertreter einer primitiven Restklasse mod m heißt Primitivwurzel mod m.",
                "Beachte:    Es gibt prime Restklassen, die nicht primitiv sind.\n\nWeil die Ordnung eines Elements die Ordnung seines Erzeugnisses ist,\ngilt:  Die Ordnung einer primitiven Restklasse mod m ist φ(m).",
            ]),
            ZTPage(id: "2.4 - Polynome", title: "Polynome", tool: nil, blocks: [
                "Für den ersten Schritt auf der Suche nach primitiven Restklassen braucht man Polynome:\n\nDefinition:     Sei R ein kommutativer Ring mit Einselement 1 ≠ 0.\n    Ein Polynom vom Grad n ist eine Funktion f: R→R der Form\nf(x) = a\u{E002}0\u{E003} + a\u{E002}1\u{E003}·x +...+ a\u{E002}n\u{E003}·x\u{E000}n\u{E001}      mit      a\u{E002}0 \u{E003},..., a\u{E002}n\u{E003} ∈ R   und   a\u{E002}n \u{E003}≠ 0.\n    \u{E002}Ein b\u{E003} \u{E002}∈\u{E003} R heißt Nullstelle des Polynoms f, wenn f(b) = 0 ist.",
                "Mit Hilfe einer Nullstelle kann man ein Polynom als Produkt darstellen:\nSatz:     \"Ausklammern von Nullstellen\"\n    Sei f ein Polynom vom Grad n und b eine Nullstelle von f.\n    Dann gibt es ein Polynom g vom Grad n–1, so dass f(x) = (x–b)·g(x) für alle x ∈ R.\n\nBeispiel    Beweis",
            ]),
            ZTPage(id: "2.4 - eindeut Fakt", title: "Eindeutige Faktorisierung", tool: nil, blocks: [
                "Die prime Restklassengruppe ℤ8* enthält vier Elemente: {1, 3, 5, 7}.\nDie Ordnung jedes Elementes ist ≤ 2, denn:\n1\u{E000}2\u{E001} ≡ 1 mod 8,   3\u{E000}2\u{E001} ≡ 1 mod 8,   5\u{E000}2\u{E001} ≡ 1 mod 8,   7\u{E000}2\u{E001} ≡ 1 mod 8.\nDeshalb sind alle vier Elemente Nullstellen des Polynoms x\u{E000}2\u{E001} – 1.",
                "Je nachdem, welche Nullstelle man ausklammert, erhält man:\n    ·  (x – 1)·(x – 7)  =  x\u{E000}2\u{E001} –8x + 7   ≡   x\u{E000}2\u{E001} – 1 mod 8, oder\n    ·  (x – 3)·(x – 5)  =  x\u{E000}2\u{E001} –8x + 15  ≡  x\u{E000}2\u{E001} – 1 mod 8.",
                "Man kann das Polynom also nicht auf eindeutige, sondern auf zweierlei Art in Faktoren zerlegen: Die Faktoren der einen Zerlegung haben Nullstellen, die die Faktoren der anderen nicht haben.\nDas ist nur möglich, weil Z\u{E002}8\u{E003} kein Körper ist. Denn es gilt:",
                "Satz:  In einem Körper hat jedes Polynom eine eindeutige Faktorzerlegung.    Beweis",
                "Satz:  In einem Körper hat jedes Polynom n-ten Grades höchstens n Nullstellen.    Beweis\nFür die Anzahl der Nullstellen gilt damit:",
            ]),
            ZTPage(id: "2.4 - mod p zyklisch", title: "ℤp* ist zyklisch", tool: .primitiveRoots, blocks: [
                "Die Gruppe der Einheiten eines Ringes R nennt man Einheitengruppe R*.\nSo ist Z\u{E002}n\u{E003}* die Einheitengruppe des Restklassenringes Z\u{E002}n\u{E003}.\nDie Einheitengruppe K* eines Körpers K mit n Elementen hat immer die Ordnung n – 1,\nweil alle Elemente außer der Null Einheiten sind.",
                "Satz:    Sei K ein endlicher Körper mit n Elementen, sei d ∈ ℕ mit d | n – 1.\n    Dann haben in der Einheitengruppe K* genau φ(d) Elemente die Ordnung d.\nBeispiel    Beweis",
                "    Da n – 1 ein Teiler von sich selbst ist, haben φ(n–1) Elemente in K* die Ordnung n – 1.\n    Diese Elemente erzeugen K*. Also ist K* zyklisch.",
                "    Ist p eine Primzahl, so ist Z\u{E002}p\u{E003}* zyklisch, weil dann Z\u{E002}p\u{E003} ein Körper ist.",
                "Anmerkung:  Der obige Satz gilt für jede endliche zyklische Gruppe.",
            ]),
            ZTPage(id: "2.4 - zyklisch komplett", title: "Wann ist ℤm* zyklisch?", tool: .primitiveRoots, blocks: [
                "    1. (Z/2\u{E000}n\u{E001})* ist genau dann zyklisch, wenn n < 3.    Beweis\n    2. Für teilerfremde Zahlen u, v > 2 ist (Z/u·v)* nicht zyklisch.    Beweis\n    3. Sei p eine Primzahl.\n        ·  Es gibt eine primitive Restklasse g mod p mit g\u{E000}p–1\u{E001} ≠ 1 mod p\u{E000}2\u{E001}.\n        ·  Ist p > 2, dann erzeugt eine Primitivwurzel von (Z/p)* auch (Z/p\u{E000}2\u{E001})*.    Beweis\n    Für Primzahlen p > 2 gilt:\n    4. Es gibt eine primitive Restklasse g mod p mit gp\u{E000}n–2\u{E001}·(p–1)  \u{E002}≠\u{E003}  \u{E002}1 mod p\u{E003}n .    Beweis\n    5. Eine Primitivwurzel von (Z/p)* erzeugt auch (Z/p\u{E000}n\u{E001})*.    Beweis\n    6. (Z/2·p\u{E000}n\u{E001})* ist zyklisch.      Beweis\nFazit:  (Z/m)* ist genau dann zyklisch, wenn m eine der folgenden Zahlen ist:\n1, 2, 4, p\u{E000}n\u{E001}, 2·p\u{E000}n\u{E001}  mit einer ungeraden Primzahl p\nHier wird die Schreibweise Z/m statt Z\u{E002}m\u{E003} verwendet.\nAbkürzung:  Ist a eine Primitivwurzel mod m, dann sagt man: a erzeugt (Z/m)*.",
            ]),
            ZTPage(id: "2.4 - finden", title: "Primitive Restklassen finden", tool: .primitiveRoots, blocks: [
                "Ende des Kapitels",
                "Primitive Restklassen mod m findet man durch Ausprobieren:\nMan wählt eine prime Restklasse x und prüft, ob ord(x) = φ(m).\nDabei hilft der Algorithmus zur Berechnung der Element-Ordnung, den man immer stoppt,\nBeispiel:\n⊂sobald klar ist, dass ord(x) < φ(m); dann prüft man sofort die nächste prime Restklasse.",
                "    Primteiler von φ(m):  {{}\nMan potenziert die Restklassen mit den Komplementärteilern der Primteiler von φ(m):",
            ]),
        ]))
        return ZTLesson(number: 2, title: "Restklassen", chapters: chapters)
    }
    static func lesson3() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "3.1", title: "Primzahlen finden", pages: [
            ZTPage(id: "3.1 - 01", title: "Primzahlen finden", tool: .sieve, blocks: [
                "Es gibt zwar unendlich viele Primzahlen, aber sie sind umso dünner gesät, je höher man steigt.\nLassen Sie ein Intervall von 20000 Zahlen durchsieben, dessen Obergrenze Sie eingeben:",
                "¬{{, .., {} enthält { Primzahlen.",
                "Primzahlsatz: Unterhalb der Schranke x liegen etwa          Primzahlen, wenn x sehr groß ist. \nln xA",
            ]),
            ZTPage(id: "3.1 - Mersenne, Fermat", title: "Mersenne- und Fermatzahlen", tool: .mersenneFermat, blocks: [
                "Ein alter Alchimistentraum der Mathematiker ist der, Primzahlen herzustellen mit einer Formel, die beliebig viele Primzahlen \"ausspuckt\".\n\nBeispiele ähnlicher Formeln:\n ·    Euler:  x\u{E000}2\u{E001} – x + 41  ergibt Primzahlen für x = 0, 1, 2, ..., 40.",
                " ·      Mersenne (1588-1648):  M\u{E002}n\u{E003} = 2\u{E000}n\u{E001} – 1\n    Diese so genannten Mersenne-Zahlen bestehen im Zweiersystem nur aus Einsen:  111...111\n    Ist 2\u{E000}n\u{E001} – 1 Primzahl, dann ist auch n Primzahl. Beweis\n    Die Umkehrung gilt nicht, zum Beispiel:  2\u{E000}11\u{E001} – 1 = 2047 = 23·89\n    In den letzten Jahren wurden etliche Mersenne-Primzahlen entdeckt.",
                " ·      Fermat:  F\u{E002}n\u{E003} = 2\u{E000}2\u{E001}  + 1\n    Diese so genannten Fermat-Zahlen sehen im Zweiersystem so aus:  100...001\n    Ist 2\u{E000}k\u{E001} + 1 Primzahl, dann ist k eine Zweierpotenz. Beweis\n    Fermat-Primzahlen gibt es wahrscheinlich nur für n = 0, 1, 2, 3 und 4.\n    Dass F\u{E002}5\u{E003} zusammengesetzt ist, hat Euler bewiesen.",
            ]),
            ZTPage(id: "3.1 - Tests", title: "Primzahltests", tool: .trialDivision, blocks: [
                "Kann man Primzahlen schon nicht beliebig per Formel konstruieren, so will man wenigstens entscheiden können, ob eine vorgelegte Zahl n eine Primzahl ist.",
                "Das einfachste Verfahren ist die Probedivision:\nMan dividiert n durch alle Primzahlen 2, 3, 5, 7, 11, ..., um zu sehen, ob ein Rest bleibt.\nHat man bis zur Wurzel von n keinen Teiler gefunden, so ist n eine Primzahl.",
                "Die Primzahlen, durch die man dividiert, liefert zum Beispiel das Sieb des Eratosthenes.\nAllerdings stößt die Probedivision mit wachsendem n schnell an Grenzen:\n  1. Das Sieb verlangt zu viel Speicherplatz.\n  2. Die Divisionen verschlingen zu viel Rechenzeit.",
                "Man hat deshalb andere, effizientere Tests ersonnen.\nEinige davon sind so genannte probabilistische Tests, das bedeutet praktisch:\n  Wo sie eine Zahl als zusammengesetzt erkennen, haben sie recht, aber\n  wo sie eine Zahl als Primzahl erkennen, irren sie mit einer gewissen Wahrscheinlichkeit.",
                "Tests mit sicherem Ergebnis sind komplexer und in der Praxis nicht unbedingt erforderlich. Sie werden hier nicht behandelt. Namentlich erwähnt sei der Test von Agrawal aus dem Jahre 2002. Zu Primzahltests siehe auch: [Agrawal-Primzahltest], [Spalka], [Winterhof]",
            ]),
        ]))
        chapters.append(ZTChapter(number: "3.2", title: "Der Fermat-Test", pages: [
            ZTPage(id: "3.2 - 01", title: "Der Fermat-Test", tool: .fermatTest, blocks: [
                "‰Jede Primzahl p besteht einen Test, der sich aus dem kleinen Satz von Fermat ergibt:\n    Prüfe für ein a ∈ {2, ..., p–1}, ob  \u{E000}ap–\u{E001}1 ≡ 1 mod p.\nDieser Test heißt Fermat-Test. Leider bestehen ihn auch einige zusammengesetzte Zahlen.\nBeispiel:     341 = 11 · 31,  trotzdem ist  2\u{E000}340\u{E001} ≡ 1 mod 341.",
                "Bei Bestehen sagt der Test nichts aus, man wiederholt ihn mit einer anderen Basis a:",
                "Definition:     Sei n eine zusammengesetzte Zahl, a teilerfremd zu n.\n    Wenn  a\u{E000}n–1\u{E001} ≡ 1 mod n,  dann heißt     ·  n Pseudoprimzahl zur Basis a,        ·  a Lügner für (die Primalität von) n,    andernfalls heißt a Zeuge gegen (die Primalität von) n.",
                "\\Satz:    Wenn es überhaupt Zeugen gegen n gibt,\n    dann sind es mindestens 50% aller zu n teilerfremden a ∈ {1, ..., n}.     Beweis",
            ]),
            ZTPage(id: "3.2 - Zeugen Staffel", title: "Fermat-Zeugen", tool: .fermatTest, blocks: [
                "Die Ordnung einer Lügnerklasse teilt außer φ(n) auch n–1.\nSatz:    a ist Zeuge gegen n  ⇔  ord( [a]\u{E002}n\u{E003} ) teilt nicht n–1.    Beweis\nBeispiel:",
                "Ordnungen der Restklassen:\nMöglich sind Teiler von φ(n).",
                "a\u{E000}n–1\u{E001} ≡ 1 mod n  ⇔  ord([a]\u{E002}n\u{E003}) | n–1",
            ]),
            ZTPage(id: "3.2 - Carmichael", title: "Carmichael-Zahlen", tool: .carmichael, blocks: [
                "Der Fermat-Test mit der Basis a\nentlarvt keine Pseudoprimzahl zur Basis a.\nMan wiederholt ihn mit anderen Basen. Nun hat das größte anzunehmende Unglück einen Namen:\nDefinition:\nIst n eine Pseudoprimzahl zur Basis a\nfür alle ganzen Zahlen a mit ggT(a, n) = 1,\ndann heißt n Carmichael-Zahl.\nGibt es solche Zahlen überhaupt?",
                "Carmichael-Zahlen < 109\nR.D.Carmichael entdeckte sie 1910.\nund wählen Sie a",
                "Der Fermat-Test entlarvt eine Carmichael-Zahl\ngenau dann, wenn ggT(a, n) > 1.\nDie Wahrscheinlichkeit dafür ist 1 –          .",
            ]),
            ZTPage(id: "3.2 - Carm. Eigenschaften", title: "Eigenschaften der Carmichael-Zahlen", tool: .carmichael, blocks: [
                "Satz:  Jede Carmichael-Zahl ist ungerade.      Beweis\nSatz:  Für jeden Primteiler p einer Carmichael-Zahl n gilt:  p–1 | n–1.     Beweis\nSatz:  Jede Carmichael-Zahl n ist quadratfrei.      Beweis",
                "Satz:     Ist n eine ungerade, zusammengesetzte, quadratfreie Zahl,\n    und gilt für jeden Primteiler p von n:  p–1 | n–1,\n    dann ist n eine Carmichael-Zahl.    Beweis\nSatz: Carmichael-Zahlen haben mindestens drei Primteiler.      Beweis",
                "Alford, Granville, Pomerance bewiesen 1994, dass es unendlich viele Carmichael-Zahlen gibt.\nSatz:  Konstruktion von Carmichael-Zahlen\n    Sind für u ∈ ℕ die drei Zahlen  p\u{E002}1\u{E003}=6·u+1,   p\u{E002}2\u{E003}=12·u+1,   p\u{E002}3\u{E003}=18·u+1  Primzahlen,\n    dann ist n = p\u{E002}1\u{E003}·p\u{E002}2\u{E003}·p\u{E002}3\u{E003} = (6·u+1)·(12·u+1)·(18·u+1) eine Carmichael-Zahl.\nBeweis\nDieser Satz allein beweist nicht, dass es unendlich viele Carmichael-Zahlen gibt, da erst gezeigt werden muss, dass es unendlich viele Primzahl-Tripel der angegebenen Form gibt. Darauf wird hier verzichtet.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "3.3", title: "Der Miller-Rabin-Test", pages: [
            ZTPage(id: "3.3 - 01", title: "Die Idee des Miller-Rabin-Tests", tool: .millerRabin, blocks: [
                "Einige Pseudoprimzahlen lassen sich entlarven, wenn man Folgendes beachtet:\nSatz:    Sei n eine Primzahl, a teilerfremd zu n, b gerade.\n    Dann gilt:    a\u{E000}b\u{E001} ≡ 1 mod n   ⇒   a\u{E000}b/2\u{E001} ≡ ±1 mod n    Beweis",
                "(a\u{E000}d\u{E001})\u{E000}2\u{E001} = a\u{E000}2·d\u{E001}. Nach s Quadrierungen hat man den Exponenten s mal verdoppelt und erhält a\u{E000}n–1\u{E001}.",
                "\"1 entsteht durch Quadrieren\nnur aus 1 oder –1.\"P",
                "Beispiel:  8\u{E000}560\u{E001} ≡ 1 mod 561,  8\u{E000}280\u{E001} ≡ 1 mod 561,  8\u{E000}140\u{E001} ≡ 67 mod 561  ⇒  561 keine Primzahl.",
                "Man hätte den Exponenten noch zwei mal halbieren können, denn 560 = 2\u{E000}4\u{E001}·35.\nAllgemein:    n–1 = 2\u{E000}s\u{E001}·d  mit s ∈ ℕ und ungeradem d.\n    n–1 lässt sich s mal halbieren, a\u{E000}d\u{E001} ist die letzte mögliche Potenz.",
                "Beim Miller-Rabin-Test fängt man mit a\u{E000}d\u{E001} an und quadriert mehrmals:\nBeispiel: (mod 561)  8\u{E000}35\u{E001} ≡ 461,  8\u{E000}70\u{E001} ≡ 463,  8\u{E000}140\u{E001} ≡ 67  ,  8\u{E000}280\u{E001} ≡ 1  ⇒  561 keine Primzahl.",
                "Man quadriert a\u{E000}d\u{E001} höchstens s–1 mal; ist nämlich n Primzahl, dann gilt wegen a\u{E000}n–1\u{E001} ≡ 1 mod n:\nEntweder schon    1) a\u{E000}d\u{E001} ≡ 1 mod n,\noder     2) vor a\u{E000}n–1\u{E001} tritt eine Potenz ≡ –1 mod n auf.\nGilt weder 1) noch 2), dann ist n keine Primzahl.",
            ]),
            ZTPage(id: "3.3 - stark pseudo", title: "Starke Pseudoprimzahlen", tool: .millerRabin, blocks: [
                "Wie beim Fermat-Test hängt das Ergebnis des Miller-Rabin-Tests von der Testbasis a ab.\nDie Begriffe Zeuge, Lügner, Pseudoprimzahl tauchen wieder auf:",
                "a\u{E000}d\u{E001}, (a\u{E000}d\u{E001})\u{E000}2\u{E001}, ((a\u{E000}d\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001}, ...... < a\u{E000}n–1\u{E001}",
                "Definition:    Sei n eine zusammengesetzte Zahl, a teilerfremd zu n.\n    Seien s, d ∈ ℕ so bestimmt, dass  n–1 = d·2\u{E000}s\u{E001}  mit ungeradem d.\nWenn     1) ad ≡ 1 mod n\noder     2) (ad)2  ≡ –1 mod n  für ein r ∈ {0, ..., s–1},\n\ndann heißt     ·  n starke Pseudoprimzahl zur Basis a,\n    ·  a starker Lügner für (die Primalität von) n.\n\nAndernfalls, wenn also weder 1) noch 2) gilt, heißt\n    ·  a starker Zeuge gegen (die Primalität von) n.",
                "Wie beim Fermat-Test muss man unter Umständen mehrere Basen probieren. Der Unterschied:\nGegen jede zusammengesetzte Zahl gibt es genug starke Zeugen.\nBewiesen wird das auf der übernächsten Seite. Betrachten Sie vorher ein paar Beispiele.",
            ]),
            ZTPage(id: "3.3 - MR action", title: "Der Miller-Rabin-Test in Aktion", tool: .millerRabin, blocks: [
                "s = {    ⇒    n–1 = d·\u{E000}2\u{E001}s        Es wird eine Zufallsbasis a ∈ {2, ..., n–1} gewählt:",
                "Damit ist sofort klar, dass n keine Primzahl ist.",
                "r      (a\u{E000}d\u{E001})2   mod n  ( ≡ –1 für ein r < s, wenn n Primzahl ist)\nuadrieren:",
            ]),
            ZTPage(id: "3.3 - max 1/4 Lügner", title: "Höchstens 1/4 Lügner", tool: .millerRabin, blocks: [
                "Hilfs-Satz:    Sei Z\u{E002}n\u{E003}* zyklisch, m ∈ ℕ. Dann gilt:\n    In  Z\u{E002}n\u{E003}* hat x\u{E000}m\u{E001} = –1 so viele Lösungen wie x\u{E000}m\u{E001} = 1 oder keine.    Beispiel\nBeweis",
                "Satz:    Sei n ≠ 9 ungerade und zusammengesetzt. Dann sind \n    höchstens 25% aller a ∈ {1, ..., n} mit ggT(a, n) = 1 starke Lügner für n.",
                "Anmerkungen:\n·  Nach x Durchläufen des Miller-Rabin-Tests mit x verschiedenen Testbasen ist die\n    Wahrscheinlichkeit, dass n nicht prim ist, kleiner als 4\u{E000}–x\u{E001}.\n·  Wegen der geringen Dichte der Primzahlen im Vergleich zu nicht primen Zahlen kann die\n    Wahrscheinlichkeit, dass n nicht prim ist, für große n deutlich besser abgeschätzt werden.\n    Für eine 500 Bit lange Zahl zum Beispiel ist sie schon nach einem Durchlauf kleiner als 4\u{E000}–28\u{E001}.\n·  Für die meisten nicht primen großen n ist bereits a = 2 ein starker Zeuge.\n·  Es gibt unendlich viele nicht prime große n, deren kleinster starker Zeuge beliebig groß ist.\n·  Im Bereich ≤ n gibt es n1/(35·ln ln ln n) nicht prime Zahlen mit großen kleinsten starken Zeugen.",
                "Ende des Kapitels",
            ]),
        ]))
        return ZTLesson(number: 3, title: "Primzahlerzeugung", chapters: chapters)
    }
    static func lesson4() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "4.1", title: "Verschlüsselung", pages: [
            ZTPage(id: "4.1 - 01", title: "Verschlüsselung", tool: .caesar, blocks: [
                "Wer einen Text geheim halten will, hat zwei Möglichkeiten: Verstecken oder Verschlüsseln.\nHübsche Beispiele des Versteckens gibt [Singh 2000].\n\nBeim Verschlüsseln übersetzt man den Text in einen anderen Text, den Chiffretext.\nDie Umkehrung ist das Entschlüsseln: Es übersetzt den Chiffretext zurück in den ersten Text, den Klartext.\nverschlüsseln\nentschlüsseln",
                "Anforderungen:     1. Unbefugte können den Chiffretext nicht entschlüsseln.     2. Das Entschlüsseln ist möglich: Man erhält wirklich wieder den Klartext.\nDie Schwierigkeit besteht darin, beide Anforderungen gleichzeitig zu erfüllen.\nAußerdem sollte das Ver- und Entschlüsseln den Befugten nur wenig Aufwand bereiten, denn ein veralteter Text ist meistens wertlos. Entsprechend kann hoher Aufwand bei der Entschlüsselung praktisch die erste Anforderung erfüllen.",
                "Auf den nächsten Seiten werden zunächst einige allgemeine Begriffe und Techniken,\ndann die Idee der asymmetrischen Verschlüsselung vorgestellt.\nUnbefugte heißen: der Gegner, der Angreifer, der Lauscher etc.",
            ]),
            ZTPage(id: "4.1 - Cäsar", title: "Die Cäsar-Verschlüsselung", tool: .caesar, blocks: [
                "Cäsar:    Lege zwei Alphabete verschoben über einander, dann steht jeweils\n    oben ein Zeichen im Klartext, darunter seine Entsprechung im Chiffretext.",
                "¤Der Empfänger muss nun wissen, um wieviele Zeichen er das Alphabet verschieben soll.\nDiese Zahl vereinbart man als Schlüssel. Sie entspricht hier",
                "Dieses Alphabet bereichert Cäsars Alphabet um J, U, W, Y, ℤ und das Leerzeichen.\nZur Vereinfachung werden Kleinbuchstaben groß gemacht und zählen auf diese Weise mit.\nAlle anderen Zeichen fallen unter den Tisch. Übernähme man sie in den Chiffretext, so könnten\nsie dem Gegner Anhaltspunkte zur Entschlüsselung geben. Dem Empfänger gegenüber bedeutet die Aufnahme des Leerzeichens ins Alphabet eine besondere Gnade.\nWer mehr Zeichen verschlüsseln will, braucht ein größeres Alphabet,\ngängig ist etwa der ASCII-Zeichensatz mit 128 Zeichen.",
            ]),
            ZTPage(id: "4.1 - Schlüssel", title: "Schlüssel", tool: .caesar, blocks: [
                "Im Folgenden dient als Alphabet das ABC plus Leerzeichen.\nEs eignet sich zu Demonstrationszwecken dank Kürze und Lesbarkeit.",
                "Die Größe des Alphabets bezeichnet man mit |Alphabet|.\nDen Zeichen des Alphabets ordnet man Zahlen zu, damit man mit ihnen rechnen kann.\nSo berechnet man bei Cäsar zu jedem Zeichen x ein neues Zeichen x + b (mod 27).\nMan sagt:    Cäsar hat die Verschlüsselungsfunktion V(x) = x + b (mod 27).\nUnd:    Cäsar hat die Entschlüsselungsfunktion E(x) = x – b (mod 27).",
                "Dabei dient b als Schlüssel. Er macht das Verfahren variabel. Für verschiedene Adressaten nimmt man nur verschiedene Schlüssel, das Verfahren behält man bei.",
                "Hier zeigt sich eine Schwachstelle der Cäsar-Verschlüsselung:  Sie kennt nur 27 Schlüssel.\nDer Gegner muss also nicht lange probieren, bis er einen sinnvollen Text erhält.\n\nEine Überlegung wäre nun, das Verfahren geheim zu halten, doch das hat man aufgegeben.\nEin Verschlüsselungsverfahren, das man geheim halten muss, gilt als unsicher. Die Sicherheit darf nur davon abhängen, dass der Schlüssel geheim bleibt.\n\nMan braucht also Verfahren mit möglichst vielen Schlüsseln.",
            ]),
            ZTPage(id: "4.1 - multiplik", title: "Multiplikative Verschlüsselung", tool: .multiplicative, blocks: [
                "Entschlüsselung mit der Umkehrfunktion:  E(x) = a'·(x–b') (mod 27)\nVerschlüsselung mit der Funktion:  V(x) = a·x + b (mod 27)\nAnzahl Schlüssel: φ(27) · 27\nDieses Verfahren arbeitet mit Addition und Multiplikation. Die Schlüssel sind Paare (a, b).\nProbieren Sie aus, bei welchen Paaren die Verschlüsselung umkehrbar ist.",
                "Es muss gelten: a·a' ≡ 1 mod 27.",
            ]),
            ZTPage(id: "4.1 - Häuf", title: "Häufigkeitsanalyse", tool: .frequency, blocks: [
                "Damit die Entschlüsselung immer klappt, muss man ungleiche Zeichen ungleich verschlüsseln:\nDie Verschlüssungsfunktion muss – wie jede umkehrbare Abbildung – injektiv sein.",
                "Jede Verschlüsselungsfunktion, die einfach die Zeichen des Alphabets neu mischt, ist injektiv.\nAls Schlüssel gibt man das gemischte Alphabet an, zum Beispiel\n    Schlüssel k:    MNBWGHIRSTUJ KLACDEXZFOPQVY\nDas ergibt  27! = 27·26·...·2·1 = 10888869450418352160768000000  mögliche Schlüssel.",
                "Doch auch das wäre leicht zu knacken – mittels Häufigkeitsanalyse:\n\nIn Texten natürlicher Sprachen treten die Buchstaben mit unterschiedlicher Häufigkeit auf.\nSo tritt das E in deutschen oder englischen Texten häufiger auf als das X.\nFür alle Sprachen gibt es Tabellen der durchschnittlichen Häufigkeit jedes Buchstabens. Vergleicht man damit die Häufigkeit jedes Zeichens im Chiffretext, so findet man bald erste Entsprechungen und kann den Rest erraten.",
                "Was hilft gegen die Häufigkeitsanalyse?\nMan definiert den Schlüssel nicht für Einzelzeichen, sondern für Kombinationen von Zeichen.\nklassisches Beispiel",
            ]),
            ZTPage(id: "4.1 - Text -> Zahl", title: "Text als Zahl", tool: .textToNumber, blocks: [
                "Einen Text kann man als große Zahl lesen, mit der man dann rechnet:\nJedes Textzeichen bildet eine Ziffer dieser Zahl. Die Ziffern gehen von 0 bis |Alphabet| – 1.\nText:",
                "Darf die Zahl eine Grenze G nicht überschreiten, so muss man den Text aufteilen\nin Blöcke der Länge L = ⌊log\u{E002}B\u{E003}G⌋. Dabei bildet jeder Block eine Zahl für sich.",
            ]),
            ZTPage(id: "4.1 - 0 vorn", title: "Blöcke und führende Nullen", tool: .textToNumber, blocks: [
                "Die Verwandlung eines Textes in eine Zahl ist nicht injektiv:\nIst dem Leerzeichen die Ziffer 0 zugeordnet, dann werden Leerzeichen am Text-Anfang\nzu Nullen am Zahl-Anfang – und verschwinden.\nNach der Rückverwandlung in einen Text fehlen also die Leerzeichen am Text-Anfang.",
                "Hier bewährt sich das Leerzeichen im Alphabet:\nLieber das Leerzeichen als das A verschwinden lassen.\nTeilt man den Text in Blöcke auf, so verschwinden die Leerzeichen am Anfang jedes Blocks.\nMan kann sie aber ergänzen, wenn man die Blocklänge kennt. Damit der letzte Block nicht nach rechts \"verrutscht\", füllt man ihn vor der Verwandlung in eine Zahl mit Leerzeichen auf.",
                "Teilt man den Text in Blöcke auf, so gibt es noch ein Problem:\nBeispiel:   V(x) = x + 2 (mod 30),  E(x) = x – 2 (mod 30),   Blocklänge = 1 = ⌊log \u{E002}27 \u{E003}30⌋ .\n     verschlüsseln:  A →  1 →  3  →  C    entschlüsseln:  C   →   3  →   1  →  A       ok",
                "    verschlüsseln:  ℤ → 26 → 28 → AA    entschlüsseln:  A|A → 1 1 → 29 29 → AB|AB  falsch\n\nWegen der Blockbildung \"weiß\" AA nicht mehr, dass es aus 28 entstanden ist.",
                "Dieses Problem tritt nicht auf, wenn man den Chiffretext als Zahl stehen lässt.\n   28  →  26 →  ℤ       ok",
            ]),
            ZTPage(id: "4.1 - asym", title: "Asymmetrische Verschlüsselung", tool: nil, blocks: [
                "Das große kryptographische Problem war immer die Schlüsselverteilung. Um Geheimnisse auszutauschen, mussten Sender und Empfänger einen geheimen Schlüssel absprechen.\nWer das belauschte, konnte alle Geheimnisse entziffern.\nWenn bei n Personen jede mit jeder Geheimnisse haben will, müssen n·(n–1)/2 Schlüssel abgesprochen werden. Das sind bei n = 1000 schon 499500 Schlüssel.",
                "In den 1970er Jahren wurde die asymmetrische Verschlüsselung erfunden. Sie benutzt zwei Schlüssel: A zum Verschlüsseln, B zum Entschlüsseln.\n\nA heißt öffentlicher Schlüssel, B heißt privater Schlüssel.\nA gibt die Empfängerin bekannt wie in einem Telefonbuch, B hält sie geheim.\nDann kann ihr jeder schreiben, aber nur sie kann es entschlüsseln.\nEs gibt keine geheimen Schlüssel-Absprachen mehr.",
                "A und B müssen so beschaffen sein, dass niemand B aus A errechnen kann.\nDarin besteht die Asymmetrie.\n\nDie bisher betrachteten Verfahren sind dagegen symmetrisch:\nBeim Cäsar-Verfahren nimmt man den selben Schlüssel zur Ver- wie zur Entschlüsselung.\nBeim Verfahren mit Multiplikation errechnet man Faktor B leicht, weil A·B ≡ 1 mod |Alphabet|.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "4.2", title: "Das RSA-Verfahren", pages: [
            ZTPage(id: "4.2 - 01", title: "Das RSA-Verfahren", tool: .rsa, blocks: [
                "nach seinen Erfindern Ron Rivest, Adi Shamir und Len Adleman",
                "Historisch das erste asymmetrische Verschlüsselungsverfahren ist RSA.\nEs beruht auf der Schwierigkeit, große Zahlen in Primfaktoren zu zerlegen.",
                "Die Empfängerin wählt zwei Primzahlen p, q und berechnet den RSA-Modul m = p·q.\nDamit ist  φ(m) = (p–1)·(q–1)\nDann wählt die Empfängerin    eine Zahl b teilerfremd zu φ(m)\nund berechnet mit Euklid    eine Zahl a, so dass  a·b ≡ 1 mod φ(m)\nÖffentlicher Schlüssel ist das Paar (m, a),  privater Schlüssel ist b.",
                "Der Sender verwandelt seine Nachricht zunächst in eine Zahl n < m.\nDabei muss n teilerfremd zu m sein – was bei großen Primzahlen p, q fast immer der Fall ist.\nDann berechnet und sendet er:      c = n\u{E000}a\u{E001} (mod m).",
                "Die Empfängerin entschlüsselt:  c\u{E000}b\u{E001} = n\u{E000}a·b\u{E001} ≡ n\u{E000}1\u{E001} ≡ n mod m\nErinnerung:      x ≡ y mod φ(m)  ⇒  n\u{E000}x\u{E001} ≡ n\u{E000}y\u{E001} mod m",
                "Um b aus (m, a) zu berechnen, braucht man φ(m), also die Primfaktoren p, q von m.\nOb es eine Möglichkeit gibt, c zu entschlüsseln, ohne b zu kennen, ist nicht bekannt.",
            ]),
            ZTPage(id: "4.2 - RSA machen", title: "RSA ausprobieren", tool: .rsa, blocks: [
            ]),
            ZTPage(id: "4.2 - trapdoor", title: "Einwegfunktion mit Falltür", tool: nil, blocks: [
                "Verschlüsseln durch Potenzieren kann jeder, entschlüsseln nicht.\n\nEine Funktion, die selbst leicht, deren Umkehrung aber schwer zu berechnen ist,\nnennt man Einwegfunktion – \"Einbahnfunktion\" träfe es im Deutschen besser.",
                "Die RSA-Verschlüsselung benutzt die Einwegfunktion  f(x) = x\u{E000}a\u{E001} (mod m).\nDiese Einwegfunktion ist gleichzeitig eine Trapdoor-Funktion,\nsie hat eine so genannte Geheimtür:\nWer φ(m) kennt, findet leicht den \"Gegen-Exponenten\" und damit die Umkehrfunktion.\nφ(m) bleibt ein Geheimnis, weil es schwer ist, die Primfaktoren von m zu finden.\nÜbrigens kann man die geheimen Primfaktoren des RSA-Moduls leicht errechnen,\nwenn man ein Paar zugehöriger Ver- und Entschlüsselungs-Exponenten kennt.\nWie das geht, beschreibt [Buchmann].",
                "Digitale Signatur:\nVerschlüsselt Alice einen Klartext mit ihrem eigenen privaten Schlüssel,\ndann kann jeder mit ihrem öffentlichen Schlüssel den Klartext lesbar machen\n – und sie kann nicht abstreiten, ihn verschlüsselt zu haben.",
            ]),
            ZTPage(id: "4.2 - Low Exp Attack", title: "Low-Exponent-Angriff", tool: .crt, blocks: [
                "Low-Exponent-Attacke:\n    Sei M = {m\u{E002}1\u{E003}, m\u{E002}2\u{E003}, ..., m\u{E002}e\u{E003}} eine Menge von e paarweise teilerfremden RSA-Moduln,     sei n ∈ ℕ eine Nachricht mit     n < m\u{E002}i\u{E003}  für alle m\u{E002}i\u{E003} ∈ M,\n       sei c ∈ ℕ mit    0 ≤ c < m\u{E002}1\u{E003}·m\u{E002}2\u{E003}·...·m\u{E002}e\u{E003}        und       c ≡ n\u{E000}e\u{E001} mod m\u{E002}i\u{E003}  für alle m\u{E002}i\u{E003} ∈ M.            Dann ist     c = n\u{E000}e\u{E001}.",
                "    Die Zahl c' = n\u{E000}e\u{E001} erfüllt die simultane Kongruenz    c ≡ n\u{E000}e\u{E001} mod m\u{E002}i\u{E003}  für alle m\u{E002}i\u{E003} ∈ M,\n    und      0 ≤ c' < m\u{E002}1\u{E003}·m\u{E002}2\u{E003}·...·m\u{E002}e\u{E003},   weil n < m\u{E002}i\u{E003} für alle m\u{E002}i\u{E003} ∈ M.\n    Nach dem Chinesischen Restsatz ist eine solche Lösung c' eindeutig, also ist c = c'.",
                "Sendet man eine Nachricht n an viele Empfänger, so benutze man den Exponenten e\nbei der Verschlüsselung  c\u{E002}i\u{E003} = n\u{E000}e\u{E001} (mod m\u{E002}i\u{E003}) weniger als e mal.\nSonst bildet ein Angreifer aus den Schlüsseltexten c\u{E002}i\u{E003} die simultane Kongruenz  c ≡ c\u{E002}i\u{E003} mod m\u{E002}i\u{E003}  und löst sie einfach mit dem Chinesischen Restsatz. Die e-te Wurzel aus c ist n.\n\nGegen die Low-Exponent-Attacke helfen große Verschlüsselungsexponenten e.",
            ]),
            ZTPage(id: "4.2 - Multiplikativität", title: "Multiplikativität", tool: .rsa, blocks: [
                "Multiplikativität:\n    Sei (m, a) ein öffentlicher RSA-Schlüssel.\n    Werden damit zwei Nachrichten n\u{E002}1\u{E003} und n\u{E002}2\u{E003} verschlüsselt, so erhält man\nc\u{E002}1\u{E003} ≡ n\u{E002}1\u{E003}\u{E000}a\u{E001} mod m    und    c\u{E002}2\u{E003} ≡ n\u{E002}2\u{E003}\u{E000}a\u{E001} mod m.\n    Für c = c\u{E002}1\u{E003}·c\u{E002}2 \u{E003} gilt dann:\nc = c\u{E002}1\u{E003}·c\u{E002}2\u{E003}  ≡ (n\u{E002}1\u{E003}·n\u{E002}2\u{E003})\u{E000}a\u{E001} mod m",
                "Ein Betrüger kann also einen Chiffretext c\u{E002}1\u{E003} um einen gefälschten Zusatz c\u{E002}2\u{E003} verlängern.\nDamit der Empfänger das merkt, kann man dem Klartext eine feste Struktur geben, die verletzt wird, wenn man zwei Klartexte multipliziert. Eine solche Struktur wäre zum Beispiel, dass das erste Zeichen mit dem letzten Zeichen überein stimmt.",
            ]),
            ZTPage(id: "4.2 - RSA machen lang", title: "RSA mit eigenen Zahlen", tool: .rsa, blocks: [
                "ab hier mit BC suchen\n⊂|Än",
            ]),
        ]))
        chapters.append(ZTChapter(number: "4.3", title: "Weitere Verfahren", pages: [
            ZTPage(id: "4.3 - 01", title: "Das Rabin-Verfahren", tool: .rabin, blocks: [
                "Für x ∈ ℙ ist  c\u{E000}x–1\u{E001} ≡ 1 mod x.  \"kleiner Fermat\"",
                "mit dem euklidischen Algorithmus",
                "Im Rabin-Verfahren wählt Alice zwei Primzahlen p, q mit p ≡ q ≡ 3 mod 4.\nIhr öffentlicher Schlüssel ist  m = p·q,  ihr privater Schlüssel ist (p, q).",
                "Bob verschlüsselt:     c = n\u{E000}2\u{E001} (mod m)\nAlice entschlüsselt durch Wurzelziehen aus c. Das geht so:",
                "Alice berechnet:     P = c\u{E000}(p+1)/4\u{E001} (mod p),     Q = c\u{E000}(q+1)/4\u{E001} (mod q)\nEs gilt ja:           4 | p+1,             4 | q+1\nDann sind ±P die Quadratwurzeln von c in Z\u{E002}p\u{E003},  und ±Q entsprechend in Z\u{E002}q\u{E003}, denn\n\n    (c\u{E000}(x+1)/4\u{E001})\u{E000}2\u{E001}  =  c\u{E000}(x+1)/2\u{E001}  =  (c\u{E000}x–1+2\u{E001})\u{E000}1/2\u{E001}  =  (c\u{E000}x–1\u{E001}·c\u{E000}2\u{E001})\u{E000}1/2\u{E001}  ≡  c\u{E000}2/2\u{E001}  =  c mod x    für x ∈ ℙ.",
                "Die vier Quadratwurzeln in Z\u{E002}m\u{E003} berechnet Alice mit dem Chinesischen Restsatz:\nSie bestimmt Koeffizienten x, y mit  x·p + y·q = 1.\nDann berechnet sie  r = (x·p·Q + y·q·P) (mod m),    s = (x·p·Q – y·q·P) (mod m).",
                "Eine der vier Quadratwurzeln  ±r,  ±s  ist die Nachricht n.\nAlice muss ausprobieren, welche. Sie nimmt die, die den sinnvollsten Text ergibt.",
            ]),
            ZTPage(id: "4.3 - Diffie-Hellman", title: "Diffie-Hellman-Schlüsselaustausch", tool: .diffieHellman, blocks: [
                "Diffie und Hellman haben ein Verfahren gefunden, wie man einen geheimen Schlüssel verabredet, ohne dass ein Lauscher ihn erfährt.",
                "–Alice und Bob verabreden in aller Öffentlichkeit einen geheimen Schlüssel:\n1. Sie wählen offen eine Primzahl p und eine Primitivwurzel g mod p.\n2. Alice wählt heimlich eine Zahl a ∈ {1, 2, ..., p–2} und sendet Bob A = ga (mod p).\n3. Bob wählt heimlich eine Zahl b ∈ {1, 2, ..., p–2} und sendet Alice B = \u{E000}g\u{E001}b (mod p).\n4. Beide berechnen den selben geheimen Schlüssel \u{E000}ga·\u{E001}b (mod p):\n    Alice berechnet \u{E000}B\u{E001}a (mod p) = \u{E000}ga·\u{E001}b (mod p).\n    Bob berechnet \u{E000}A\u{E001}b (mod p) = \u{E000}ga·\u{E001}b (mod p).",
                "Der Lauscher steht vor dem Diffie-Hellman-Problem:  Er erfährt zwar p, g, A und B,\n       aber nicht den Schlüssel g\u{E000}a·b\u{E001} (mod p) oder die Exponenten a, b.\n       Um a oder b zu ermitteln, müsste er diskrete Logarithmen in Z\u{E002}p\u{E003}* berechnen.\n       Diskrete Logarithmen in Z\u{E002}p\u{E003}* sind aber sehr unregelmäßig und schwer zu berechnen.",
                "Gefahr:  Man-In-The-Middle-Attacke\nDer Lauscher tauscht unbemerkt Schlüssel mit Alice und Bob und kann alles lesen.",
            ]),
            ZTPage(id: "4.3 - ElGamal", title: "Das ElGamal-Verfahren", tool: .elgamal, blocks: [
                "Das ElGamal-Verfahren hängt eng mit dem Diffie-Hellman-Schlüsselaustausch zusammen.\n\nAlice wählt eine Primzahl p und eine Primitivwurzel g mod p.\nSie wählt eine Zahl a ∈ {1, 2, ..., p–2} und berechnet A = \u{E000}g\u{E001}a (mod p).\nIhr öffentlicher Schlüssel ist (p, g, A). Ihr geheimer Schlüssel ist der Exponent a.",
                "OBob verschlüsselt n:  Er wählt eine Zahl b ∈ {1, 2, ..., p–2} und berechnet\n1. c = \u{E000}A\u{E001}b·n (mod p).    Der Faktor \u{E000}A\u{E001}b = (\u{E000}g\u{E001}a\u{E000})\u{E001}b    ist der geheime Schlüssel bei Diffie-Hellman.\n2. B = \u{E000}g\u{E001}b (mod p).     Die Zahl     B   =  \u{E000}g\u{E001}b     ist Bobs Anteil bei Diffie-Hellman.\nBob sendet (B, c).\nEin Nachteil des Verfahrens ist, dass B die Länge der Sendung verdoppelt.",
                "Für p ∈ ℙ ist  g\u{E000}p–1\u{E001} ≡ 1 mod p.  \"kleiner Fermat\"",
                "Alice berechnet     B\u{E000}p–1–a\u{E001}·c (mod p)   und erhält n, denn\n    B\u{E000}p–1–a\u{E001}·c  ≡  g\u{E000}b·(p–1–a)\u{E001}·A\u{E000}b\u{E001}·n  ≡  (g\u{E000}p–1\u{E001})\u{E000}b\u{E001}·(g\u{E000}a\u{E001})\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  ≡  A\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  ≡  n mod p",
                "Bob muss für jede Nachricht n ein neues b wählen. Sonst gilt:\n    c ≡ A\u{E000}b\u{E001}·n mod p,      c' ≡ A\u{E000}b\u{E001}·n' mod p\n    ⇒    c'·c\u{E000}–1\u{E001} ≡ n'·n\u{E000}–1\u{E001} mod p      ⇒    n' ≡ c'·c\u{E000}–1\u{E001}·n mod p.  Jeder, der n kennt, kann auch n' lesen.",
            ]),
            ZTPage(id: "4.3 - ElGamal2", title: "ElGamal und elliptische Kurven", tool: .elgamal, blocks: [
                "Im ElGamal-Verfahren verschlüsselt Bob jede Nachricht mit einem neuen Exponenten.\nDer Gegner merkt nicht, wenn zwei mal die selbe Nachricht auf die Reise geht.\nDas erschwert die Statistik des Gegners.",
                "Erweiterung zu \"Euler-Fermat\":\nIn jeder Gruppe G gilt:  a\u{E000}|G|\u{E001} = e (neutral)  für alle a ∈ G.",
                "Das ElGamal-Verfahren funktioniert nicht nur in primen Restklassengruppen,\nsondern in jeder zyklischen Gruppe G, in der diskrete Logarithmen schwer zu berechnen sind.\n\nDie Gruppen-Ordnung |G| ist nicht geheim. Alice braucht sie zur Entschlüsselung:\nAlice berechnet     B\u{E000}|G|–a\u{E001}·c  in G   und erhält n, denn\n    B\u{E000}|G|–a\u{E001}·c  =  g\u{E000}b·(|G|–a)\u{E001}·A\u{E000}b\u{E001}·n  =  (g\u{E000}|G|\u{E001})\u{E000}b\u{E001}·(g\u{E000}a\u{E001})\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  =  A\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  =  n",
                "Beispiel:     Die Punktgruppe einer elliptischen Kurve über Z\u{E002}p\u{E003}* mit p ∈ ℙ\nDabei muss man die Nachrichten irgend wie in Gruppen-Elemente verwandeln.\nEs sei auf die Literatur unter [Elliptische Kurven] verwiesen, insbesondere auf:\nhttp://www.mi.uni-erlangen.de/~ruppert/WS0001",
                "Ende des Kapitels",
            ]),
        ]))
        return ZTLesson(number: 4, title: "Asymmetrische Verschlüsselung", chapters: chapters)
    }
    static func lesson5() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "5.1", title: "Teiler finden", pages: [
            ZTPage(id: "5.1 - 01", title: "Teiler finden", tool: .trialDivision, blocks: [
                "In diesem Kapitel geht es darum, wie man natürliche Zahlen n in Faktoren zerlegt,\nFaktorisierung ist ein anderes Wort für Faktorzerlegung.\nAls Faktoren sucht man nicht-triviale Teiler, also Teiler zwischen 1 und n. \nBei Primzahlen macht man eine Ausnahme: Die Faktorisierung einer Primzahl ist sie selbst.",
                "Das einfachste Verfahren ist die Probedivision, die auch als Primzahltest dienen kann:\n    Man dividiert n durch alle Primzahlen 2, 3, 5, 7, 11, ..., um zu sehen, ob ein Rest bleibt.\n    Hat man bis zur Wurzel von n keinen Teiler gefunden, so ist n eine Primzahl.\n    Bei großen Zahlen geht man nicht bis zur Wurzel, sondern beispielsweise nur bis 10000,\n    und greift dann zu anderen Verfahren.\n    Die Probedivision ist gut, um kleine Teiler zu finden.",
                "Hat man einen Teiler d gefunden, so erhält man seinen Komplementärteiler durch Division n/d\nund damit die Faktorzerlegung  n = d · n/d.\nFaktorisiert man nun die Teiler d und n/d, dann deren Teiler und alle Teiler, die noch kommen, so erhält man die Primfaktorzerlegung von n, die man etwa braucht, um φ(n) zu berechnen.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.2", title: "Fermat-Faktorisierung", pages: [
            ZTPage(id: "5.2 - 01", title: "Fermat-Faktorisierung", tool: .fermatFactor, blocks: [
                "Wenn sich n als    n = a\u{E000}2\u{E001} – b\u{E000}2\u{E001} schreiben lässt, ergibt sich die Faktorisierung von n einfach als     n = (a + b)·(a – b).",
                "Jedes Produkt zweier ungerader Zahlen u·v mit u > v lässt sich so darstellen, da für\n     n = u·v      mit  a = (u+v)/2      und  b = (u–v)/2      gilt:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = n.\n    15 = 15·1      mit  a = (15+1)/2 = 8     und  b = (15–1)/2 = 7    gilt:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = 64 – 49 = 15\n    15 = 5·3       mit  a = (5+3)/2 = 4    und  b = (5–3)/2 = 1    gilt:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = 16 – 1 = 15",
                "Bei der Faktorisierungs-Methode nach Fermat setzt man für a die Werte  ⌈√n⌉,  ⌈√n⌉ + 1, ... ein\n       und prüft, ob a\u{E000}2\u{E001} – n eine Quadratzahl ist.\n    Wenn ja, ist mit a\u{E000}2\u{E001} – n = b\u{E000}2\u{E001} eine Faktorisierung  n = (a + b)·(a – b)  gefunden.",
                "Beispiel:     n = 39\n              ⌈√n⌉ = 7\n    7\u{E000}2\u{E001} – n = 49 – 39 = 10\n    8\u{E000}2\u{E001} – n = 64 – 39 = 25 = 5\u{E000}2\u{E001}  Bingo!\n    ⇒   n = 8\u{E000}2\u{E001} – 5\u{E000}2\u{E001} = (8 + 5)·(8 – 5) = 13 · 3",
            ]),
            ZTPage(id: "5.2 - Fermat Abbruch", title: "Wann bricht das Verfahren ab?", tool: .fermatFactor, blocks: [
                "Ist bis a = ⌊(n+9)/6⌋ keine Quadratzahl b\u{E000}2\u{E001} gefunden, dann ist n eine Primzahl.",
                "Beispiel: n = 47\n          ⌈√n⌉ = 7        Grenze = ⌊(n+9)/6⌋ = 9\n    7\u{E000}2\u{E001} – n = 49 – 47 = 2\n    8\u{E000}2\u{E001} – n = 64 – 47 = 17\n    9\u{E000}2\u{E001} – n = 81 – 47 = 34\n    ⇒   n ist Primzahl.",
                "Schieben Sie den blauen Punkt\nGrund",
            ]),
            ZTPage(id: "5.2 - Quadrate erkennen", title: "Quadrate erkennen", tool: .fermatFactor, blocks: [
                "Hat man a\u{E000}2\u{E001} errechnet, so findet man die nächsten Quadratzahlen leicht, denn der Abstand zwischen den Quadratzahlen wächst immer um 2. Der erste Abstand ist (a+1)\u{E000}2\u{E001} – a\u{E000}2\u{E001} = 2·a + 1.",
                "!Um zu entscheiden, ob \u{E000}a\u{E001}2 – n eine Quadratzahl ist, muss man nicht unbedingt die Wurzel ziehen. Quadratzahlen enden zum Beispiel nie auf 2, 3, 7 oder 8.\nModulo 10 gibt es nur die quadratischen Reste {0, 1, 4, 5, 6, 9}.",
                "Ist eine Zahl x zu irgendeinem Modul quadratischer Nicht-Rest, so ist x keine Quadratzahl.\nMan betrachtet x also zuerst zu mehreren Moduln, z.B. den ungeraden Primzahlen < 20.  \nNur wenn x zu jedem dieser Moduln quadratischer Rest ist, muss man noch die Wurzel ziehen.\nEine Betrachtung mod 2 ist übrigens sinnlos, da jede Zahl quadratischer Rest mod 2 ist.\nEine Betrachtung mod 16 dagegen ist gut, weil nur 4 Zahlen quadratische Reste mod 16 sind.\n\nBeispiel",
                "Der schlechteste Fall des Fermat-Verfahrens ist gerade der beste Fall der Probedivison\nund umgekehrt. Es bietet sich daher an, beide Verfahren zu kombinieren.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.3", title: "Pollards Rho-Faktorisierung", pages: [
            ZTPage(id: "5.3 - 01", title: "Das Geburtstagsparadoxon", tool: .birthday, blocks: [
                "Ab wieviel Personen auf einer Party lohnt sich die Wette darauf, dass\nmindestens zwei der Anwesenden am gleichen Tag Geburtstag haben?",
                "im Sinne von: öfter gewinnen als verlieren",
                "Die Tage des Jahres sind\nvon 1 bis 365 nummeriert,\n32 ist also der 1. Februar.\nDer 29. Februar entfällt.",
                "Rechts steht, wieviele Partygäste an dem Tag links Geburtstag haben.",
                "Geburtstagsparadox:\n    Auf der Erde reichen 23 Personen.     Beweis\n    Allgemein gilt:\n    Hat das Jahr n Tage, dann reichen etwas mehr als √n Personen.",
                "Geburtstag     Personen\n_{> 365    gewinnt jede Wette\n(Zur Vereinfachung habe jedes Jahr 365 Tage.)\n   k    Wetten     davon gewonnen",
            ]),
            ZTPage(id: "5.3 - pollard rho", title: "Die Idee von Pollards Rho", tool: .rhoSequence, blocks: [
                "der griechische Buchstabe Rho",
                "Pollards r-Faktorisierungs-Methode arbeitet mit einer pseudozufälligen Folge von Werten:\n    x\u{E002}1\u{E003} := random(0, n–1)\n    x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)\nDabei ist x\u{E002}1\u{E003} ∈ ℤ der Startwert und f ein Polynom mit Koeffizienten ∈ ℤ, etwa x\u{E000}2\u{E001} + 1.",
                "Sei d ein nicht-trivialer Teiler von n.\nDann existieren wahrscheinlich x\u{E002}i\u{E003} und x\u{E002}j\u{E003} mit:\n    x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d\n    x\u{E002}i\u{E003} ≠ x\u{E002}j\u{E003} mod n",
                "Laut Geburtstagsparadox ist dieser Fall nach etwas mehr als √d Folgengliedern zu erwarten.\nDann gilt:     d teilt x\u{E002}i\u{E003} – x\u{E002}j\u{E003}  und  n teilt nicht x\u{E002}i\u{E003} – x\u{E002}j\u{E003} .\n    Also erhält man mit  ggT(x\u{E002}i\u{E003} – x\u{E002}j\u{E003}, n)  einen nicht-trivialen Teiler von n.",
                "Es bleibt zu klären, wie man die richtigen x\u{E002}i\u{E003} und x\u{E002}j\u{E003} am schnellsten findet.\nMüsste man ggT(x\u{E002}i\u{E003} – x\u{E002}j\u{E003}, n) für alle Kombinationen von Folgengliedern x\u{E002}i\u{E003} und x\u{E002}j\u{E003} bestimmen,\ndann wäre der Algorithmus schlechter als die Probedivision.",
            ]),
            ZTPage(id: "5.3 - Kreise", title: "Folgen laufen im Kreis", tool: .rhoSequence, blocks: [
                "Wegen  x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)  läuft die Folge spätestens nach n Gliedern im Kreis.\nSei nun d ein nicht-trivialer Teiler von n.\nGilt für zwei Folgenglieder x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d,  dann gilt wegen  x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)\n    auch  x\u{E002}i+k\u{E003} ≡ x\u{E002}j+k\u{E003} mod d  für alle k ∈ ℕ.\nDie Reduktion mod n subtrahiert Vielfache von d: die Kongruenz mod d bleibt bestehen.\nDaher bildet die Folge auch mod d einen Kreis – der kleiner sein kann als der Kreis mod n.",
                "Beispiel:  n = 15,   f(x) = x\u{E000}2\u{E001} + 1,  zufälliger Startwert x\u{E002}1\u{E003} = 3.\ni        1    2    3    4    5    6    7    8    9\nx\u{E002}i\u{E003} mod 15    3    10    11    2    5    11    2    5    ...",
                "Die Werte des Kreises, die also wiederkehren, bilden die so genannte Periode.\nDie Werte am Anfang, die nicht wiederkehren, bilden die so genannte Vorperiode.",
                "Man sucht Folgenglieder mit x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d.\nWeil die Folge periodisch wird, hilft dabei ein Kreisfindungs-Algorithmus.",
            ]),
            ZTPage(id: "5.3 - Floyd, Brent", title: "Floyd und Brent", tool: .rhoSequence, blocks: [
                "Als Pollard seinen r-Algorithmus 1975 vorstellte, benutzte er den\nKreisfindungs-Algorithmus von Floyd:\nFloyd startet zwei Variablen x und y mit dem selben Wert\nund rechnet in jedem Schritt:\n     x\u{E002}i+1 \u{E003}:= f(x\u{E002}i\u{E003}),    x\u{E002}i+2 \u{E003}:= f(x\u{E002}i+1\u{E003})\n    y\u{E002}j+1 \u{E003}:= f(y\u{E002}j\u{E003})\nAlso durchläuft x die Folge doppelt so schnell wie y\nund überrundet y bald. Dann ist der Kreis gefunden.",
                "Das illustriert das Bild rechts,\nwenn Sie auf Floyd drücken.",
                "1980 stellte Brent einen Kreisfindungs-Algorithmus vor,\nder in jedem Schritt nur einmal rechnet, nämlich so:\n    Wenn i eine 2er-Potenz ist, setze y := x\u{E002}i\u{E003}.\n    Berechne  x\u{E002}i+1 \u{E003}:= f(x\u{E002}i\u{E003})  und\n    vergleiche den aktuellen Wert x\u{E002}i\u{E003} mit y.\nBrent-Illustration mit Zahlen",
                "Das Bild verewigte Pollard im Namen r-Algorithmus.",
            ]),
            ZTPage(id: "5.3 - pollard rho Algo", title: "Der Rho-Algorithmus", tool: .pollardRho, blocks: [
                "Die Laufzeit des Kreisfindungs-Algorithmus hängt vom Startwert x\u{E002}1\u{E003} ab. Deshalb probiert man\nbei Überschreiten eines Limits einen anderen Startwert. Beim Limit berücksichtigt man das Geburtstagsparadox und die Tatsache, dass n \u{E000}∉\u{E001} ℙ einen Teiler d ≤ \u{E000}Ön hat.\u{E001}",
                "VAlgorithmus:    Erläuterungen:\nlimit := sqrt( sqrt(n) ) + 1000    # Geburtstagsparadox bei Teiler von n\nx := random(0, n–1)    # zufälliger Startwert x\ni := 1\nd := 1\nSolange d = 1, wiederhole  {    # Brents Kreisfindungs-Algorithmus\n    φ := i\n    y := x    # y merkt sich xj , wobei φ = 2er-Potenz\n    Solange i < 2·j, wiederhole  {\n        x := f(x) (mod n)    # Üblich ist f(x) = \u{E000}x\u{E001}2 + 1.\n        i := i + 1\n          Wenn x = y oder i > limit, dann Stopp    # neuen Startwert x probieren\n        d := ggT( x–y, n )    # suche einen Kreis mod d, nicht mod n.\n        Wenn d > 1, dann Ausgabe: d    # Teiler von n gefunden\nStartwert",
                "Die Laufzeit hängt außerdem ab:\n·  von der Folgenfunktion f, die man ebenfalls ändern kann,\n    so lange sie ganzzahlige Werte behält\n·  vom Modul n, den man nicht ändern kann,\n    wenn man ihn gerade faktorisieren will\n∅x := f(x) (mod n)",
                "Der Algorithmus findet den Kreis schneller, wenn man neben dem letzten das vorletzte x\u{E002}j\u{E003} aufhebt:  y und y1\nUnten rechnet man dann:\nd := ggT( (x–y)·(x–y1), n)\ny1 := y\ny := 0P",
                "Um einen Kreis mod n zu finden, reicht der Test, ob x = y",
            ]),
            ZTPage(id: "5.3 - Pollard Rho demo", title: "Pollard Rho in Aktion", tool: .pollardRho, blocks: [
                " ∈ ℕ\n⇔\u{E002}xi+\u{E003}1 := \u{E002}x\u{E003}\u{E000}i\u{E001}2 + 1 (mod n)",
                "⇔sqrt( sqrt(n) ) + 1000  wird durch\n10⌊Stellenzahl(n) / 4⌋ + 1000 angenähert.",
                "⊂j    \u{E002}x\u{E003}j      i    \u{E002}x\u{E003}i     Limit für i:",
                "Es wurde kein nicht-trivialer Teiler gefunden.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.4", title: "Pollards p–1-Faktorisierung", pages: [
            ZTPage(id: "5.4 - 01", title: "Die Idee von Pollards p–1", tool: .pollardPm1, blocks: [
                "Pollard fand auch eine Faktorisierungs-Methode, die den \"kleinen Fermat\" einspannt.\nEine Zahl n habe den Primteiler p. Sei a teilerfremd zu n – und damit zu p – zufällig gewählt.\n⇒      a\u{E000}p–1\u{E001} ≡ 1 mod p    \"kleiner Fermat\"\n⇒      p | a\u{E000}p–1\u{E001}–1",
                "⇒      ggT( a\u{E000}p–1\u{E001}–1, n ) > 1\nFalls     ggT( a\u{E000}p–1\u{E001}–1, n ) < n,  hätte man einen nicht-trivialen Teiler von n gefunden – doch leider\nkennt man den Exponenten p–1 nicht, wenn man p nicht kennt.",
                "Idee:    Nimm als Exponenten ein Vielfaches von p–1.\n1. Wegen  a\u{E000}(p–1)·z\u{E001} = (a\u{E000}p–1\u{E001})\u{E000}z\u{E001} ≡ 1 mod p  geht obiger Trick auch mit (p–1)·z für alle z ∈ ℤ.\n2. Wähle zum Exponenten ein Produkt k aus vielen Primzahlen – und hoffe, dass p–1 | k.",
                "Sei     p | a\u{E000}p–1\u{E001}–1  und glücklicher Weise  p–1 | k.\n⇒    p | a\u{E000}k\u{E001}–1    Man berechnet a\u{E000}k\u{E001} (mod n) mit \"square & multiply\".\n⇒    p | a\u{E000}k\u{E001} (mod n) – 1    Denn die Reduktion mod n zieht Vielfache von p ab, weil p | n.\nFalls    ggT(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  ist man erfolgreich fertig.",
            ]),
            ZTPage(id: "5.4 - faktbas", title: "Faktorbasis und B-Glattheit", tool: .pollardPm1, blocks: [
                "Sei     p | a\u{E000}p–1\u{E001}–1  und  p–1 | k.\n⇒    p | a\u{E000}k\u{E001}–1    Man berechnet a\u{E000}k\u{E001} (mod n) mit \"square & multiply\".\n⇒    p | a\u{E000}k\u{E001} (mod n) – 1    Denn die Reduktion mod n zieht Vielfache von p ab.\nFalls    ggT(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  ist man erfolgreich fertig.",
                "Sei     p | a\u{E000}p–1\u{E001}–1  und  p–1 | k.",
                "Falls    ggT(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  ist man erfolgreich fertig.",
                "Den Exponenten k baut man so:\nMan wählt eine Zahl B und berechnet k als Produkt aller Primzahlpotenzen ≤ B.\nBeispiel:    B = 10     ⇒       k = 2\u{E000}3\u{E001}·5·7 = 280",
                "Sollte Fermat oder ein anderes Genie früherer Zeiten\nauf die Idee der p–1-Faktorisierung gekommen sein,\nso brach ihnen die Berechnung von a\u{E000}k\u{E001} das Genick.\nAuf der nächsten Seite sehen Sie Beispiele.\nAllerdings darf der Exponent auch nicht so groß sein, dass die Berechnung der Potenz länger dauert als die Probedivision bis zur Wurzel von n.",
                "Dieser Begriff ist angelehnt an den Begriff B-glatt:\n    Wenn p–1 keine Primzahl > B als Teiler hat, heißt  p–1 B-glatt.\nB-Glätte macht keine Einschränkung beim Exponenten eines Primteilers.\nBeispiel:      2\u{E000}3\u{E001}·5·7 = 280 ist 7-glatt, aber nicht 7-satt.",
                "Wenn  p–1 | k,  wenn also p–1 keine Primzahlpotenz > B als Teiler hat, dann heißt p–1 B-satt.\n\nDie p–1-Methode hofft auf einen Primteiler p von n, für den p–1 B-satt ist.\nDaher wünscht man sich B möglichst groß.",
                "Ist aber B zu groß, dann gilt für alle Primteiler q von n, dass q–1 B-satt ist.\n⇒    q | a\u{E000}k\u{E001} (mod n) – 1    für alle Primteiler q von n\nHat nun n keinen Primteiler q mehrfach, dann gilt:\n    ggT(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) = n.   Man findet also keinen Teiler < n.",
                "Der Fall ggT = n bedeutet allgemein: Die Ordnung von [a]\u{E002}n\u{E003} teilt k. Deutlich ist das bei a = 1.\nMan verkleinert dann also B oder ändert a. Es gibt aber Zahlen n, bei denen nichts hilft:  Beispiel",
            ]),
            ZTPage(id: "5.4 - p-1 demo", title: "Pollard p–1 in Aktion", tool: .pollardPm1, blocks: [
                "Das ist schon ein echter Teiler von n. Glück gehabt!",
                "    ⇒  a ist teilerfremd zu allen Teilern von n.\n    Sei p ein Primteiler von n, und gelte glücklicher Weise p–1 | k.\n      ⇒  a\u{E000}k\u{E001} ≡ 1 mod p,      denn a\u{E000}p–1\u{E001} ≡ 1 mod p (\"kleiner Fermat\")\n      ⇒  p | a\u{E000}k\u{E001}–1\n      ⇒  p | a\u{E000}k\u{E001} (mod n) –1,    denn die Reduktion zieht Vielfache von p ab.\n      ⇒  ggT( a\u{E000}k\u{E001} (mod n) –1, n ) > 1\na\u{E000}k\u{E001} (mod n)",
            ]),
            ZTPage(id: "5.4 - ECM", title: "Elliptische Kurven (ECM)", tool: .factorize, blocks: [
                "Betrachten Sie a\u{E000}k\u{E001} in der Zerlegung Z\u{E002}n\u{E003} @ Z\u{E002}p\u{E003}× Z\u{E002}q\u{E003}× ... .\nggT( a\u{E000}k\u{E001}–1, n) liefert ein Vielfaches von p,\nwenn a\u{E000}k\u{E001}–1 = (0, ...)\nalso   a\u{E000}k\u{E001}     = (1, ...)\nMan hofft, durch Potenzieren mit k das neutrale Element 1 der Gruppe Z\u{E002}p\u{E003}* zu erreichen.\nDas gelingt, wenn man mit k glücklicherweise ein Vielfaches der Gruppen-Ordnung p–1 trifft.\nNun gibt es neben den Restklassengruppen auch Gruppen zu p mit anderer Ordnung als p–1.\nSie bieten k neue Treffer-Chancen.\nDarauf beruht die Faktorisierung mit der elliptischen-Kurven-Methode (ECM).\nBeschreibungen sind im Literaturverzeichnis unter [Elliptische Kurven] genannt.",
                "Sie benutzt als Exponenten die globale Variable pollardk,\ndie man durch die Funktion faktbas(b) aus der Datei prims.txt berechnen lässt.\nDa BC nicht besonders schnell ist, erzeugt schon faktbas(10000) einen Exponenten,\nbei dem die Berechnung spürbar Zeit in Anspruch nimmt. Er hat 4349 Dezimalstellen.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.5", title: "Das Quadratische Sieb", pages: [
            ZTPage(id: "5.5 - 01", title: "Das Quadratische Sieb", tool: .factorize, blocks: [
                "/Beschreibung fast wörtlich aus [Buchmann]:\n\nEines der effizientesten Faktorisierungsverfahren ist das Quadratische Sieb.\nDas Prinzip:\nEs werden ganze Zahlen x und y bestimmt, für die gilt:\n   x2 ≡ y2 mod n  und\n   x  ≠ ±y  mod n\nDann ist n ein Teiler von x2 – y2 = (x – y)·(x + y), aber weder von x – y noch von x + y.\nAlso ist ggT(x – y, n) ein echter Teiler von n.\nBestimmung von x und y:\nDas beschriebene Prinzip wird auch in anderen Faktorisierungsalgorithmen angewendet, z.B. im Zahlkörpersieb. Die Verfahren unterscheiden sich darin, wie x und y berechnet werden.\nBeim Quadratischen Sieb geht es so:\n\nSei  m = ⌊√n⌋  und  f(X) = (X + m)2 – n.\nBeispiel:  n = 7429.  Also ist  m = 86,   f(X) = (X + 86)2 – 7429. Es gilt\n  f(–3)  =  832 – 7429  =  –540  =  –1·22·33·5\n  f(1)    =  872 – 7429  =    140  =       22·5·7\n  f(2)    =  882 – 7429  =    315  =       32·5·7\nHieraus folgt\n  832  ≡  –1·22·33·5 mod 7429\n  872  ≡       22·5·7 mod 7429\n  882  ≡       32·5·7 mod 7429\nMultipliziert man die letzten beiden Kongruenzen, so erhält man\n  (87·88)2 ≡ (2·3·5·7)2 mod n\nAlso setzt man\n  x = 227 ≡ 87·88 mod n\n  y = 210 ≡ 2·3·5·7 mod n\n\nIn diesem Beispiel werden Zahlen s angegeben, für die f(s) nur kleine Primfaktoren hat. Wie man solche Zahlen findet, wird weiter unten erklärt. Es wird ausgenutzt, dass\n  (s + m)2 ≡ f(s) mod n \nist, und es werden Kongruenzen dieser Form ausgewählt, deren Produkt auf der linken und rechten Seite ein Quadrat ergibt. Auf der linken Seite einer Kongruenz steht ohnehin ein Quadrat. Das Produkt beliebiger linker Seiten ist also immer ein Quadrat. Auf der rechten Seite ist die Primfaktorzerlegung bekannt. Man erhält also ein Quadrat, wenn die Exponenten aller Primfaktoren und der Exponent von –1 gerade sind.\n\nAuswahl geeigneter Kongruenzen:\nIm obigen Beispiel kann man direkt sehen, welche Kongruenzen multipliziert werden müssen, damit das Produkt der rechten Seiten der Kongruenzen ein Quadrat ergibt. Bei großen Zahlen n muss man die geeigneten Kongruenzen aus mehr als 100000 möglichen Kongruenzen auswählen. Dazu wendet man lineare Algebra an.\nAus den Kongruenzen des vorigen Beispiels werden die geeigneten durch Lösung eines linearen Gleichungssystems ausgewählt. Drei Kongruenzen stehen zur Wahl. Daraus sollen die Kongruenzen so ausgewählt werden, dass das Produkt der rechten Seiten ein Quadrat ergibt. Man sucht also Zahlen u, v, w ∈ {0, 1}, für die\n   (–1·22·33·5)u · (22·5·7)v · (32·5·7)w\n   (–1)u · 22·u+2·v · 33·u+2·w · 5u+v+w · 7v+w\nein Quadrat ist. Diese Zahl ist genau dann ein Quadrat, wenn der Exponent von –1 und die Exponenten aller Primzahlen gerade sind. Man erhält das folgende Kongruenzsystem:\n           u ≡ 0 mod 2\n  2·u+2·v ≡ 0 mod 2\n 3·u+2·w ≡ 0 mod 2\n   u+v+w ≡ 0 mod 2\n       v+w ≡ 0 mod 2\nDie Koeffizienten der Unbekannten u, v, w kann man modulo 2 reduzieren. Man erhält dann das vereinfachte System\n           u ≡ 0 mod 2\n   u+v+w ≡ 0 mod 2\n       v+w ≡ 0 mod 2.\nDaraus erhält man die Lösung\n   u = 0,  v = w = 1.\n\nallgemein:\nMan wählt eine natürliche Zahl B. Gesucht werden kleine ganze Zahlen s, für die f(s) nur Primfaktoren in der Faktorbasis  F(B) = {p ∈ ℙ: p ≤ B} ∪ {–1}  hat.\nSolche Werte f(s) heißen B-glatt. Hat man so viele Zahlen gefunden, wie die Faktorbasis Elemente hat, so stellt man das entsprechende lineare Kongruenzsystem auf und löst es.\nDa das Kongruenzsystem ein lineares Gleichungssystem über dem Körper Z2 ist, kann man zu seiner Lösung den Gauß-Algorithmus verwenden. Da aber die Anzahl der Gleichungen und Variablen im allgemeinen sehr groß ist, verwendet man statt dessen spezialisierte Verfahren, auf die hier nicht näher eingegangen wird. (Buchmann erwähnt an anderer Stelle einen Algorithmus von Wiedemann für dünn besetzte Gleichungssysteme).\n\nDas Sieb:\nEs bleibt noch zu klären, wie die Zahlen s gefunden werden, für die f(s) B-glatt ist. Man könnte für s = 0, ±1, ±2, ... den Wert f(s) berechnen und dann durch Probedivision testen, ob f(s) B-glatt ist. Das ist aber sehr aufwendig. Um herauszufinden, dass f(s) nicht B-glatt ist, muss man nämlich durch alle Primzahlen p ≤ B dividieren. In der Regel sind die Faktorbasen sehr groß, daher kann die Probedivision sehr lange dauern. Schneller geht ein Siebverfahren.\nMan fixiert ein Siebintervall S = {–C, –C+1, ...,–1, 0, 1, ..., C–1, C}.\nGesucht werden alle s∈S, für die f(s) B-glatt ist. Man berechnet zuerst alle Werte f(s), s∈S.\nFür jede Primzahl p der Faktorbasis dividiert man alle Werte f(s) durch die höchstmögliche p-Potenz. Die B-glatten Werte f(s) sind genau diejenigen, bei denen eine 1 oder –1 übrig bleibt.\n\nUm herauszufinden, welche Werte f(s) = (s + m)2 – n durch eine Primzahl p der Faktorbasis teilbar sind, bestimmt man zuerst die Zahlen s∈{0, 1, ..., p–1}, für die f(s) durch p teilbar ist. Da das Polynom f(X) höchstens zwei Nullstellen modulo p hat, sind das entweder zwei, eine oder keine Zahl s. Für kleine Primzahlen kann man die Nullstellen durch Ausprobieren finden.\nIst p groß, muss man andere Methoden anwenden (siehe unten [4]). Geht man von diesen\nNullstellen in Schritten der Länge p nach rechts und links durch das Siebintervall, so findet man alle s-Werte, für die f(s) durch p teilbar ist. Diesen Vorgang nennt man Sieb mit p. Man dividiert dabei nur die teilbaren Werte f(s). Es gibt keine erfolglosen Probedivisionen mehr.\n\nBeispiel:\nwie oben  n = 7429,  m = 86,   f(X) = (X + 86)2 – 7429.\nAls Faktorbasis wähle die Menge {2, 3, 5, 7} ∪ {–1}\nund als Siebintervall die Menge {–3, –2, ..., 3}.  Das Sieb sieht dann so aus:\n\ns       –3        –2        –1       0       1       2       3\n(s + m)2 – n    –540    –373    –204    –33    140    315    492\nSieb mit 2    –135          –51          35        123\nSieb mit 3       –5          –17    –11          35      41\nSieb mit 5       –1                   7       7\nSieb mit 7                       1       1\n\n\nDas Sieb kann noch sehr viel effizienter gestaltet werden. Siehe [28].\n\nLiteratur:\n[4]     E. Bach and J. Shallit. Algorithmic number theory. MIT Press, Cambridge, Massachusetts     and London, England, 1996.\n[28]    H. Riesel. Prime numbers and computer methods for factorization. Birkhäuser, 1994.",
                "Ende des Kapitels",
            ]),
        ]))
        return ZTLesson(number: 5, title: "Faktorisierung", chapters: chapters)
    }
    static func lesson6() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "6.1", title: "Exponenten finden", pages: [
            ZTPage(id: "6.1 - 01", title: "Diskrete Logarithmen", tool: .dlogEnum, blocks: [
                "Gegeben sei eine endliche zyklische Gruppe G, ein Erzeuger g von G und ein Element a.\nDie kleinste nicht negative Zahl x mit g\u{E000}x\u{E001} = a heißt diskreter Logarithmus von a zur Basis g.",
                "· eine Primzahl, z.B. 2, oder\n· eine Potenz einer ungeraden Primzahl, z.B. 9, oder\n· das Doppelte davon, z.B. 4 oder 18.\n(Z/m)* ist zyklisch  ⇔  m ist",
                "Der diskrete Logarithmus ist in der Regel sehr unregelmäßig und schwer zu bestimmen.\n\nBeim Aufzählungs-Verfahren – vornehm: Enumeration – setzt man für x der Reihe nach\nalle Gruppenelemente ein und testet, ob g\u{E000}x\u{E001} = a ist. Das kann allerdings sehr lange dauern.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.2", title: "Shanks Babystep-Giantstep-Methode", pages: [
            ZTPage(id: "6.2 - 01", title: "Die Babystep-Giantstep-Idee", tool: .bsgs, blocks: [
                "Dieser Algorithmus löst g\u{E000}x\u{E001} = a schneller als die Enumeration, braucht aber mehr Speicherplatz:\n          Löse die untere Gleichung, grob gesagt, so:\n          Sammle alle rechten Seite, vergleiche damit die linken Seiten, bis es passt.\nSetze  w = ⌈√n ⌉ , wobei n die Gruppen-Ordnung ist.\nIdee:   g\u{E000}x\u{E001} = g\u{E000}q·w+r\u{E001} = a             (mit q, r ∈ ℕ\u{E002}0\u{E003} und  0 ≤ r < w)\n          ⇔   g\u{E000}q·w\u{E001} = a·g\u{E000}–r \u{E001}",
                "Die gesammelten rechten Seiten bilden die Babysteps B = { (a·g\u{E000}–r\u{E001}, r) | 0 ≤ r < w }.\nEnthält B ein Paar (1, r), so ist man mit  q = 0  und  x = r  sofort fertig.",
                "Giantsteps: Prüfe für q = 1, 2, 3, ..., ob B ein Paar (g\u{E000}q·w\u{E001}, ...) enthält.\nDann ist die zweite Komponente des Paares das gesuchte r, und es gilt   g\u{E000}q·w\u{E001} = a·g\u{E000}–r\u{E001},\nund damit ist der diskrete Logarithmus   x = q·w + r   gefunden.\nZur Beschleunigung setzt man am Anfang d = g\u{E000}w\u{E001}  und berechnet in jedem Giantstep nur d\u{E000}q\u{E001}.",
                "Um möglichst schnell prüfen zu können, ob B ein Paar (d\u{E000}q\u{E001}, ...) enthält,\nordnet man die Babysteps nach ihren ersten Komponenten in eine Hashtabelle ein.",
            ]),
            ZTPage(id: "6.2 - Baby-Giant", title: "Babystep-Giantstep in Aktion", tool: .bsgs, blocks: [
                "6.2 Shanks Babystep-Giantstep-Methode – Beispiele in Z\u{E002}m\u{E003}*",
                "Babysteps (a·g\u{E000}–r\u{E001}, r),  0 ≤ r < w.           Hashtabelle",
                "Sobald  g\u{E000}w·q\u{E001} = a·g\u{E000}–r\u{E001},  ist  a = g\u{E000}w·q+r\u{E001} = g\u{E000}x\u{E001}.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.3", title: "Pollards Rho-Algorithmus", pages: [
            ZTPage(id: "6.3 - 01", title: "Pollards Rho für Logarithmen", tool: .dlogEnum, blocks: [
                "Um g\u{E000}x\u{E001} = a in G mit Erzeuger g zu lösen, kann man auch Pollards Rho-Algorithmus benutzen.\nSein Vorteil: konstanter Speicherbedarf. Wie bei seiner Anwendung zur Faktorisierung\nberechnet man eine Pseudo-Zufalls-Folge und sucht darin nach einem Zyklus:",
                "Dafür zerlegt man G in drei Teilmengen \u{E002}G\u{E003}1, \u{E002}G\u{E003}2, \u{E002}G\u{E003}3 und definiert f: G → G mit\n    g·b    falls b ∈ \u{E002}G\u{E003}1\n    f(b) =    \u{E000}b\u{E001}2    falls b ∈ \u{E002}G\u{E003}2\n    a·b    falls b ∈ \u{E002}G\u{E003}3\nMan wählt \u{E002}z\u{E003}1 ∈ {1, ..., |G|} zufällig, setzt    b1 = gz1     und macht weiter mit bi+1 = f(bi).",
                "Dabei führt man Buch über die Anzahl der Faktoren g und a. Man setzt  y\u{E002}1\u{E003} = 0  und dann:\n    z\u{E002}i\u{E003} + 1    (mod |G|)    falls b\u{E002}i\u{E003} ∈ G\u{E002}1\u{E003}    y\u{E002}i\u{E003}         falls b\u{E002}i\u{E003} ∈ G\u{E002}1\u{E003}\n    z\u{E002}i+1\u{E003} =    2·z\u{E002}i\u{E003}     (mod |G|)    falls b\u{E002}i\u{E003} ∈ G\u{E002}2\u{E003}         y\u{E002}i+1\u{E003} =    2·y\u{E002}i\u{E003}     (mod |G|)    falls b\u{E002}i\u{E003} ∈ G\u{E002}2\u{E003}\n    z\u{E002}i\u{E003}         falls b\u{E002}i\u{E003} ∈ G\u{E002}3\u{E003}    y\u{E002}i\u{E003} + 1    (mod |G|)    falls b\u{E002}i\u{E003} ∈ G\u{E002}3\u{E003}    z zählt die Faktoren g,     y zählt die Faktoren a.\nFür die Folgenglieder gilt:       b\u{E002}i\u{E003} = g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i",
            ]),
            ZTPage(id: "6.3 - Pollard log", title: "Die Kongruenz lösen", tool: .dlogEnum, blocks: [
                "Für die Folgenglieder b\u{E002}i\u{E003} ∈ G gilt:     b\u{E002}i\u{E003} = g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i\n\nGemäß Geburtstagsparadox wiederholen sich die Folgenglieder b\u{E002}i\u{E003} nach k ≈ √ |G| Schritten.",
                "Dann gilt:    g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i  =  g\u{E000}z\u{E001}i+k · a\u{E000}y\u{E001}i+k\nund damit:    g\u{E000}z\u{E001}i \u{E000}– z\u{E001}i+k  =  a\u{E000}y\u{E001}i+k \u{E000}– y\u{E001}i\nFür den diskreten Logarithmus x von a zur Basis g  gilt also:     z\u{E002}i \u{E003}–z\u{E002}i+k\u{E003}  ≡  x·(y\u{E002}i+k\u{E003} – y\u{E002}i\u{E003})  mod |G|",
                "Hat diese Kongruenz mehrere Lösungen, so findet man die richtige durch Ausprobieren.\nSind es zu viele, so wiederholt man die Berechnung mit einem neuen Startwert z\u{E002}1\u{E003}.\n\nBeispiele in primen Restklassengruppen:",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.4", title: "Weitere Verfahren", pages: [
            ZTPage(id: "6.4 - 01", title: "Weitere Verfahren", tool: .dlogEnum, blocks: [
                "Buchmann setzt die Beschreibung fort mit stärkeren Verfahren:\n\n·  Pohlig-Hellman-Algorithmus\n    Kennt man die Primfaktorzerlegung der Gruppen-Ordnung |G|,\n    so löst man g\u{E000}x\u{E001} = a in vielen kleinen Gruppen\n    und konstruiert daraus die Lösung in G.\n\n·  Index-Calculus-Methoden\n    Sie sind verwandt mit Quadratischem Sieb und Zahlkörpersieb bei der Faktorisierung.",
                "Ende des Kapitels",
            ]),
        ]))
        return ZTLesson(number: 6, title: "Diskrete Logarithmen", chapters: chapters)
    }
    static let glossary: [ZTGlossaryEntry] = [
        ZTGlossaryEntry(term: "abgeschlossen", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Addition von Restklassen", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "algebraische Struktur", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Alphabet", pageID: "4.1 - Cäsar"),
        ZTGlossaryEntry(term: "assoziativ", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "asymmetrische Verschlüsselung", pageID: "4.1 - asym"),
        ZTGlossaryEntry(term: "Ausklammern von Nullstellen", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "B-satt", pageID: "5.4 - faktbas"),
        ZTGlossaryEntry(term: "Babystep-Giantstep-Algorithmus", pageID: "6.2 - 01"),
        ZTGlossaryEntry(term: "bijektiv", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "binomische Formel", pageID: "2.4 - zyklisch komplett"),
        ZTGlossaryEntry(term: "Brent, Kreisfindungs-Algorithmus", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "Carmichael-Zahl", pageID: "3.2 - Carmichael"),
        ZTGlossaryEntry(term: "cartesisches Produkt", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "Chiffretext", pageID: "4.1 - 01"),
        ZTGlossaryEntry(term: "Chinesischer Restsatz", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "Cäsar-Verschlüsselung", pageID: "4.1 - Cäsar"),
        ZTGlossaryEntry(term: "Diffie-Hellman-Schlüsselaustausch", pageID: "4.3 - Diffie-Hellman"),
        ZTGlossaryEntry(term: "digitale Signatur", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "direktes Produkt", pageID: "2.2 - Zerlegung Ring"),
        ZTGlossaryEntry(term: "diskreter Logarithmus", pageID: "6.1 - 01"),
        ZTGlossaryEntry(term: "distributiv", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Division mit Rest", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "Dreieckszahlen", pageID: "2.1 - Wozu mod"),
        ZTGlossaryEntry(term: "Einheit", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Einheitengruppe", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Einselement", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Einwegfunktion", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "ElGamal-Verschlüsselung", pageID: "4.3 - ElGamal"),
        ZTGlossaryEntry(term: "elliptische Kurven", pageID: "4.3 - ElGamal2"),
        ZTGlossaryEntry(term: "elliptische Kurven, Faktorisierung", pageID: "5.4 - ECM"),
        ZTGlossaryEntry(term: "Entschlüsselungfunktion", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "Enumeration", pageID: "6.1 - 01"),
        ZTGlossaryEntry(term: "Eratosthenes, Sieb des", pageID: "1.2 - Eratosthenes"),
        ZTGlossaryEntry(term: "Erzeuger", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "Erzeugnis", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "Euklidischer Algorithmus", pageID: "1.3 - Euklid Ablauf"),
        ZTGlossaryEntry(term: "Euler-Fermat, Satz von", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Euler-Funktion", pageID: "2.2 - Euler-Funktion"),
        ZTGlossaryEntry(term: "Euler-Funktion, Berechnung (1)", pageID: "2.2 - Berechnung Euler 1"),
        ZTGlossaryEntry(term: "Euler-Funktion, Berechnung (2)", pageID: "2.2 - Berechnung Euler 2"),
        ZTGlossaryEntry(term: "Faktorisierung", pageID: "5.1 - 01"),
        ZTGlossaryEntry(term: "Faktorzerlegung", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "Fermat, Faktorisierung", pageID: "5.2 - 01"),
        ZTGlossaryEntry(term: "Fermat, großer Satz von", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Fermat, kleiner Satz von", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Fermat-Test", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "Fermat-Zahl", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "Floyd, Kreisfindungs-Algorithmus", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "Fundamentalsatz der Zahlentheorie", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "ganzzahliger Quotient", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "Geburtstagsparadox", pageID: "5.3 - 01"),
        ZTGlossaryEntry(term: "ggT", pageID: "1.1 - Def ggT"),
        ZTGlossaryEntry(term: "ggT als Vielfachsumme", pageID: "1.3 - Eigenschaften ggT"),
        ZTGlossaryEntry(term: "Gruppe", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Halbgruppe", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Homomorphismus", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Häufigkeitsanalyse", pageID: "4.1 - Häuf"),
        ZTGlossaryEntry(term: "injektiv", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "inverses Element", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Isomorphismus", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "kanonische Primfaktorzerlegung", pageID: "1.2 - kanonische PFZ"),
        ZTGlossaryEntry(term: "kgV", pageID: "1.4 - 01"),
        ZTGlossaryEntry(term: "Klartext", pageID: "4.1 - 01"),
        ZTGlossaryEntry(term: "kleiner Fermat", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Koeffizienten einer Vielfachsumme", pageID: "1.3 - 01"),
        ZTGlossaryEntry(term: "kommutativ", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Komplementärteiler", pageID: "1.1 - 01"),
        ZTGlossaryEntry(term: "Kongruenz", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "Kongruenzen lösen", pageID: "2.2 - Kongruenzen lösen"),
        ZTGlossaryEntry(term: "Kreisfindungs-Algorithmen", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "Körper", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Lagrange, Satz von", pageID: "2.3 - Lagrange"),
        ZTGlossaryEntry(term: "Lucas-Lehmer-Test", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "Lösungen von Kongruenzen", pageID: "2.2 - Kongruenzen lösen"),
        ZTGlossaryEntry(term: "Lügner", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "Lügner, starker", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "Mersenne-Zahl", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "Miller-Rabin-Test", pageID: "3.3 - 01"),
        ZTGlossaryEntry(term: "Modul", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "Monoid", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Montgomery-Multiplikation", pageID: "2.2 - modulare Potenz"),
        ZTGlossaryEntry(term: "Multiplikation von Restklassen", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "neutrales Element", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Nullelement", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Nullstelle", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "Nullteiler", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Ordnung einer Gruppe", pageID: "2.3 - |G|"),
        ZTGlossaryEntry(term: "Ordnung eines Elements", pageID: "2.3 - ord(a)"),
        ZTGlossaryEntry(term: "Ordnung eines Elements berechnen", pageID: "2.3 - ord(a) berechnen"),
        ZTGlossaryEntry(term: "Ordnung eines Zeugen", pageID: "3.2 - Zeugen Staffel"),
        ZTGlossaryEntry(term: "Pollard, p–1: Faktorisierung", pageID: "5.4 - 01"),
        ZTGlossaryEntry(term: "Pollard, Rho: diskreter Logarithmus", pageID: "6.3 - 01"),
        ZTGlossaryEntry(term: "Pollard, Rho: Faktorisierung", pageID: "5.3 - 01"),
        ZTGlossaryEntry(term: "Polynom", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "positives Erzeugnis", pageID: "2.3 - pos Erz"),
        ZTGlossaryEntry(term: "Potenzen bei Assoziativität", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Potenzen in einer Gruppe", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "prim", pageID: "1.1 - Def ggT"),
        ZTGlossaryEntry(term: "prime Restklasse", pageID: "2.2 - Zm*"),
        ZTGlossaryEntry(term: "prime Restklassengruppe", pageID: "2.2 - Zm*"),
        ZTGlossaryEntry(term: "Primfaktor", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "Primfaktorzerlegung", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "primitive Restklasse", pageID: "2.4 - 01"),
        ZTGlossaryEntry(term: "Primitivwurzel", pageID: "2.4 - 01"),
        ZTGlossaryEntry(term: "Primitivwurzeln berechnen", pageID: "2.4 - finden"),
        ZTGlossaryEntry(term: "Primteiler", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "Primzahl", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "Primzahlsatz", pageID: "3.1 - 01"),
        ZTGlossaryEntry(term: "Primzahltest", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "privater Schlüssel", pageID: "4.1 - asym"),
        ZTGlossaryEntry(term: "probabilistischer Test", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "Probedivision", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "Pseudoprimzahl", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "Pseudoprimzahl, starke", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "quadratischer Rest", pageID: "5.2 - Quadrate erkennen"),
        ZTGlossaryEntry(term: "Quadratisches-Sieb-Verfahren", pageID: "5.5 - 01"),
        ZTGlossaryEntry(term: "Quersummen", pageID: "2.1 - Quersummen"),
        ZTGlossaryEntry(term: "Rabin-Verschlüsselung", pageID: "4.3 - 01"),
        ZTGlossaryEntry(term: "Reduktion mod m", pageID: "2.1 - Standardvertreter"),
        ZTGlossaryEntry(term: "regulär", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Rest", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "Restklasse", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "Restklasse, Menge aller", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "Restklassenring", pageID: "2.1 - Restklassenring"),
        ZTGlossaryEntry(term: "Ring", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "RSA-Verschlüsselung", pageID: "4.2 - 01"),
        ZTGlossaryEntry(term: "Schlüssel", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "simultane Kongruenz", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "square & multiply", pageID: "2.2 - schnelle Potenz"),
        ZTGlossaryEntry(term: "Standardvertreter", pageID: "2.1 - Standardvertreter"),
        ZTGlossaryEntry(term: "surjektiv", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "teilbar", pageID: "1.1 - Teiler in Z"),
        ZTGlossaryEntry(term: "Teilbarkeitskriterien", pageID: "2.1 - Quersummen"),
        ZTGlossaryEntry(term: "Teilbarkeitsregeln", pageID: "1.1 - Teiler in Z"),
        ZTGlossaryEntry(term: "Teiler", pageID: "1.1 - 01"),
        ZTGlossaryEntry(term: "Teilermenge", pageID: "1.1 - Teilermenge"),
        ZTGlossaryEntry(term: "Text als Zahl", pageID: "4.1 - Text -> Zahl"),
        ZTGlossaryEntry(term: "Trapdoor-Funktion", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "Uhren verstellen", pageID: "2.2 - Uhren verstellen"),
        ZTGlossaryEntry(term: "Untergruppe", pageID: "2.3 - |G|"),
        ZTGlossaryEntry(term: "Verknüpfung", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Verschlüsselungsfunktion", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "Vertreter", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "Vielfachenmenge", pageID: "1.4 - 01"),
        ZTGlossaryEntry(term: "Vielfaches", pageID: "1.1 - 01"),
        ZTGlossaryEntry(term: "Vielfachsumme", pageID: "1.3 - 01"),
        ZTGlossaryEntry(term: "Vigenère-Verschlüsselung", pageID: "4.1 - Häuf"),
        ZTGlossaryEntry(term: "wohldefiniert", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "Zerlegung eines Ringes", pageID: "2.2 - Zerlegung Ring"),
        ZTGlossaryEntry(term: "Zeuge", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "Zeuge, starker", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "zusammengesetzte Zahl", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "zyklische Gruppe", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "zyklische prime Restklassengruppen", pageID: "2.4 - zyklisch komplett"),
        ZTGlossaryEntry(term: "Äquivalenzklasse", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "Äquivalenzrelation", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "öffentlicher Schlüssel", pageID: "4.1 - asym"),
    ]
}
