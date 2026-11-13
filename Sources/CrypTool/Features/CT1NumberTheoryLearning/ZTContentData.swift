// Generated from the content recovered out of NT.exe (Martin Ramberger, Authorware 4).
// Page texts are verbatim; \u{E000}…\u{E001} = superscript, \u{E002}…\u{E003} = subscript.

extension ZTContent {
    static func lesson1() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "1.1", title: "Divisibility", pages: [
            ZTPage(id: "1.1 - 01", title: "Divisors and complementary divisors", tool: .divisorPairs, blocks: [
                "Definition: Let d, n ∈ ℕ.\n    ·  d is a divisor of n, if there is a number z ∈ ℕ with d·z = n.\n    ·  If d is a divisor of n, then     is d's complementary divisor.\nWhen searching for divisors of n, only look for the divisors ≤ √n,\ntheir complementary divisors make up the rest.",
                "If n is a square number, n's number of divisors is odd, since one divisor \"appears twice\",\notherwise n's number of divisors is even.",
            ]),
            ZTPage(id: "1.1 - Teiler in Z", title: "Divisors in ℤ", tool: .divides, blocks: [
                "One can extend the concept of divisors on integers:\nDefinition: Let a, b ∈ ℤ.\n    a is a divisor of b, if z ∈ ℤ exists with a·z = b.\n    Notation: a | b. One says: a divides b, b is divisible by a,  b is a multiple of a.\n\nExample:      5 | –15,  since there exists –3 ∈ ℤ with 5·(–3) = –15",
                "Theorem: For all a, b, c ∈ ℤ the following divisibility rules hold:\n    1.  ±1 | a  and  ±a | a,    since    1·a = a = (–1)·(–a)  and  a·1 = a = (–a)·(–1).\n    2.  a | 1  ⇒  a = ±1,    \"    for a ≠ ±1 exists no z ∈ ℤ with a·z = ±1.\n    6.  a | b  ⇒  a·c | b·c,    \"    a·z = b  ⇒  b·c = (a·z)·c = (a·c)·z.\n    7.  a | b  ∧  b ≠ 0  ⇒  |a| ≤ |b|,    \"    a·z = b  ∧  z ≠ 0  ⇒  |a·z| ≥ |a|.\n    8.  a | b  ∧  b | a  ⇒  |a| = |b|,    \"    if a = 0, then b = 0 and vice versa,\n            otherwise is |a| ≤ |b| and |b| ≤ |a|, thus |a| = |b|.\n    3.  a | 0,    \"    a·0 = 0.\n    4.  0 | b  ⇒  b = 0,    \"    0·z = b  ⇒  b = 0.\n    5.  a | b  ∧  b | c  ⇒  a | c,    \"    a·z\u{E002}1\u{E003} = b  ∧  b·z\u{E002}2\u{E003} = c  ⇒  c = (a·z\u{E002}1\u{E003})·z\u{E002}2\u{E003} = a·(z\u{E002}1\u{E003}·z\u{E002}2\u{E003}).",
                "  1 divides a,      a divides a,\n–1 divides a,    –a divides a.",
                "If a divides 1, then a equals 1 or –1.\nIn other words: The only divisors of 1 are 1 and –1.",
                "Each number divides 0. Even 0 divides 0, since 0·z = 0 with any z ∈ ℤ.\nBut the division 0 by 0 is forbidden, because no z is defined as this division's result.",
                "Whenever 0 divides a number, this number is 0.\nThis means: Only 0 is divided by 0.\nOr: The only multiple of 0 is 0 itself.",
                "If a divides b and b divides c, then a divides c.\nThis means: divisibility is transitive.",
                "If a divides b, then a·c divides b·c.",
                "If a divides b and b is not 0, then a's absolute value is not greater than b's absolute value.",
                "If a divides b and b divides a, then a and b have equal absolute values.",
            ]),
            ZTPage(id: "1.1 - Teilermenge", title: "The divisor set", tool: .divisorSet, blocks: [
                "With each number a also –a is a divisor of b:   a | b  ⇔  –a | b.\nHence one simply looks for the positive divisors:\n\nDefinition:     For a ∈ ℤ the set T\u{E002}a\u{E003} = { x ∈ ℕ  |  x | a } is called divisor set of a.",
                "This line means:\n\"with the following property\"",
                "d | a  ⇔  d | –a,    since   a = d·z  ⇔  –a = d·(–z)",
                "3rd divisibility rule",
                "7th divisibility rule",
                "1st divisibility rule",
                "No divisor set is empty:  T\u{E002}a\u{E003} ≠ ∅  for all a.\nThe divisor set of 0 contains all natural numbers:  T\u{E002}0\u{E003} = ℕ.\nThe divisor sets for a ≠ 0 are finite.\n\nBecause of T\u{E002}a\u{E003} = T\u{E002}–a\u{E003} one can restrict the examination of divisor sets to a ∈ ℕ.",
            ]),
            ZTPage(id: "1.1 - Def ggT", title: "The greatest common divisor", tool: .gcdSets, blocks: [
                "Definition: If numbers a, b ∈ ℤ not both are 0, then the greatest number from T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}\n    is called the greatest common divisor of a and b, shortly GCD(a, b).\nThe GCD exists, since each divisor set contains the number 1, \nand at least one divisor set is finite, thus the intersection of the divisor sets is finite;\nbecause all natural numbers are comparable in respect of size,\neach finite non-empty set of natural numbers has a biggest element.",
                "Theorem: The following rules hold for the GCD:\n    1. GCD(a, b) = GCD(±a, ±b),     since  T\u{E002}a\u{E003} = T\u{E002}–a\u{E003}  and  T\u{E002}b\u{E003} = T\u{E002}–b\u{E003}\n    2. GCD(a, 0) = |a|  for a ≠ 0,    since  T\u{E002}0\u{E003} = ℕ    and  T\u{E002}a\u{E003} ∩ ℕ = T\u{E002}a\u{E003} = T\u{E002}|a|\u{E003}\n    3. GCD(a, 1) = 1,    since  T\u{E002}1\u{E003} = {1}  and  T\u{E002}a\u{E003} ∩ {1} = {1}\nBecause of rule 1 one can restrict the identification of GCD(a, b) on a, b ∈ ℕ.\nDefinition: Two numbers a, b ∈ ℤ are coprime or relatively prime, if GCD(a, b) = 1.\nmore Examples\nExample:     T\u{E002}–6\u{E003} = {1, 2, 3, 6},  T\u{E002}15\u{E003} = {1, 3, 5, 15},\n    T\u{E002}–6\u{E003} ∩ T\u{E002}15\u{E003} = {1, 3}  ⇒  GCD(–6, 15) = 3",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.2", title: "Primes", pages: [
            ZTPage(id: "1.2 - 01", title: "Primes", tool: .trialDivision, blocks: [
                "Definition:    A prime or prime number p is a natural number with exactly two positive divisors,\n    namely 1 and p itself. The set of all primes is called ℙ.\n\nNotice that 1 is no prime. The primes < 100 are:\n2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97.",
                "Definition:    If a prime p divides an integer a, then p is called prime divisor of a.\nTheorem:     Each natural number n > 1 has at least one prime divisor.    Proof",
                "From this Euclid got insight in the number of primes:\nTheorem:     There are infinitely many primes.    Proof",
                "Definition:     The natural numbers between the primes are called composite numbers.\nTheorem:     Each composite number n has a prime divisor p ≤ √ n.    Proof",
                "Thus, if an integer n > 1 is not divisible by any prime p ≤ √ n, then n is prime.\nExample:     89 is prime, since 2, 3, 5, 7 do not divide 89,  and 11 > √ 89.",
            ]),
            ZTPage(id: "1.2 - Eratosthenes", title: "The Sieve of Eratosthenes", tool: .sieve, blocks: [
                "Each composite number n has a prime divisor ≤ √ n. This is taken advantage of by the\nSieve of Eratosthenes. It finds all primes up to a limit g",
            ]),
            ZTPage(id: "1.2 - Erat mit Einsen", title: "Trial division", tool: .trialDivision, blocks: [
                "Each p-th number is a multiple of p: You can strike it out regardlessly.\nHence you can simply fill the sieve initially with 1s in order to save space.\nMoreover you can omit the even numbers. Then the i-th field represents the number 2·i – 1.\nIn the end the remaining 1s mark the primes > 2.",
            ]),
            ZTPage(id: "1.2 - Fundamentalsatz", title: "The fundamental theorem of arithmetic", tool: .factorize, blocks: [
                "The composite numbers can be represented as products of natural numbers > 1.\n\nExamples:    ·  4 = 2·2\n    ·  60 = 6·10 = 2·3·2·5  or  60 = 4·15 = 2·2·3·5\n\nA representation like this is called factor decomposition. A factor ∈ ℙ is called prime factor.\nA prime decomposition contains only prime factors.\nThe prime decomposition of a prime p consists of only one factor: p itself.",
                "Theorem:     If p ∈ ℙ divides a product of integers, then p divides at least one factor.\nProof:    The proof of this theorem is located about the end of chapter 1.3.\nAnnotation: For p ∉ ℙ there are counter-examples, e.g. p = 4 divides 2·10, but neither 2 nor 10.",
                "Thus holds the Fundamental Theorem of Arithmetic:\n\nTheorem:     Each natural number n > 1 has a unique prime decomposition\n    apart from rearrangement of the prime factors.\nProof",
            ]),
            ZTPage(id: "1.2 - Zahlenmenge 4n+1", title: "The number set 4n+1", tool: .hilbert, blocks: [
                "The theorem that each natural number > 1 has a unique prime decomposition seems trivial.\nBut it does not hold in each set of numbers.\nExample:     Consider H = {4·n + 1 | n ∈ ℕ\u{E002}0\u{E003}} = {1, 5, 9, 13, 17, 21, 25, 29, 33, ...}.",
                "    H is multiplicatively closed, this means:  a, b ∈ H  ⇒  a·b ∈ H.\n    Because:  (4·a+1)·(4·b+1)  =  16·a·b + 4·a + 4·b + 1  =  4·(4·a·b+a+b) + 1",
                "Primes are defined in H as numbers with exactly two divisors ∈ H.\nIf a ∈ H is prime in ℕ, then a is prime in H too.",
                "    Additionally there are primes in H which are no primes in ℕ,\n    for example:\n    ·  9    is prime in H. The decomposition 9 = 3·3 does not exist in H, since 3 ∉ H.\n    ·  77    is prime in H. The decomposition 7 = 7·11 does not exist in H, since 7 ∉ H.",
                "    And in H there are numbers with more than one prime decomposition,\n    for example:\n    ·  441 = 21·21 = 9·49    ·  1089 = 33·33 = 9·121\n    ·  3249 = 57·57 = 9·361    ·  5929 = 77·77 = 49·121",
            ]),
            ZTPage(id: "1.2 - kanonische PFZ", title: "Canonical prime decomposition", tool: .factorize, blocks: [
                "Usually one orders the factors of a prime decomposition by their size\nand combines equal factors in powers, for example:  200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001}",
                "Having numbered the primes consecutively,\n    p\u{E002}1\u{E003} = 2,   p\u{E002}2\u{E003} = 3,   p\u{E002}3\u{E003} = 5,   p\u{E002}4\u{E003} = 7,   p\u{E002}5\u{E003} = 11,  ...",
                "if the i-th prime occurs α\u{E002}i\u{E003} times in the prime decomposition of number a,",
                "        a = ∏ p\u{E002}i\u{E003}\u{E000}α\u{E001}i   =  p\u{E002}1\u{E003}\u{E000}α\u{E001}1 · p\u{E002}2\u{E003}\u{E000}α\u{E001}2 · p\u{E002}3\u{E003}\u{E000}α\u{E001}3 · ....\n\nExample:       200 = 2\u{E000}3\u{E001}·3\u{E000}0\u{E001}·5\u{E000}2\u{E001}·7\u{E000}0\u{E001}·11\u{E000}0\u{E001}·13\u{E000}0\u{E001}·...\nthen is",
                "This product has only finitely many factors,\nsince all primes which do not divide a, are neutralized by the exponent α\u{E002}i\u{E003} = 0.\n =  2\u{E000}3\u{E001}·1·5\u{E000}2\u{E001}·1·1·1·...  =  2\u{E000}3\u{E001}·5\u{E000}2\u{E001}",
                "p\u{E000}0\u{E001} = 1, and the factor 1 doesn't change the product.",
                "Definition:       a = ∏ p\u{E002}i\u{E003}\u{E000}α\u{E001}i   is called the canonical prime decomposition of a.\n\nIn the canonical prime decomposition of 1 are all exponents α\u{E002}i\u{E003} = 0.",
            ]),
            ZTPage(id: "1.2 - Anzahl Teiler", title: "Number of divisors", tool: .divisorCount, blocks: [
                "With the canonical prime decomposition you can find the divisors of a number a ∈ ℕ.\nNumber  d = ∏ p\u{E002}i\u{E003}\u{E000}δ\u{E001}i   is a divisor of  a = ∏ p\u{E002}i\u{E003}\u{E000}α\u{E001}i  ,  exactly if δ\u{E002}i\u{E003} ≤ α\u{E002}i\u{E003} for all i ∈ ℕ.",
                "Example:     The positive divisors d of a = 200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001} are:\n    2\u{E000}0\u{E001}·5\u{E000}0\u{E001} = 1    2\u{E000}0\u{E001}·5\u{E000}1\u{E001} = 5    2\u{E000}0\u{E001}·5\u{E000}2\u{E001} = 25\n    2\u{E000}1\u{E001}·5\u{E000}0\u{E001} = 2    2\u{E000}1\u{E001}·5\u{E000}1\u{E001} = 10    2\u{E000}1\u{E001}·5\u{E000}2\u{E001} = 50\n    2\u{E000}2\u{E001}·5\u{E000}0\u{E001} = 4    2\u{E000}2\u{E001}·5\u{E000}1\u{E001} = 20    2\u{E000}2\u{E001}·5\u{E000}2\u{E001} = 100\n    2\u{E000}3\u{E001}·5\u{E000}0\u{E001} = 8     2\u{E000}3\u{E001}·5\u{E000}1\u{E001} = 40    2\u{E000}3\u{E001}·5\u{E000}2\u{E001} = 200",
                "The negative divisors differ from the positive ones only by their signs.",
                "The positive divisors are formed by combinations of prime factors;\nin each combination the prime factor p\u{E002}i\u{E003} can occur at most α\u{E002}i\u{E003} times or miss completely.\nThis yields (α\u{E002}1\u{E003}+1)·(α\u{E002}2\u{E003}+1)·(α\u{E002}3\u{E003}+1)·.... possible combinations altogether.\nBecause of the uniqueness of the prime decomposition in ℕ each combination is a new divisor.\n(3+1) possibilities for prime factor 2\n(2+1) possibilities for prime factor 5",
                "Thus the number of positive divisors of a ∈ ℕ is ∏ (α\u{E002}i\u{E003}+1).\nExample:     200 = 2\u{E000}3\u{E001}·5\u{E000}2\u{E001}  has  (3+1)·(2+1) = 12  positive divisors.",
            ]),
            ZTPage(id: "1.2 - ggT mit Hilfe PFZ", title: "GCD by means of the prime decomposition", tool: .gcdFactor, blocks: [
                "Knowing the prime decompositions of two numbers a, b ∈ ℕ,\none can find GCD(a, b) without T\u{E002}a\u{E003} and T\u{E002}b\u{E003}.",
                "min(x, y) is the minimal element of x and y,\nthus x, if x ≤ y; otherwise y.",
                "If prime divisor p\u{E002}i\u{E003} occurs α\u{E002}i\u{E003} times in a and β\u{E002}i\u{E003} times in b, then min(α\u{E002}i \u{E003}, β\u{E002}i\u{E003}) times in GCD(a, b):\na = ∏ p\u{E002}i\u{E003}\u{E000}α\u{E001}i   ∧  b = ∏ p\u{E002}i\u{E003}\u{E000}β\u{E001}i    ⇒    GCD(a, b) = ∏ p\u{E002}i\u{E003}\u{E000}min(α\u{E001}i \u{E000}, β\u{E001}i\u{E000})\u{E001}",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.3", title: "Euclid's Algorithm", pages: [
            ZTPage(id: "1.3 - 01", title: "Linear combinations", tool: .linearCombination, blocks: [
                "Definition:    Let a, b ∈ ℤ.\n    Then a·x + b·y with x, y ∈ ℤ is called a linear combination of a and b.\n    The numbers x and y are called coefficients of the linear combination.",
                "Example:    a and b are clickable.",
                "Theorem:  Let a, b ∈ ℤ. Then for all x, y ∈ ℤ holds:\n    d | a  ∧  d | b    ⇒    d | a·x + b·y\n    Each common divisor of a, b divides each linear combination of a, b.   Proof\nThus only multiples of all common divisors of a, b can be linear combinations of a, b.",
                "Theorem:  Each linear combination has infinitely many representations.     Proof",
            ]),
            ZTPage(id: "1.3 - ggT(a,b)=ggT(b,a-b)", title: "GCD(a, b) = GCD(b, a – b)", tool: .subtractiveGcd, blocks: [
                "Let a, b ∈ ℤ.\nBy subtracting a multiple of b from a, one gets the following linear combination of a and b:\na – x·b = c\nHence holds:     d | a  ∧  d | b  ⇒  d | c",
                "By transforming the equation, one gets a as linear combination of b and c:\na = x·b + c\nHence holds too:     d | b  ∧  d | c  ⇒  d | a",
                "Hence in conjunction holds:    d | a  ∧  d | b  ⇔  d | b  ∧  d | c\nThis means for the divisor sets:    T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}     =     T\u{E002}b\u{E003} ∩ T\u{E002}c\u{E003}\nAnd so holds:    GCD(a, b)     =     GCD(b, c)\nExamples:     ·  1024    – 10·100    = 24,     thus is  GCD(1024, 100)  =  GCD(100, 24)\n    ·  100    – 4·24    = 4,      thus is  GCD(100, 24)  =  GCD(24, 4)\n    ·  24    – 6·4    = 0,      thus is  GCD(24, 4)  =  GCD(4, 0)  =  4",
            ]),
            ZTPage(id: "1.3 - Euklid Ablauf", title: "The steps of the Euclidian algorithm", tool: .euclid, blocks: [
                "a – z·b = r   ⇔   a = z·b + r\nSince r is linear combination of a and b holds:    d | a  ∧  d | b     ⇒     d | b  ∧  d | r\nSince a is linear combination of b and r holds:    d | b  ∧  d | r     ⇒     d | a  ∧  d | b\nHence holds:    d | a  ∧  d | b     ⇔     d | b  ∧  d | r\nhence:    T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003}     =     T\u{E002}b\u{E003} ∩ T\u{E002}r\u{E003}\nand hence:    GCD(a, b)     =     GCD(b, r)",
                "GCD(a, b) = GCD(±a, ±b)",
                "Euclid: \"Subtract from the first number a such multiple of the second number b that the",
                "When remainder = 0 stop. The last remainder > 0 is the GCD.",
            ]),
            ZTPage(id: "1.3 - die Teiler des ggT", title: "The divisors of the GCD", tool: .gcdSets, blocks: [
                "a–x·b is linear combination of a and b.",
                "Repeatedly one subtracts from the first number a multiple of the second number,\nso that the remainder ≥ 0 is as small as possible.",
                "Finally the remainder 0 is hit.",
                "r is the greatest number ∈ T\u{E002}r\u{E003} = T\u{E002}a \u{E003}∩ T\u{E002}b\u{E003}",
                "Euclid's algorithm accords with the following equations with r as last remainder > 0:\nT\u{E002}a \u{E003}∩ T\u{E002}b\u{E003}  =  T\u{E002}b \u{E003}∩ T\u{E002}a–x·b\u{E003}  =  ...  =  T\u{E002}r \u{E003}∩ T\u{E002}0\u{E003}  =  T\u{E002}r\u{E003}  =  T\u{E002}GCD(a,b)\u{E003}\nThus the common divisors of a and b are exactly the divisors of the GCD(a, b).",
                "Hence GCD(a, b) alternatively can be defined as follows:\nDefinition:     The number d ∈ ℕ\u{E002}0\u{E003} is called greatest common divisor of a and b, if holds:\n    1. d | a  and  d | b    d is common divisor.\n    2. t | a and t | b  ⇒  t | d    Each common divisor divides d.\n\nAfter this definition GCD(0, 0) = 0 is sensible, since:\n    1. 0 is common divisor.\n    2. Each common divisor – thus each integer – divides 0.",
                "Let's get back to the question:    Which numbers can be linear combinations of a and b?\nUntil now we knew:     Only multiples of all common divisors of a and b.\nThis means now:     Only multiples of the GCD(a, b).\n\nThe question remains: Can GCD(a, b) always be represented as linear combination of a and b?",
            ]),
            ZTPage(id: "1.3 - ggT als Vielfachsumme", title: "The GCD as linear combination", tool: .extEuclid, blocks: [
                "Euclid's algorithm calculates GCD(a, b). In this calculation one can represent all remainders\nas linear combinations of a and b and calculate their coefficients:",
                "GCD(a, b) = GCD(±a, ±b)\nThe coefficients react in their signs.",
                "One gets GCD(a, b) as linear combination of |a| and |b|.\nIf a < 0 or b < 0, one multiplies the corresponding coefficient by –1\nand gets GCD(a, b) as linear combination of a and b:",
            ]),
            ZTPage(id: "1.3 - Eigenschaften ggT", title: "Properties of the GCD", tool: .extEuclid, blocks: [
                "From the Euclidian algorithm follows thus:\nTheorem:   The divisors of GCD(a, b) are the common divisors of a and b.    Demonstration\nTheorem:   GCD(a, b) can be represented as linear combination of a and b.    Demonstration",
                "Also each multiple of GCD(a, b) can be as represented as linear combination of a and b:\n    GCD(a, b)  =  a·x + b·y    ⇒    GCD(a, b)·z  =  a·x·z + b·y·z\nSince only multiples of GCD(a, b) can be linear combinations of a and b, one gets as\nConsequence:    GCD(a, b) | d     ⇔    There are x, y ∈ ℤ, so that  d = a·x + b·y.",
                "Theorem:   GCD(a, b) = d   ⇔   GCD(   ,   ) = 1    Proof\nUsing linear combinations, it is easy to prove further properties:\nTheorem:   GCD(a, c) = 1  ∧  GCD(b, c) = 1   ⇒   GCD(a·b, c) = 1    Proof\nTheorem:   GCD(a, b) = 1  ∧  a | b·c   ⇒   a | c    Proof",
                "In chapter 1.2 the fundamental theorem of arithmetic was proved with the aid of the theorem:\n    If a prime divides a product of integers, then it divides at least one factor.\nHere is the proof of this theorem.",
            ]),
            ZTPage(id: "1.3 - ggT von mehr als 2 Zahlen", title: "GCD of more than 2 numbers", tool: .gcdMany, blocks: [
                "One can define the GCD of more than 2 numbers:\nDefinition:     Let k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k\u{E003} ∈ ℤ and k > 2. Then is      \u{E000}GCD( a\u{E001}1, \u{E000}a\u{E001}2, ..., ak ) = biggest number ∈ Ta\u{E002}1\u{E003} \u{E000}∩ T\u{E001}a\u{E002}2\u{E003} ∩ ... ∩ Ta\u{E002}k\u{E003} , if not all a = 0,\n    GCD( 0, 0, ..., 0 ) = 0.",
                "Coprime numbers are not necessarily pairwise coprime.   Example\n    If GCD(a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003}) = 1, then a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003} are called coprime.",
                "Theorem:      GCD( a, GCD(b, c) )  =  GCD( GCD(a, b), c )    Proof\n    GCD( a\u{E002}1\u{E003}, ..., a\u{E002}k+1\u{E003} )  =  GCD( GCD( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} ), a\u{E002}k+1\u{E003} )  for k ≥ 2    Proof\nWith the property T\u{E002}a\u{E003} ∩ T\u{E002}b\u{E003} = T\u{E002}GCD(a, b)\u{E003} can be shown:",
                "One can also define linear combinations of more than two numbers a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003}  and\nshow by induction that these linear combinations can represent GCD( a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003} ).\nTo make it short, here is only the proof for k = 3.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "1.4", title: "The LCM", pages: [
            ZTPage(id: "1.4 - 01", title: "The least common multiple", tool: .lcm, blocks: [
                "Definition:  Let a, b ∈ ℤ.\n    The number v ∈ ℕ\u{E002}0\u{E003} is called least common multiple of a and b, shortly LCM(a, b),\n    if holds:    1. a | v  and  b | v    v is common multiple,        2. a | w and b | w  ⇒  v | w    v divides each common multiple.",
                "The product a·b is a common multiple of a and b, but not always the smallest one.\n\nTheorem:   LCM(a, b) =    for a, b ≠ 0      Proof    Examples\nGCD(a, b)\nLCM(a, 0) = 0,  since the only multiple of 0 is 0 itself.",
                "Definition:  One denotes the set of all positive multiples of a ∈ ℤ by V\u{E002}a\u{E003} .\nThus is V\u{E002}0\u{E003} = ∅.",
                "For a, b ≠ 0 holds:    LCM(a, b) is the smallest number ∈ V\u{E002}a\u{E003} ∩ V\u{E002}b\u{E003} , and\n    V\u{E002}a\u{E003} ∩ V\u{E002}b\u{E003} = V\u{E002}LCM(a, b)\u{E003} .",
                "Hereby can be shown:\nTheorem:     LCM(  a, LCM(b, c)  )  =  LCM(  LCM(a, b), c  )    Proof",
            ]),
            ZTPage(id: "1.4 - kgV von mehr als 2 Zahlen", title: "LCM of more than 2 numbers", tool: .lcm, blocks: [
                "One also can define the LCM of more than 2 numbers:\n\nDefinition:    For k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k\u{E003} ∈ ℤ and k > 2 is\nthe smallest number ∈ V\u{E002}1\u{E003} ∩ V\u{E002}2\u{E003} ∩ ... ∩ V\u{E002}k \u{E003},  if all a ≠ 0,\n0,  if at least one a = 0.\nLCM( a\u{E002}1\u{E003}, a\u{E002}2\u{E003}, ..., a\u{E002}k\u{E003} )",
                "Theorem:    For k, a\u{E002}1 \u{E003}, a\u{E002}2 \u{E003}, ..., a\u{E002}k \u{E003}, a\u{E002}k+1\u{E003} ∈ ℤ and k > 2 holds:\n\n    1.  Va\u{E002}1\u{E003} ∩ ... ∩ Va\u{E002}k\u{E003}  =  VLCM( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} )    Proof\n         The common multiples are the multiples of the LCM.\n         The proof also shows:\n         LCM( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} )  =  LCM(  LCM( a\u{E002}1\u{E003}, ..., a\u{E002}k–1\u{E003} ), a\u{E002}k\u{E003}  )\n         Thus the LCM of more than 2 numbers can be calculated recursively.\n\n    2.  a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} pairwise coprime  ⇒  LCM( a\u{E002}1\u{E003}, ..., a\u{E002}k\u{E003} ) = |a\u{E002}1\u{E003}·...· a\u{E002}k \u{E003}|    Proof",
                "end of this lesson",
            ]),
        ]))
        return ZTLesson(number: 1, title: "Integers", chapters: chapters)
    }
    static func lesson2() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "2.1", title: "Congruences", pages: [
            ZTPage(id: "2.1 - 01", title: "Algebraic terms", tool: nil, blocks: [
                "distributive\nAlgebraic Structure\n\n\nSemigroup\nMonoid    Neutral Element\nGroup     Inverse Element\n\nRing    Zero-Element    One-Element\n    Zero Divisor    Unit\nField\nIn this lesson some concepts from algebra are required,\nwhich can be studied later when coming across or now collectively:\nIsomorphism\ninjective      surjective      bijective",
            ]),
            ZTPage(id: "2.1 - Division mit Rest", title: "Division with remainder", tool: .divRest, blocks: [
                "Dividing an integer by another integer not always yields an integer,\nfor instance:     ∉ ℤ.\nFor obtaining integer results one applies division with remainder:",
                "Definition: Let a, b ∈ ℤ, b > 0.\n    Division of a by b with remainder is called the following representation:\n    a = q·b + r    with q, r ∈ ℤ   and   0 ≤ r < b.\n    Here  q  is called the integer quotient and  r  the remainder of the division.",
                "no constraint, since",
                "Theorem:  Integer quotient and remainder are unique:  q = ⌊   ⌋  and  r = a – q·b.\nProof        Annotation",
            ]),
            ZTPage(id: "2.1 - Kongruenz", title: "Congruence", tool: .congruence, blocks: [
                "Definition: Let m ∈ ℕ.\n    Two integers a and b are called congruent modulo m, if m divides the difference a – b.\n    One writes a ≡ b mod m. The number m is called the modulus.\n\nThe concept and notation of congruence were introduced by Gauss.\n\nExamples:\n    · clock times:  13 ≡ 1 mod 12,  24 ≡ 0 mod 12\n    · odd numbers:  –25 ≡ 3 mod 2",
                "Theorem:   a ≡ b mod m  ⇔  a and b give the same remainder after division by m.\nProof",
                "    Congruence modulo m is an equivalence relation in ℤ, it holds:\n    1. Reflexivity:     a ≡ a mod m  for all a ∈ ℤ\n    2. Symmetry:     a ≡ b mod m  ⇒  b ≡ a mod m\n    3. Transitivity:     a ≡ b mod m  ∧  b ≡ c mod m  ⇒  a ≡ c mod m",
            ]),
            ZTPage(id: "2.1 - Restklassen", title: "Residue classes", tool: .residueClass, blocks: [
                "Congruence modulo m divides ℤ into equivalence classes, called residue classes.\nDefinition:\n    The set [a]\u{E002}m\u{E003} = { x ∈ ℤ | x ≡ a mod m } is called Residue Class a modulo m, shortly: a mod m.\n    The number a is called a Representative of the residue class.",
                "All elements of [a]\u{E002}m\u{E003} give the same remainder as the representative a after division by m.\nSince they differ from a and from each other by integer multiples of the modulus m, there is the alternative denotation a+mℤ =    [a]\u{E002}m\u{E003} = { x ∈ ℤ | x = a + z·m, z ∈ ℤ }.\nExamples:\n    ·  [1]\u{E002}10\u{E003} = {1, 1±10, 1±2·10, 1±3·10, ...} = {1, –9, 11, –19, 21, –29, 31, ...}\n    ·  [1]\u{E002}2\u{E003} is the set of all odd numbers.\n    ·  [0]\u{E002}2\u{E003} is the set of all even numbers.",
                "Each number can represent its residue class:  a ≡ b mod m  ⇔  [a]\u{E002}m\u{E003} = [b]\u{E002}m\u{E003}\nExamples:  ·  [1]\u{E002}10\u{E003} = [11]\u{E002}10\u{E003}                ·  [1]\u{E002}2\u{E003} = [–1]\u{E002}2\u{E003}                ·  [0]\u{E002}12\u{E003} = [24]\u{E002}12\u{E003}",
            ]),
            ZTPage(id: "2.1 - Standardvertreter", title: "Standard representative", tool: .residueClass, blocks: [
                "least non-negative,    least positive,    greatest negative,    absolute least representatives\n    [0]\u{E002}4\u{E003}     =     [4]\u{E002}4\u{E003}     =     [–4]\u{E002}4\u{E003}     =     [0]\u{E002}4\u{E003}\n    [1]\u{E002}4\u{E003}     =     [1]\u{E002}4\u{E003}     =     [–3]\u{E002}4\u{E003}     =     [1]\u{E002}4\u{E003}\n    [2]\u{E002}4\u{E003}     =     [2]\u{E002}4\u{E003}     =     [–2]\u{E002}4\u{E003}     =     [2]\u{E002}4\u{E003}\n    [3]\u{E002}4\u{E003}     =     [3]\u{E002}4\u{E003}     =     [–1]\u{E002}4\u{E003}     =     [–1]\u{E002}4\u{E003}\nThere are some special representatives, for example with the residue classes modulo 4:",
                "The least non-negative representatives are called standard representatives.\nThey are the possible remainders after division by the modulus.\nIf x is the standard representative of [a]\u{E002}m\u{E003} one writes  x = a (mod m).\nReplacing an integer a with a (mod m) is called reduction mod m.",
                "It holds:       x = a (mod m)   ⇒   x ≡ a mod m\nThe converse is wrong, for instance:      3 ≡ 5 mod 2,  but  3 ≠ 5 (mod 2) = 1",
                "In many programming languages the function mod(a, b) computes a representative of a mod b,\nusually the standard-, in some languages the greatest negative representative in case a < 0.",
            ]),
            ZTPage(id: "2.1 - Summe, Produkt", title: "Sum and product", tool: .modTables, blocks: [
                "Definition:     The set of all residue classes mod m is denoted by ℤ\u{E002}m\u{E003} or ℤ/m.\nℤ\u{E002}m\u{E003} has m elements, since the possible remainders after division by m are 0, 1, 2, ..., m – 1.\nExample:    ℤ\u{E002}3\u{E003} = { [0], [1], [2] }\nIf the modulus is known from the context, one can omit the indices of the residue classes.\nIf it's clear that residue classes are meant, one can omit the brackets too.",
                "  1. The sum of two residue classes is [a] + [b] = [a+b].\n  2. The product of two residue classes is [a] · [b] = [a·b].\nIn the finite set ℤ\u{E002}m\u{E003} an addition + and a multiplication · can be defined,\nsuch that (ℤ\u{E002}m\u{E003}, +, ·) is an algebraic structure.",
                "Theorem: These connections are well-defined, this means:\n        They give the same results no matter which representatives a and b are chosen.\n        From  [a] = [a']  and  [b] = [b']  follows  [a+b] = [a'+b']  and  [a·b] = [a'·b'].\nProof\nA counter-example shows that well-definedness cannot be taken for granted.",
            ]),
            ZTPage(id: "2.1 - Restklassenring", title: "The residue class ring", tool: .modTables, blocks: [
                "Theorem:    Associativity, commutativity, existence of a neutral element, invertibility and     distributivity are transported from (ℤ, +, ·) to (ℤ\u{E002}m \u{E003}, +, ·).\nProof",
                "Consequence:\n    (ℤ\u{E002}m \u{E003}, +) is a commutative group. Neutral element is [0], inverse to [a] is [m–a].\n    (ℤ\u{E002}m \u{E003}, ·) is a commutative semigroup. Neutral element is [1].",
                "Corollary and Definition:    (ℤ\u{E002}m \u{E003}, +, ·) is a commutative ring with one-element: the residue class ring modulo m.",
            ]),
            ZTPage(id: "2.1 - Wozu mod", title: "Why calculate modulo?", tool: .checkNine, blocks: [
                "prominent Example\nCalculating in the residue class ring corresponds to calculating with congruences.\nSince only classes matter, one can always choose the \"handiest\" representatives.\n\nExample:  Which remainder gives 13·14 after division by 16?\n    In the residue class ring mod 16 holds [13·14] = [13]·[14] = [–3]·[–2] = [(–3)·(–2)] = [6].\n    This correspond to the congruences                    13·14  ≡  (–3)·(–2) ≡ 6 mod 16.\n    Instead of 13·14 one divides (–3)·(–2) by 16 and obtains the remainder 6 at once.\n    Test it yourself.",
                "This is utilized in calcution checks with final digits. One calculates modulo 10.\nExample:      5461958 · 987459187 ≠ 434756195619242, since [8]·[7] = [6].\nThe result can be wrong, even if the final digits accord. \nThen the difference from the correct result is a multiple of 10.\nThis calcution check also works with different moduli. If the residue classes accord,\nthe difference from the correct result is a multiple of the modulus.",
            ]),
            ZTPage(id: "2.1 - Quersummen", title: "Transversal sums", tool: .crossSums, blocks: [
                "For all exponents z holds 10\u{E000}z\u{E001}  ≡  1 mod 3.\n10 ≡ 1 mod 3",
                "From right to left one merges packs of k digits into new numbers.\nThe leftmost pack can have less than k digits.",
                "The packs get alternating signs,\nstarting from the right end with a + .",
                "with x = 5214\nAny other x would do as well.",
                "For even exponents z holds 10\u{E000}z\u{E001}  ≡  1 mod 11,\nfor odd z holds 10\u{E000}z\u{E001}  ≡  –1 mod 11.\n10 ≡ –1 mod 11",
                "For all exponents z holds (10\u{E000}2\u{E001})\u{E000}z\u{E001}  ≡  1 mod 11.\n10\u{E000}2\u{E001} ≡ 1 mod 11",
                "Perhaps you know the rule:    3 | x    ⇔     3 | Q(x) = transversal sum of x\nExample:      3 | 5214, since    3 | 5+2+1+4 = 12",
                "Base-10 system:    5214  =    5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}.\n10 ≡ 1 mod 3    ⇒    5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}  ≡  5+2+1+4 mod 3\n        After division by 3, x gives the same remainder as Q(x).",
                "Consider k-stage transversal sums Q\u{E002}k\u{E003} and alternating transversal sums Q'\u{E002}k\u{E003}:",
                "For divisibility by 11 holds:    11 | x      ⇔      11 | Q'\u{E002}1\u{E003}(x)    and    11 | x      ⇔      11 | Q\u{E002}2\u{E003}(x),    since\n10 ≡ –1 mod 11    ⇒     5·10\u{E000}3\u{E001} + 2·10\u{E000}2\u{E001} + 1·10\u{E000}1\u{E001} + 4·10\u{E000}0\u{E001}  ≡  –5+2–1+4 mod 11\n10\u{E000}2\u{E001} ≡ 1 mod 11    ⇒     52·10\u{E000}2\u{E001} + 14·10\u{E000}0\u{E001}  ≡  52+14 mod 11\n        After division by 11, x gives the same remainder as Q'\u{E002}1\u{E003}(x) and Q\u{E002}2\u{E003}(x).\nmore Examples      Generalization",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.2", title: "Prime Residue Classes", pages: [
            ZTPage(id: "2.2 - 01", title: "Units and zero divisors", tool: .modTables, blocks: [
                "Consider the equation      3 + x = 5.\nIt can be solved by subtracting 3, thus by adding the inverse of 3.\n    3 + x = 5   |  + (– 3)\n          x = 2",
                "with respect to · here",
                "Consider now the equation    3 · x = 5.\nIt can be solved by dividing by 3, thus by multiplying by the inverse of 3.\n    3 · x = 5   |  ·\n         \u{E002}x = \u{E003}",
                "Here one calculates in the ring (ℚ, +, ·), since    ∉ ℤ.\nIn the ring of integers (ℤ, +, ·) 3 is not multiplicatively invertible.",
                "With respect to addition each element of a ring is invertible,\nwith respect to multiplication only some are invertible, they are called units.\nIf 0 is a unit, the ring has only one element. Proof",
                "Some rings contain elements a, b ≠ 0, but a·b = 0. Such elements are called zero divisors, they are never units.",
            ]),
            ZTPage(id: "2.2 - Zm*", title: "Prime residue classes ℤm*", tool: .units, blocks: [
                "that are not invertible:\n(standard representatives)\nThe elements of a ring that are invertible with respect to multiplication are called units.",
                "Observation: Exactly the representatives of the units are coprime to the modulus.\nDefinition:    The units in the residue class ring are called prime residue classes.\n    They form the group of prime residue classes modulo m, shortly ℤ\u{E002}m\u{E003}* or (ℤ/m)*.",
                "Observation: The other residue classes except [0] are zero divisors.",
                "The units have a 1\nin row and column.",
                "≠ 0, have more than a 0 in row and column",
            ]),
            ZTPage(id: "2.2 - prim zum Modul", title: "Coprime to the modulus", tool: .units, blocks: [
                "Theorem:    [a]\u{E002}m\u{E003} is a prime residue class  ⇔  GCD(a, m) = 1.\nProof\n\"⇒\"    [a]\u{E002}m\u{E003}·[b]\u{E002}m\u{E003} = [1]\u{E002}m\u{E003}   ⇒   a·b ≡ 1 mod m  ⇒  m | a·b – 1\n    ⇒     GCD(a, m) | a·b – 1\n    Moreover:    GCD(a, m) | a\n ⇒  GCD(a, m) | 1  ⇒  GCD(a, m) = 1",
                "invertible with respect to multiplication",
                "\"⇐\"    Let GCD(a, m) = 1.    ⇒    There are coefficients x, y ∈ ℤ with a·x + m·y = 1.\n    ⇒  a·x – 1 = –m·y    ⇒    m | a·x – 1\n    ⇒  a·x ≡ 1 mod m    ⇒    [a]\u{E002}m\u{E003}·[x]\u{E002}m\u{E003} = [1]\u{E002}m\u{E003}\nThe coefficients x and y – and thus [x]\u{E002}m\u{E003} – can be found by the Euclidian algorithm.\nThe proof of the converse is based on linear combinations:",
                "The second observation can be proved too:\nTheorem:     [a]\u{E002}m\u{E003} is a zero divisor   ⇔   1 < GCD(a, m) < m.      Proof",
                "In case the modulus m is a prime, all residue classes except [0] are prime residue classes.\nThus the residue class ring modulo a prime is a field.",
            ]),
            ZTPage(id: "2.2 - invertieren mit Euklid", title: "Inverting with Euclid", tool: .inverse, blocks: [
                "The multiplicative inverse [x]\u{E002}m\u{E003} to a residue class [a]\u{E002}m\u{E003}\ncan be found by trial and error ...",
                "... or by the Euclidian algorithm,\nwhich can represent GCD(a, m) as a linear combination:",
                "a·x ≡ 1 mod m  ⇔  a·x + m·y = 1",
            ]),
            ZTPage(id: "2.2 - Kongruenzen lösen", title: "Solving congruences", tool: .linearCongruence, blocks: [
                "Definition:     If a·x ≡ b mod m for an x\u{E002}0\u{E003} ∈ ℤ, one says: x\u{E002}0\u{E003} satisfies the congruence,\n    and the residue class [x\u{E002}0\u{E003}]\u{E002}m\u{E003} is called then a solution of the congruence.\nIf [a]\u{E002}m\u{E003} is prime residue class with [a']\u{E002}m\u{E003}·[a]\u{E002}m\u{E003} = [1]\u{E002}m \u{E003}, then [a']\u{E002}m\u{E003}·[b]\u{E002}m\u{E003} is the unique solution.\nAlso otherwise there can be solutions:",
                "Theorem:      1. The congruence  a·x ≡ b mod m  is solvable  ⇔  GCD(a, m) | b.\n    2. If there are solutions of  a·x ≡ b mod m, their number is GCD(a, m).\nProof",
                "Example:    4·x ≡ 6 mod 10  is solvable, since GCD(4, 10) = 2 | 6.\n    There are 2 solutions. Thus one cancels by 2 and solves the new congruence\n    2·x ≡ 3 mod 5.\n    Its solution is [4]\u{E002}5\u{E003} = {4 + 5·z | z ∈ ℤ} = {..., –6, –1, 4, 9, 14, 19, ...}.\n    Modulo 10 this class falls into the two classes\n        [4]\u{E002}10\u{E003} = {4 + 10·z | z ∈ ℤ} = {..., –6, 4, 14, ...}  and\n        [9]\u{E002}10\u{E003} = {9 + 10·z | z ∈ ℤ} = {..., –1, 9, 19, ...}.\n    They are the two solutions of the original congruence 4·x ≡ 6 mod 10.",
            ]),
            ZTPage(id: "2.2 - Euler-Funktion", title: "The Euler function", tool: .phiTable, blocks: [
                "the greek letter Phi",
                "The number of prime residue classes modulo n is denoted by φ(n).\nDefinition: Euler function φ\n    Let n ∈ ℕ. Then φ(n) counts the natural numbers ≤ n that are coprime to n.",
                "some values of the Euler function:\n  n    1    2    3    4    5    6    7    8    9    10    11    12    13    14    15    16    17    18    19    20    ...    n\n φ(n)    1    1    2    2    4    2    6    4    6     4    10     4    12     6     8     8    16     6    18     8    ...    ?",
                "Theorem:  For all n ∈ ℕ is n = Σ φ(d).",
                "d =     t    A\u{E002}t\u{E003}     x ∈ {1, .., n} with GCD(x, n) = t            ∈ {1, ..,   } with GCD(  ,   ) = 1    φ(d)",
                "For each x there is a set A\u{E002}t\u{E003}.\nNo x is in more than one set A\u{E002}t\u{E003}.\nThere are n different x.",
                "A\u{E002}t\u{E003} contains all x ∈ {1, 2, ..., n} with GCD(x, n) = t.\nThese are exactly the x ∈ {1, 2, ..., n}, for which     is coprime to    ,\nand it holds        ∈ {1, 2, ...,   }.\nExactly φ(   ) numbers    ∈ {1, 2, ...,   } are coprime to    .",
                "Proof:  Σ φ(d) = n       where φ(n) counts the natural numbers ≤ n that are coprime to n.\nFor each divisor t of n let A\u{E002}t\u{E003} be the set of all x ∈ {1, 2, ..., n} with GCD(x, n) = t.\n⇒    Σ |A\u{E002}t\u{E003}|  =  n.     Because for each x there is exactly one t = GCD(x, n).",
                "Moreover:     GCD(x, n) = t  ⇔  GCD(   ,   ) = 1",
                "⇒      |A\u{E002}t\u{E003}|  =  φ(   )\n⇒      n = Σ    |A\u{E002}t\u{E003}|  =  Σ φ(   )",
                "Set d =    = complementary divisor of t, then the proposition follows.",
            ]),
            ZTPage(id: "2.2 - Berechnung Euler 1", title: "Computing the Euler function (1)", tool: .phi, blocks: [
                "Some values of the Euler function can be given at once:\n\nTheorem:      For each prime p is  φ(p) = p – 1.\nProof:     All natural numbers < p are coprime to p.\nExamples:      φ(2) = 1,    φ(5) = 4,    φ(11) = 10,    φ(97) = 96",
                "Examples:      φ(8) = φ(2\u{E000}3\u{E001}) = 1·2\u{E000}2\u{E001} = 4\n    φ(81) = φ(3\u{E000}4\u{E001}) = 2·3\u{E000}3\u{E001} = 54\n    φ(121) = φ(11\u{E000}2\u{E001}) = 10·11\u{E000}1\u{E001} = 110\nTheorem:    For prime powers p\u{E000}a\u{E001} is  φ(p\u{E000}a\u{E001}) = p\u{E000}a\u{E001} – p\u{E000}a–1\u{E001} = (p – 1)·p\u{E000}a–1\u{E001}.\nProof:    Each p-th number ∈ {1, 2, ..., p\u{E000}a\u{E001}} is divisible by p, that are       = p\u{E000}a–1\u{E001}  numbers.\nalternative Proof\n    Thus there are p\u{E000}a\u{E001} – p\u{E000}a–1\u{E001} numbers coprime to p\u{E000}a\u{E001}.",
                "And if a number is no prime power?\nThis case needs some deeper examination ...",
            ]),
            ZTPage(id: "2.2 - Uhren verstellen", title: "Clock setting", tool: .crt, blocks: [
                "Below each clock is a quotient:\nThe enumerator tells the hour,\nthe denominator tells the size of the clock face.\n\nThe clocks can only be adjusted simultaneously,\neach by the same number of hours.",
                "Set these clocks:",
                "adjusting the clocks stepwise:",
            ]),
            ZTPage(id: "2.2 - Chinesischer Restsatz", title: "The Chinese remainder theorem", tool: .crt, blocks: [
                "congruences for which\na common solution is wanted",
                "The simultaneous clock adjustment demonstrates the Chinese Remainder Theorem:\n\nTheorem:    Let     m\u{E002}1\u{E003} , m\u{E002}2\u{E003} , ... , m\u{E002}k\u{E003} ∈ ℕ  be pairwise coprime,\n         a\u{E002}1\u{E003} ,  a\u{E002}2\u{E003} , ... ,  a\u{E002}k\u{E003} ∈ ℤ,     n = m\u{E002}1\u{E003} · m\u{E002}2\u{E003} · ... · m\u{E002}k\u{E003} ,\n    then exactly one residue class x\u{E002}0\u{E003} mod n solves the simultaneous congruence\n        x ≡ a\u{E002}1\u{E003} mod m\u{E002}1\u{E003} ,   x ≡ a\u{E002}2\u{E003} mod m\u{E002}2\u{E003} ,  ... ,   x ≡ a\u{E002}k\u{E003} mod m\u{E002}k\u{E003} .\nProof",
                "The numbers  m\u{E002}1\u{E003}, ..., m\u{E002}k\u{E003}  correspond the clocks.\nThe residue classes  a\u{E002}1\u{E003} mod m\u{E002}1\u{E003}, ...,  a\u{E002}k\u{E003} mod m\u{E002}k\u{E003}  correspond the target times.\nFor each x mod n there is a combination ( x mod m\u{E002}1 \u{E003}, ... ,  x mod m\u{E002}k\u{E003} ) of clock times.",
                "Each of these combinations is an element of    ℤm\u{E002}1\u{E003} ×   ...   ×  ℤm\u{E002}k\u{E003} .\nNow the Chinese Remainder Theorem says that also vice versa\nfor each such combination there is exactly one residue class x mod n.\nThus there is a bijective mapping f from ℤn  \u{E000}to\u{E001}  ℤm\u{E002}1\u{E003}× ... ×  ℤm\u{E002}k\u{E003} .\nExample",
                "the set of all residue classes mod n",
            ]),
            ZTPage(id: "2.2 - Zerlegung Ring", title: "Decomposition of the residue class ring", tool: .crtMap, blocks: [
                "Let R\u{E002}1\u{E003}, R\u{E002}2\u{E003}, ... , R\u{E002}k\u{E003} be rings, then one denotes as their direct product the set of all tuples\n(r\u{E002}1\u{E003}, r\u{E002}2\u{E003}, ... , r\u{E002}k\u{E003}) ∈ R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} with componentwise addition and multiplication.\nExample",
                "The direct product is a ring too. If the R\u{E002}i\u{E003} are commutative rings with one-elements e\u{E002}i\u{E003} , 1≤ i ≤ k, then the direct product is a commutative ring with one-element (e\u{E002}1\u{E003}, ... , e\u{E002}k\u{E003}).",
                "Theorem:    Let  m\u{E002}1 \u{E003}, m\u{E002}2 \u{E003}, ... , m\u{E002}k\u{E003} ∈ ℕ be pairwise coprime,  n = m\u{E002}1 \u{E003}· m\u{E002}2 \u{E003}· ... · m\u{E002}k \u{E003}.  Then\n    the mapping        f:  ℤn   →   ℤm\u{E002}1\u{E003}\u{E000}×\u{E001}  ℤm\u{E002}2\u{E003}× ... ×  ℤm\u{E002}k\u{E003}     with\n\n    is an isomorphism of rings.\nProof        Example\n\u{E000}f( [x]\u{E001}n \u{E000}) = ( [x]\u{E001}m\u{E002}1 \u{E003},  \u{E000}[x]\u{E001}m\u{E002}2 \u{E003}, ... ,  \u{E000}[x]\u{E001}m\u{E002}k\u{E003} \u{E000})\u{E001}",
                "If R ≅ R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} , then R\u{E002}1\u{E003}× R\u{E002}2\u{E003}× ... × R\u{E002}k\u{E003} is called a decomposition of R.\nSo one can decompose ℤ\u{E002}n\u{E003} and calculate in many little rings instead in a big one;\nthe resulting tuple can be transformed back to ℤ\u{E002}n\u{E003} with the Chinese Remainder Theorem.",
            ]),
            ZTPage(id: "2.2 - Berechnung Euler 2", title: "Computing the Euler function (2)", tool: .phi, blocks: [
                "Due to the decomposition of residue class rings the Euler function can be calculated\nfor any product of coprime numbers too – provided that its prime factors are known:\nRecollection:  For prime powers  p\u{E000}a\u{E001}  is  φ(p\u{E000}a\u{E001}) = (p – 1)·p\u{E000}a–1\u{E001}.",
                "Theorem:     Let  n = m\u{E002}1 \u{E003}· m\u{E002}2 \u{E003}· ... · m\u{E002}k \u{E003} with pairwise coprime numbers  m\u{E002}1 \u{E003}, m\u{E002}2 \u{E003}, ... , m\u{E002}k\u{E003} ∈ ℕ.\n    Then is      φ(n) = φ(m\u{E002}1\u{E003}) · φ(m\u{E002}2\u{E003}) · ... · φ(m\u{E002}k\u{E003}).\nProof",
                "If  n = ∏ p\u{E000}e(p)\u{E001}   is the prime decomposition of n, where p occurs e(p) times, then is\n\nφ(n) = ∏ φ(p\u{E000}e(p)\u{E001} ).   After replacing p\u{E000}e(p)\u{E001} with the formula for prime powers one obtains the\nFormula for the Euler function:\nφ(n) = ∏ (p – 1)·p\u{E000}e(p)–1\u{E001}\nother Representations",
            ]),
            ZTPage(id: "2.2 - Fermat, Euler", title: "The theorems of Fermat and Euler", tool: .eulerFermat, blocks: [
                "Euler, by generalizing a theorem of Fermat, got a most important theorem in number theory:\n\nTheorem:    \"Euler-Fermat\"\n    Let n ∈ ℕ, a be coprime to n. Then is  a\u{E000}φ(n)\u{E001} ≡ 1 mod n.\nIllustration        Proof",
                "The special case φ(p) = p – 1 for primes p was known to Fermat:\nTheorem:    \"Little Fermat\"\n    Let p be prime, a be coprime to p. Then is  a\u{E000}p–1\u{E001} ≡ 1 mod p.",
                "but 2 ≡ 4 mod 4.\nCorollary:  Let n ∈ ℕ, a be coprime to n. Then holds:\n    b ≡ c mod φ(n)  ⇒  a\u{E000}b\u{E001} ≡ a\u{E000}c\u{E001} mod n    Proof\nThe converse is wrong,  e.g.  3\u{E000}2\u{E001} ≡ 3\u{E000}4\u{E001} mod 8,",
                "Thus in calcutions with prime residue classes modulo n\none can replace their     ·  representatives     modulo n,\n    ·  exponents     modulo φ(n).     Example 1\n            Example 2",
            ]),
            ZTPage(id: "2.2 - schnelle Potenz", title: "Fast exponentiation", tool: .squareMultiply, blocks: [
                "    ⌊half⌋     (97)    48    24    12    6     3     1    0 \n    remainder      1    0    0    0     0     1    1",
                "Compare the number of multiplications\n(including squaring) with the exponent.",
                "Sometimes there are no tricks, one must compute a power. But cleverly.\n    Quadrify the base \"several times\", this yields \"building material\". \n    Choose the proper building material and compose the power of it.\nThis is being explained in the case of  3\u{E000}97\u{E001}:",
                "Quadrify 3 several times:    3,    9,    81,    81\u{E000}2\u{E001},    (81\u{E000}2\u{E001})\u{E000}2\u{E001},    ((81\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001},    (((81\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001} ...\nNow holds:  (a\u{E000}k\u{E001})\u{E000}2\u{E001} = a\u{E000}2·k\u{E001}\nThus the material is:    3\u{E000}1\u{E001},    3\u{E000}2\u{E001},    3\u{E000}4\u{E001},    3\u{E000}8\u{E001},    3\u{E000}16\u{E001},    3\u{E000}32\u{E001},    3\u{E000}64\u{E001} ...",
                "The proper material is shown by the decomposition of the exponent in different powers of 2: \n    97  =      1 +    0 +    0  +    0   +     0    +     32     +    64\nThus is      3\u{E000}97\u{E001} =     3\u{E000}1\u{E001} ·    1  ·    1   ·    1   ·    1     ·    3\u{E000}32\u{E001}    ·     3\u{E000}64\u{E001}.\ncleverly",
                "The decomposition of the exponent corresponds its binary representation 1100001 backwards,\nit can be found by repeatedly halving with remainder. This yields the following\nAlgorithm:      power := 1\n    While exponent > 0:    exponent := ⌊exponent / 2⌋\n                    If remainder = 1, then  power := power · base\n                     base := base\u{E000}2\u{E001}",
            ]),
            ZTPage(id: "2.2 - modulare Potenz", title: "Modular exponentiation", tool: .squareMultiply, blocks: [
                "durch the Standardvertreter ersetzt",
                "base, squares and (in brackets) intermediate results are being reduced at once.",
                "The base is not invertible.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.3", title: "Subgroups", pages: [
            ZTPage(id: "2.3 - 01", title: "Groups", tool: nil, blocks: [
                "In order to make it short from now on\n\n·  well-known groups are given without connection,\n    for example  ℤ instead (ℤ, +),\n\n·  residue classes with known modulus are given by representatives,\n    for example  ℤ\u{E002}10\u{E003}* = {1, 3, 7, 9},\n\nif the meaning is clear from the context.\nThe circumstantial notation can be used for clarification here and there.",
            ]),
            ZTPage(id: "2.3 - |G|", title: "Order of a group, subgroups", tool: .order, blocks: [
                "Definition:  The number of elements of a group G is called order of the group, shortly |G|.\nExamples:    ·  ℤ    has infinite order.\n    ·  ℤ\u{E002}10\u{E003}    has the order 10.    ·  ℤ\u{E002}10\u{E003}*   has the order φ(10) = 4.",
                "Definition:    Let (G, *) be a group, U ⊆ G.\n    If (U, *) is a group, then it is called a subgroup of (G, *).\n\nExamples:    ·  In ℤ the even numbers form a subgroup.\n    ·  The neutral element and G itself are the so called trivial subgroups.\n    ·  The subgroups in ℤ\u{E002}8\u{E003}* are: {1}, {1, 3}, {1, 5}, {1, 7}, ℤ\u{E002}8\u{E003}* itself.",
                "Theorem:    Let (G, *) be a group, U ⊆ G, U ≠ ∅.\n    If U is finite and closed with respect to *,\n    then (U, *) is a subgroup of (G, *).    Proof\n\nNotice:    Closedness alone is not enough, for instance (ℕ\u{E002}0\u{E003}, +) is no subgroup of (ℤ, +).",
            ]),
            ZTPage(id: "2.3 - ord(a)", title: "Order of an element", tool: .order, blocks: [
                "After the theorem of Euler-Fermat holds for all a ∈ ℤ\u{E002}m\u{E003}*:  a\u{E000}φ(m)\u{E001} = 1.\nThis can be extended:",
                "Theorem:      Let G be a finite group with neutral element e.\n        Then holds for all a ∈ G:      a\u{E000}|G|\u{E001} = e.\nExample:    In ℤ\u{E002}10\u{E003} holds:  [2]\u{E000}10\u{E001} = [2]+[2]+[2]+[2]+[2]+[2]+[2]+[2]+[2]+[2] = [20] = [0] = e.\nProof:      In the proof of Euler-Fermat replace ℤ\u{E002}m\u{E003}* with G,  φ(m) with |G| etc.",
                "Here this works also with a smaller exponent:\n[2]\u{E000}5\u{E001} = [2]+[2]+[2]+[2]+[2] = [10] = [0] = e.",
                "Definition:    Let G be a group with neutral element e, a ∈ G.\n    The smallest number n ∈ ℕ with a\u{E000}n\u{E001} = e is called the order of a in G, shortly ord(a).\n    If no such number exists, the order of a in G is called infinite.\nExamples:    ·  In ℤ is ord(2) = ∞.\n    ·  In ℤ\u{E002}10\u{E003} is ord(2) = 5.    ·  In ℤ\u{E002}10\u{E003}* is ord(9) = 2.",
                "if G is well-known",
            ]),
            ZTPage(id: "2.3 - ord( Potenz )", title: "Order of a power", tool: .order, blocks: [
                "Let G be a group with neutral element e, a ∈ \u{E000}G, z\u{E001} ∈ ℤ and ord(a) ∈ ℕ. Then holds:\nTheorem:    a\u{E000}z\u{E001} = e  ⇔  ord(a) | z\n    \"power neutral  ⇔  order of the base divides exponent\"    Proof\nExample",
                "Consequences:\n    1. Due to    a\u{E000}|G|\u{E001} = e   holds:   ord(a) divides |G|.\n\"element-order divides group-order.\"\n\n    2. Due to    a\u{E000}x–y\u{E001} = e  ⇔  ord(a) | (x–y)     holds:\n        a\u{E000}x\u{E001} = a\u{E000}y\u{E001}  ⇔  x ≡ y mod ord(a)    Example\nin finite groups",
                "GCD(α, z)\nord(a\u{E000}z\u{E001})\nTheorem:\nExample\nIf the order of a is known, one easily gets the order of each power of a:\nwith α = ord(a)",
            ]),
            ZTPage(id: "2.3 - Erzeugnis", title: "Generation, cyclic groups", tool: .order, blocks: [
                "Definition:    Let G be a group.\n    ·  For each a ∈ G the set <a> = {a\u{E000}z\u{E001} | z ∈ ℤ} is called the generation of a.\n        One says: a generates <a>, a is called generator or generator element of <a>.\n    ·  If there is an a ∈ G with <a> = G, then G is called cyclic.\nSome groups can be generated from one of their elements by exponentiation:",
                "Examples:    ·  ℤ is cyclic with the generators 1 and –1. \n        The even numbers are <2> = <–2> = {2·z | z ∈ ℤ}.\n    ·  The generations in ℤ\u{E002}8\u{E003}* are:     <1> = {1},",
                "Theorem:    Each generation is a subgroup.     Proof\n\nThe converse of the theorem is wrong, since for example\n    ℤ\u{E002}8\u{E003}* is not cyclic, but is a subgroup of itself,\n    ℤ\u{E002}20\u{E003}* has the non-cyclic subgroup {1, 9, 11, 19}.",
            ]),
            ZTPage(id: "2.3 - Lagrange", title: "Lagrange's theorem", tool: .order, blocks: [
                "Theorem:     Let G be a group, a ∈ G, then holds:\n        |<a>| = ord(a)    Proof\nEach element of a group generates a subgroup.\nThe order of this subgroup is exactly the order of the generating element.",
                "In finite groups holds:    ord(a)  divides  |G|.\nConsequence for finite groups:     |<a>|  divides  |G|. \n\"generation-order divides group-order.\"",
                "Lagrange found the following generalization:\nLagrange's Theorem:      If U is a subgroup of a finite group G, then holds:                  |U| divides |G|.    Proof\n\"subgroup-order divides group-order.\"\nNotice:     Lagrange does not say, there were a subgroup for each divisor of |G|.",
            ]),
            ZTPage(id: "2.3 - ord(a) berechnen", title: "Computing ord(a)", tool: .order, blocks: [
                "Let G be a finite group with neutral element e, a ∈ G.\nWhen computing ord(a), one only has to take the divisors of |G| into account.\nOne looks for the smallest divisor d of |G| for that a\u{E000}d\u{E001} = e.",
                "Since the divisors consist of the prime divisors of |G|,\nknowing the prime decomposition of |G| is helpful.\nStart with d = |G| and decrease d as long as possible:",
                "Algorithm:     1. d := |G|\n    2. Take a prime divisor p of |G| that has not yet been handled.    3. If a\u{E000}d/p\u{E001} = e, then        d := d / p         If p occurs more often in |G| than it has been handled, then go to 3.    4. If not yet all prime divisors have been handled, then go to 2.    5. Output: ord(a) = d.",
                "The question whether a is a generator can be decided faster by the algorithm, since\na generates the group  ⇔  ord(a) = |G|.\nAs soon as the algorithm can decrease d, a cannot be a generator any more.\n a is no generator of G.",
            ]),
            ZTPage(id: "2.3 - zyklisch iso", title: "Cyclic groups are isomorphic", tool: .order, blocks: [
                "Examples:    ·  (ℤ, +) ≅ (<2>, +)      with f(x) = 2·x\n    ·  (ℤ\u{E002}4 \u{E003}, +) ≅ (ℤ\u{E002}5\u{E003}*, ·)    with f( [x] ) = [2]\u{E000}x\u{E001} , as ℤ\u{E002}5\u{E003}* = <[2]> = {[2], [4], [3], [1]}\nEach generation is a cyclic group and vice versa, and it holds:\nTheorem:    Each cyclic group is isomorphic to a residue class group ℤ\u{E002}n\u{E003} or to ℤ.\nProof",
                "Tables of cyclic groups\ncan be rearranged such that\nall rising diagonals      contain\nequal elements respectively.",
                "Start on the left.\nThe next element of the headline always\nhas to be the element left below.\nIf this is impossible, start the headline with a new element.",
                "So few elements\ncannot be arranged otherwise than required.",
            ]),
            ZTPage(id: "2.3 - zyklisch Sätze", title: "Theorems on cyclic groups", tool: nil, blocks: [
                "Thanks to isomorphism one can learn from ℤ and ℤ\u{E002}n\u{E003} everything about cyclic groups.\n\nThe subgroups of ℤ are <a> = <–a> = {0, ±a, ±2·a, ±3·a, ...} with a ∈ ℤ.\nFor a ≠ 0, <a> is infinite and isomorphic to ℤ with f(x) = a·x.\nHowever <0> = {0} is finite and isomorphic to ℤ\u{E002}1\u{E003}.",
                "In ℤ\u{E002}n\u{E003} the following theorems hold:\nTheorem:  <a> = <GCD(a, n)>      Proof\nTheorem:  For each divisor d of n there is exactly one cyclic subgroup: <d>    Proof\nTheorem:  For each divisor d of n there are exactly φ(d) elements of order d.    Proof\nTheorem:  All subgroups are cyclic.    Proof\nIn order to translate these theorems for cyclic groups G with generator g, replace n with |G|\nand the generations < x > with < g\u{E000}x \u{E001}>.",
            ]),
            ZTPage(id: "2.3 - pos Erz", title: "Positive generation", tool: .order, blocks: [
                "In a semigroup there needn't be any neutral element, nor invertible elements.\nBut powers with positive exponents are always possible.\n\nDefinition:  Let H be a semigroup, h ∈ H.\n    As positive generation of g we denote <h>\u{E000}+\u{E001} = {h\u{E000}n\u{E001} | n ∈ ℕ}.",
                "Theorem:     Let H be a semigroup, h ∈ H, n ∈ ℕ.\n    h\u{E000}n\u{E001} = h for n > 1  ⇔  <h>\u{E000}+\u{E001} is a group.    Proof\nThe positive generation can be a group.",
                "Examples:    ·  In H = (ℤ\u{E002}n \u{E003}, ·) the set <0>\u{E000}+\u{E001} = {0} forms a group with neutral element 0.\n    ·  In H = (ℤ\u{E002}6\u{E003} , ·) the set <2>\u{E000}+\u{E001} = {2, 4} forms a group with neutral element 4.\n    In both cases <h>\u{E000}+\u{E001} is no subgroup of H, since H is no group.\nEach group <h>\u{E000}+\u{E001} of order n is cyclic and thus isomorphic to ℤ\u{E002}n\u{E003}.\nIn <h>\u{E000}+\u{E001} there can be a neutral element that is not neutral in H,\nand such like invertible elements.",
            ]),
            ZTPage(id: "2.3 - sterne", title: "Generations as stars", tool: .order, blocks: [
                "Consider positive generations <a>\u{E000}+\u{E001} of residue classes modulo\n\nconnection:",
            ]),
        ]))
        chapters.append(ZTChapter(number: "2.4", title: "Primitive Residue Classes", pages: [
            ZTPage(id: "2.4 - 01", title: "Primitive residue classes", tool: .primitiveRoots, blocks: [
                "Now will be inquired which groups of prime residue classes are cyclic.\n\nExamples:    ·  ℤ\u{E002}8\u{E003}* = {1, 3, 5, 7} is not cyclic.\n    ·  ℤ\u{E002}10\u{E003}* = {1, 3, 7, 9} is cyclic with the generators 3 and 7.",
                "Definition:    ·  A prime residue class that generates ℤ\u{E002}m\u{E003}*, is called primitive residue class mod m.\n    ·  A representative of a primitive residue class mod m is called primitive root mod m.",
                "Notice:    There are prime residue classes which are not primitive.\n\nSince the order of an element is the order of its generation,\nholds:  The order of a primitive residue class mod m is φ(m).",
            ]),
            ZTPage(id: "2.4 - Polynome", title: "Polynomials", tool: nil, blocks: [
                "For the first step in the search for primitive residue classes one needs polynomials:\n\nDefinition:     Let R be a commutative ring with one-element 1 ≠ 0.\n    A polynomial of degree n is a function f: R→R of the form\nf(x) = a\u{E002}0\u{E003} + a\u{E002}1\u{E003}·x +...+ a\u{E002}n\u{E003}·x\u{E000}n\u{E001}      with      a\u{E002}0 \u{E003},..., a\u{E002}n\u{E003} ∈ R   and   a\u{E002}n \u{E003}≠ 0.\n    \u{E002}r\u{E003} ∈ R is called root of the polynomial f, if f(r) = 0.",
                "If a root is given, a polynomial can be written as a product:\nTheorem:     \"Factoring out Roots\"\n    Let f be a polynomial of degree n and r a root of f.\n    Then there is a polynomial g of degree n–1, so that f(x) = (x–r)·g(x) for all x ∈ R.\n\nExample    Proof",
            ]),
            ZTPage(id: "2.4 - eindeut Fakt", title: "Unique factorization", tool: nil, blocks: [
                "The group of prime residue classes ℤ\u{E002}8\u{E003}* contains four elements: {1, 3, 5, 7}.\nThe order of each element is ≤ 2, since:\n1\u{E000}2\u{E001} ≡ 1 mod 8,   3\u{E000}2\u{E001} ≡ 1 mod 8,   5\u{E000}2\u{E001} ≡ 1 mod 8,   7\u{E000}2\u{E001} ≡ 1 mod 8.\nHence all four elements are roots of the polynomial x\u{E000}2\u{E001} – 1.",
                "Depending on which root is being factored out, one obtains:\n    ·  (x – 1)·(x – 7)  =  x\u{E000}2\u{E001} –8x + 7   ≡   x\u{E000}2\u{E001} – 1 mod 8, or\n    ·  (x – 3)·(x – 5)  =  x\u{E000}2\u{E001} –8x + 15  ≡  x\u{E000}2\u{E001} – 1 mod 8.",
                "Thus one can not uniquely decompose the polynomial into factors, but in two ways:\nThe factors of the first decomposition have roots that the factors of the second have not.\nThis is only possible, because ℤ\u{E002}8\u{E003} is not a field. Because it holds:",
                "Theorem:  In a field each polynomial has a unique factor decomposition.    Proof",
                "Theorem:  In a field each polynomial of degree n has at most n roots.    Proof\nThus for the number of roots holds:",
            ]),
            ZTPage(id: "2.4 - mod p zyklisch", title: "ℤp* is cyclic", tool: .primitiveRoots, blocks: [
                "The group of the units of a ring R is called group of units R*.\nFor instance, the residue class ring ℤ\u{E002}n\u{E003} has the group of units ℤ\u{E002}n\u{E003}*.\nThe group of units K* of a field K with n elements always has the order n – 1,\nsince all elements except the zero-element are units.",
                "Theorem:    Let K be a finite field with n elements, d ∈ ℕ with d | n – 1.\n    Then in the group of units K* exactly φ(d) elements have the order d.\nExample    Proof",
                "Corollary:    Since n – 1 is a divisor of itself, φ(n–1) elements in K* have the order n – 1.\n    These elements generate K*. Thus K* is cyclic.",
                "Corollary:    If p is prime, ℤ\u{E002}p\u{E003}* is cyclic, because then ℤ\u{E002}p\u{E003} is a field.",
                "Annotation:  The above theorem holds for each finite cyclic group.",
            ]),
            ZTPage(id: "2.4 - zyklisch komplett", title: "When is ℤm* cyclic?", tool: .primitiveRoots, blocks: [
                "    1. (ℤ/2\u{E000}n\u{E001})* is exactly then cyclic, if n < 3.    Proof\n    2. For coprime numbers u, v > 2 (ℤ/u·v)* is not cyclic.    Proof\n    3. Let p be a prime.\n        ·  There is a primitive residue class g mod p so that g\u{E000}p–1\u{E001} ≠ 1 mod p\u{E000}2\u{E001}.\n        ·  If p > 2, then a primitive root of (ℤ/p)* also generates (ℤ/p\u{E000}2\u{E001})*.    Proof\n    For primes p > 2 holds:\n    4. There is a primitive residue class g mod p so that gp\u{E000}n–2\u{E001}·(p–1)  ≠  \u{E002}1 mod p\u{E003}n .    Proof\n    5. A primitive root of (ℤ/p)* also generates (ℤ/p\u{E000}n\u{E001})*.    Proof\n    6. (ℤ/2·p\u{E000}n\u{E001})* is cyclic.      Proof\nResult:  (ℤ/m)* is exactly then cyclic, if m is one of the following numbers:\n1, 2, 4, p\u{E000}n\u{E001}, 2·p\u{E000}n\u{E001}  with an odd prime p\nHere the notation ℤ/m instead of ℤ\u{E002}m\u{E003} is used.\nAbbreviation:  If a is a primitive root mod m, one says: a generates (ℤ/m)*.",
            ]),
            ZTPage(id: "2.4 - finden", title: "Finding primitive residue classes", tool: .primitiveRoots, blocks: [
                "end of this lesson",
                "Primitive residue classes mod m are found by trial and error:\nChoose a prime residue class x and test whether ord(x) = φ(m).\nFor this one can apply the algorithm for calculating an element's order, which can be stopped,\nExample:\nwhen it's clear that ord(x) < φ(m); in this case test the next prime residue class at once.",
                "One exponentiates the classes by the complementary divisors of the prime divisors of φ(m):",
            ]),
        ]))
        return ZTLesson(number: 2, title: "Residue Classes", chapters: chapters)
    }
    static func lesson3() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "3.1", title: "Finding Primes", pages: [
            ZTPage(id: "3.1 - 01", title: "Finding primes", tool: .sieve, blocks: [
                "There are infinitely many primes, but they are the rarer, the higher you get.\nSieve an interval of up to 20000 numbers whose upper bound you enter here:",
                "Prime Number Theorem: Below the limit x there are about          primes, if x is very big.\nln x",
            ]),
            ZTPage(id: "3.1 - Mersenne, Fermat", title: "Mersenne and Fermat numbers", tool: .mersenneFermat, blocks: [
                "An old alchemist-dream of mathematicians is obtaining primes by a formula, which outputs arbitrary many primes.\n\nExamples of similar formulas:\n ·    Euler:  x\u{E000}2\u{E001} – x + 41  yields primes for x = 0, 1, 2, ..., 40.",
                " ·      Mersenne (1588-1648):  M\u{E002}n\u{E003} = 2\u{E000}n\u{E001} – 1\n    These so called Mersenne numbers consist in the binary system only of ones:  111...111\n    If 2\u{E000}n\u{E001} – 1 is prime, then also n is prime. Proof\n    The converse is false, for example:  2\u{E000}11\u{E001} – 1 = 2047 = 23·89\n    In recent years several Mersenne primes were discovered.",
                " ·      Fermat:  F\u{E002}n\u{E003} = 2\u{E000}2\u{E001}  + 1\n    These so called Fermat numbers look in the binary system like this:  100...001\n    If 2\u{E000}k\u{E001} + 1 is prime, then k is a power of two. Proof\n    Fermat primes probably only exist for n = 0, 1, 2, 3 and 4.\n    That F\u{E002}5\u{E003} is composite was proved by Euler.",
            ]),
            ZTPage(id: "3.1 - Tests", title: "Prime number tests", tool: .trialDivision, blocks: [
                "Even if primes can not be constructed at will per formula, one at least wants to be able to decide whether a given number n is prime.",
                "The simplest method is the trial division:\nDivide n by all primes 2, 3, 5, 7, 11, ... to see whether a remainder is left.\nIf up to the root of n no divisor has been found, n is a prime.",
                "The primes that serve as trial divisors can be given by the sieve of Eratosthenes, for example.\nBut for greater n the trial division soon reaches its limits:\n  1. The sieve needs too much memory space.\n  2. The divisions take too much calculation time.",
                "Therefore one has devised different, more efficient tests.\nSome are so called probabilistic tests, that means practically:\n  Where they recognize a number as composite they are right, but\n  where they recognize a number as prime they are mistaken with some probability.",
                "Tests with safe results are more complex and not necessarily needed for practical matters.\nThey are not treated here. We only mention Agrawal's test from 2002.\nAbout prime tests see also: [Agrawal prime test], [Spalka], [Winterhof]",
            ]),
        ]))
        chapters.append(ZTChapter(number: "3.2", title: "Fermat Test", pages: [
            ZTPage(id: "3.2 - 01", title: "The Fermat test", tool: .fermatTest, blocks: [
                "Each prime p passes a test that results from Fermat's Little Theorem:\n    For b ∈ {2, ..., p–1}, test if  b\u{E000}p–1\u{E001} ≡ 1 mod p.\nThis test is called Fermat Test. Unfortunately some composite numbers pass it as well.\nExample:     341 = 11 · 31, and yet  2\u{E000}340\u{E001} ≡ 1 mod 341.",
                "Passing the test provides no information. It must be repeated with a different base b:",
                "Definition:     Let n be a composite number coprime to b.\n    If  b\u{E000}n–1\u{E001} ≡ 1 mod n,  then it is said that     ·  n is pseudoprime to b,                                                       and    ·  b is a liar for (the primality of) n,    otherwise it is said that       ·  b is a witness against (the primality of) n.",
                "Theorem:    If there are any witnesses against n,\n    then they make up at least 50% of all b ∈ {1, ..., n} coprime to n.     Proof",
            ]),
            ZTPage(id: "3.2 - Zeugen Staffel", title: "Fermat witnesses", tool: .fermatTest, blocks: [
                "The order of a liar class divides φ(n) and n–1.\nTheorem:    b is witness against n  ⇔  ord( [b]\u{E002}n\u{E003} ) does not divide n–1.    Proof\nExample:",
                "orders of the residue classes:\nPossible are divisors of φ(n).",
                "b\u{E000}n–1\u{E001} ≡ 1 mod n  ⇔  ord([b]\u{E002}n\u{E003}) | n–1",
            ]),
            ZTPage(id: "3.2 - Carmichael", title: "Carmichael numbers", tool: .carmichael, blocks: [
                "The Fermat test with base b\ndetects no pseudo prime to base b.\nOne repeats it with other bases. Now the\nmaximum credible accident has a name:\nDefinition:\nIf n is a pseudo prime to base b\nfor all integers b where GCD(b, n) = 1,\nthen n is called Carmichael number.\nAre there such numbers at all?",
                "Carmichael numbers < 10\u{E000}9\u{E001}\nR.D.Carmichael discovered them in 1910.\nand choose b",
                "The Fermat test detects a Carmichael number,\nexactly if GCD(b, n) > 1.\nThe probability for this is 1 –          .",
            ]),
            ZTPage(id: "3.2 - Carm. Eigenschaften", title: "Properties of the Carmichael numbers", tool: .carmichael, blocks: [
                "Theorem:  Each Carmichael number is odd.      Proof\nTheorem:  For each prime divisor p of a Carmichael number n holds:  p–1 | n–1.     Proof\nTheorem:  Each Carmichael number n is squarefree.      Proof",
                "Theorem:     If n is an odd, composite, squarefree number,\n    and if for each prime divisor p of n holds:  p–1 | n–1,\n    then n is a Carmichael number.    ProofTheorem:    Carmichael numbers have at least three prime divisors.      Proof",
                "Alford, Granville, Pomerance proved in 1994 that there are infinitely many Carmichael numbers.\nTheorem:  construction of Carmichael numbers\n    If for u ∈ ℕ the three numbers  p\u{E002}1\u{E003}=6·u+1,   p\u{E002}2\u{E003}=12·u+1,   p\u{E002}3\u{E003}=18·u+1  are primes,\n    then  n = p\u{E002}1\u{E003}·p\u{E002}2\u{E003}·p\u{E002}3\u{E003} = (6·u+1)·(12·u+1)·(18·u+1)  is a Carmichael number.\nProof\nThis theorem alone does not prove that there are infinitely many Carmichael numbers,\nsince first must be shown that there are infinitely many prime triples of the given form.\nThis won't be done here.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "3.3", title: "Miller-Rabin Test", pages: [
            ZTPage(id: "3.3 - 01", title: "The idea of the Miller-Rabin test", tool: .millerRabin, blocks: [
                "Some pseudo primes can be detected by taking into account the following:\nTheorem:    Let n be a prime, b coprime to n, k even.\n    Then holds:    b\u{E000}k\u{E001} ≡ 1 mod n   ⇒   b\u{E000}k/2\u{E001} ≡ ±1 mod n    Proof",
                "(b\u{E000}d\u{E001})\u{E000}2\u{E001} = b\u{E000}2·d\u{E001}. After s squarings the exponent has been doubled s times and one gets b\u{E000}n–1\u{E001}.",
                "\"1 is generated by squaring\nonly from 1 or –1.\"",
                "Example:  8\u{E000}560\u{E001} ≡ 1 mod 561,  8\u{E000}280\u{E001} ≡ 1 mod 561,  8\u{E000}140\u{E001} ≡ 67 mod 561  ⇒  561 no prime.",
                "One could have halved the exponent two more times, since 560 = 2\u{E000}4\u{E001}·35.\nGenerally:    n–1 = 2\u{E000}s\u{E001}·d  with s ∈ ℕ and odd d.\n    n–1 can be halved s times, b\u{E000}d\u{E001} is the last possible power.",
                "The Miller-Rabin Test starts from below at b\u{E000}d\u{E001} and squares several times:\nExample: (mod 561)  8\u{E000}35\u{E001} ≡ 461,  8\u{E000}70\u{E001} ≡ 463,  8\u{E000}140\u{E001} ≡ 67  ,  8\u{E000}280\u{E001} ≡ 1  ⇒  561 no prime.",
                "One squares b\u{E000}d\u{E001} at most s–1 times:  If n is prime, then due to b\u{E000}n–1\u{E001} ≡ 1 mod n holds:\nEither already    1) b\u{E000}d\u{E001} ≡ 1 mod n,\nor     2) before b\u{E000}n–1\u{E001} there occurs a power ≡ –1 mod n.\nIf neither 1) nor 2), then n is no prime.",
            ]),
            ZTPage(id: "3.3 - stark pseudo", title: "Strong pseudo primes", tool: .millerRabin, blocks: [
                "Like in Fermat's test the result of Miller-Rabin's test depends on the test base b.\nThe concepts witness, liar, pseudo prime occur once more:",
                "b\u{E000}d\u{E001}, (b\u{E000}d\u{E001})\u{E000}2\u{E001}, ((b\u{E000}d\u{E001})\u{E000}2\u{E001})\u{E000}2\u{E001}, ...... < b\u{E000}n–1\u{E001}",
                "Definition:    Let n be a composite number coprime to b.\n    Let s, d ∈ ℕ such that  n–1 = d·2\u{E000}s\u{E001}  with odd d.\nIf     1) b\u{E000}d\u{E001} ≡ 1 mod n\nor     2) (b\u{E000}d\u{E001})\u{E000}2\u{E001}  ≡ –1 mod n  for an r ∈ {0, ..., s–1},\n\nthen it is said     ·  n is a strong pseudo prime to base b,\n    ·  b is a strong liar for (the primality of) n.\n\nOtherwise – if neither 1) nor 2) holds – it is said that\n    ·  b is a strong witness against (the primality of) n.",
                "Like in Fermat's test one possibly has to try several bases. The difference:\nAgainst each composite number there are enough strong witnesses.\nThis will be proved two pages later. Consider some examples on the next page first.",
            ]),
            ZTPage(id: "3.3 - MR action", title: "The Miller-Rabin test in action", tool: .millerRabin, blocks: [
                "This shows at once that n is no prime.",
                "r      (b\u{E000}d\u{E001})2   mod n  ( ≡ –1 for an r < s, if n is prime)\nsquaring:",
            ]),
            ZTPage(id: "3.3 - max 1/4 Lügner", title: "At most 1/4 liars", tool: .millerRabin, blocks: [
                "Lemma:    Let (A, *) be a finite group, m ∈ ℕ. Then holds:\n    x\u{E000}m\u{E001} = –1 has as many solutions in (A, *) as x\u{E000}m\u{E001} = 1 or none.    Example\nProof",
                "Theorem:    Let n ≠ 9 be odd and composite. Then\nProof",
                "Annotations:\n·  After x rounds of the Miller-Rabin test with x different test bases\n    the probability that n is composite is less than 4\u{E000}–x\u{E001}.\n·  Due to the little density of the primes compared with the composite numbers,\n    the probability that n is composite for big n can be estimated much better.\n    For a 500 bit long number, for example, even after one round it is less than 4\u{E000}–28\u{E001}.\n·  For the most composite big n already b = 2 is a strong witness.\n·  There are infinitely many composite big n whose least strong witness is arbitrary big.\n·  In the area ≤ n there are n\u{E000}1/(35·ln ln ln n)\u{E001} composite numbers with big least strong witnesses.",
                "end of this lesson",
            ]),
        ]))
        return ZTLesson(number: 3, title: "Prime Generation", chapters: chapters)
    }
    static func lesson4() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "4.1", title: "Cryptography", pages: [
            ZTPage(id: "4.1 - 01", title: "Cryptography", tool: .caesar, blocks: [
                "Whoever wants to keep a text secret has two possibilities: hide or encrypt.\nNice examples of hiding provides [Singh 2000].\n\nEncryption translates the text into a different text, the cipher text.\nThe converse is decryption: It translates the cipher text back into the first text, the plain text.\nPlain Text    ———————→    Cipher Text\nencryption\ndecryption",
                "Requirements:     1. Meddlers can not decrypt the cipher text.     2. The decryption is possible: One really gets back the plain text.\nThe difficulty lies in satisfying both requirements simultaneously.\nMoreover should the authorized persons be able to en- and decrypt with only little effort, since in general an out-dated text is worthless. Likewise a great effort in the decryption can practically satisfy the first requirement.",
                "The next pages introduce some general concepts and techniques first,\nthen the idea of public key cryptography, before the next chapters go into details.\nMeddlers are called: the enemy, the attacker, the eavesdropper etc.",
            ]),
            ZTPage(id: "4.1 - Cäsar", title: "The Caesar cipher", tool: .caesar, blocks: [
                "Caesar:    Lay two alphabets displaced over each other, then in each column you can find:\n    on top a letter in the plain text, below its counterpart in the cipher text.",
                "The addressee needs to know by how many letters he has to shift the alphabet.\nUpon this number one agrees as key. Here it corresponds to",
                "This alphabet expands Caesar's alphabet by J, U, W, Y, Z and the space character.\nFor simplification lowercase letters are capitalized and thus come into account, too.\nAll other characters are ignored. If they were put into the cipher text, they could provide the  enemy with hints for the decryption. An act of mercy against the addressee is the introduction of the space character into the alphabet.\nWhoever wants to encrypt more symbols needs a bigger alphabet,\nfor instance the ASCII character set with 128 symbols.",
            ]),
            ZTPage(id: "4.1 - Schlüssel", title: "Key", tool: .caesar, blocks: [
                "From now on our alphabet is the ABC plus space character.\nIt is suitable for illustrations, because it is short and readable.",
                "The size of the alphabet is denoted by |alphabet|.\nWe assign numbers to the symbols of the alphabet in order to allow calculations.\nFor instance, with Caesar one calculates for each symbol x a new symbol x + b (mod 27).\nWe say:    Caesar has the encryption function E(x) = x + b (mod 27).\nAnd:    Caesar has the decryption function D(x) = x – b (mod 27).",
                "Here b serves as key. It makes the method flexible. For different adressees we only take different keys, but do not change the method. The method is called a cipher.",
                "A weak point of the Caesar cipher gets clear:  It knows only 27 keys.\nThus the enemy needs only few tries to obtain a sensible text.\n\nNow we could think about keeping the method secret, but this idea was given up.\nA cypher that has to be kept secret is said to be unsafe. The security must only depend on keeping the key secret.\n\nThus we need methods with as many keys as possible.",
            ]),
            ZTPage(id: "4.1 - multiplik", title: "Multiplicative cipher", tool: .multiplicative, blocks: [
                "Decryption by the inverse function:  D(x) = a'·(x–b') (mod 27)\nEncryption by the function:      E(x) = a·x + b (mod 27)\nnumber of keys: φ(27) · 27\nThis method applies addition and multiplication. Its keys are pairs (a, b).\nTry out which pairs make the encryption reversible.",
                "It must hold:  a·a' ≡ 1 mod 27.",
            ]),
            ZTPage(id: "4.1 - Häuf", title: "Frequency analysis", tool: .frequency, blocks: [
                "To make sure that a decryption is possible, different symbols must be encrypted differently:\nThe encrpytion function – like every reversible mapping –  must be injective.",
                "Each encryption function that simply mixes the symbols of the alphabet is injective.\nThe key is the mixed alphabet, for example\n    key k:    MNBWGHIRSTUJ KLACDEXZFOPQVY\nThis provides  27! = 27·26·...·2·1 = 10888869450418352160768000000  possible keys.",
                "But even this could be easily broken – by frequency analysis:\n\nIn natural language texts the letters occur with different frequencies.\nFor instance, in German or English texts the letter E occurs more often than the letter X.\nFor all languages there are tables of the average frequency of each letter. By comparison with the frequency of each symbol in the cipher text you can soon find some matches and then guess the rest.",
                "What saves from frequency analysis?\nDefine the key not for single characters, but for combinations of characters.\nClassic Example",
            ]),
            ZTPage(id: "4.1 - Text -> Zahl", title: "Text as number", tool: .textToNumber, blocks: [
                "A text can be read as a big number, which can be transformed by calculations:\nEach character forms a digit of this number. The digits run from 0 to |alphabet| – 1.\n\nText:",
                "If the number must not exceed a limit G, the text has to be divided into\nblocks of length L = ⌊log\u{E002}B\u{E003}G⌋. Then each block forms a number of its own.",
            ]),
            ZTPage(id: "4.1 - 0 vorn", title: "Blocks and leading zeros", tool: .textToNumber, blocks: [
                "Transforming a text into a number is not injective:\nIf the space character is mapped to the digit 0, the space characters at the text's beginning\nbecome zeros at the number's beginning – and vanish.\nThus after retransforming the number into a text the leading space characters are missing.",
                "This is another reason for introducing the space character into the alphabet:  \nBetter let vanish the space character than the A.\nWhen dividing a text into blocks, the space characters at each block's beginning vanish.\nThey can be restored, if the block's length is well-known. To prevent the last block from shifting to the right, it must be stuffed with space characters before being transformed into a number.",
                "When dividing a text into blocks, there is another problem:\nExample:   E(x) = x + 2 (mod 30),  D(x) = x – 2 (mod 30),   block length = 1 = ⌊log \u{E002}27 \u{E003}30⌋ .\n     encrypt:  A →  1  →  3 → C    decrypt:  C     →  3   →    1   →   A       ok",
                "    encrypt:  Z → 26 → 28 → AA    decrypt:  A|A → 1 1 → 29 29 → AB|AB  wrong\n\nDue to the block-forming AA has \"forgotten\" it came from 28.",
                "This problem does not occur, if you take the number as cipher text.\n28  →   26   →   Z       ok",
            ]),
            ZTPage(id: "4.1 - asym", title: "Asymmetric cryptography", tool: nil, blocks: [
                "The big problem in cryptography always was the distribution of keys. In order to exchange secret messages, sender and addressee had to agree on a secret key. Whoever overheard this was able to decrypt the secret messages.\nIf each of n persons wants to share secrets with each other, n·(n–1)/2 keys must be agreed on. For instance, n = 1000 persons need 499500 keys.",
                "In the 1970s public key cryptography was invented. It uses two keys:\nA for encryption, B for decryption.\n\nA is called public key, B is called private key.\nThe addressee publishes A like in a telephone book and keeps B secret.\nThen anybody can send messages which only the addressee can decrypt.\nThere are no secret key agreements any more.",
                "For A and B must hold that nobody can deduce B from A.\nTherefore public key encryption is also called asymmetric cryptography.\n\nThe methods on the previous pages however are symmetric:\nCaesar's cipher has the same key for en- as for decryption.\nIn the cipher using multiplication one can easily find factor B, since A·B ≡ 1 mod |alphabet|.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "4.2", title: "RSA", pages: [
            ZTPage(id: "4.2 - 01", title: "The RSA cipher", tool: .rsa, blocks: [
                "after its inventors Ron Rivest, Adi Shamir and Len Adleman",
                "Historically the first public key cipher is RSA.\nIt is based on the difficulty of decomposing big numbers into prime factors.",
                "The addressee chooses two primes p, q and computes the RSA-modulus m = p·q.\nThus is  φ(m) = (p–1)·(q–1)\nThen the addressee chooses    any number b coprime to φ(m)\nand computes with Euclid    the  number a, such that  a·b ≡ 1 mod φ(m)\nThe public key is the pair (m, a),  the private key is b.",
                "The sender first transforms his message into a number n < m.\nHere n must be coprime to m – which for big primes p, q is almost always true.\nThen he computes and sends:      c = n\u{E000}a\u{E001} (mod m).",
                "The addressee decrypts:      c\u{E000}b\u{E001} = n\u{E000}a·b\u{E001} ≡ n\u{E000}1\u{E001} ≡ n mod m\nRemember:      x ≡ y mod φ(m)  ⇒  n\u{E000}x\u{E001} ≡ n\u{E000}y\u{E001} mod m",
                "For deducing b from (m, a) one needs φ(m), thus the prime factors p, q of m.\nWhether there is any possibility of decrypting c without knowing b, is not known.",
            ]),
            ZTPage(id: "4.2 - RSA machen", title: "Trying RSA", tool: .rsa, blocks: [
            ]),
            ZTPage(id: "4.2 - trapdoor", title: "Trapdoor one-way function", tool: nil, blocks: [
                "Encrypting by exponentiation is easy, decrypting is hard.\nA function that is easy to compute but hard to invert is called a one-way function.",
                "The RSA cypher uses the one-way function  f(x) = x\u{E000}a\u{E001} (mod m).\nThis one-way function is a trapdoor function, it has a secret door:\nWhoever knows φ(m), can easily find the \"counter-exponent\" and hence the inverse function.\nφ(m) remains a secret, since it is hard to find the prime factors of m.\nBy the way: the secret prime factors of the RSA-Modulus can be found easily,\nif a corresponding pair of en- and decryption exponents is known.\nFor details see [Buchmann].",
                "Digital Signature:\nIf Alice encrypts a plain text with her own private key,\nanybody can get the plain text by applying her public key\n – and she can't deny that she had encrypted this plain text.",
            ]),
            ZTPage(id: "4.2 - Low Exp Attack", title: "Low exponent attack", tool: .crt, blocks: [
                "Low-Exponent-Attack:\n    Let M = {m\u{E002}1\u{E003}, m\u{E002}2\u{E003}, ..., m\u{E002}e\u{E003}} be a set of e pairwise coprime RSA-moduli,     let n ∈ ℕ be a message such that     n < m\u{E002}i\u{E003}  for all m\u{E002}i\u{E003} ∈ M,\n       let c ∈ ℕ with    0 ≤ c < m\u{E002}1\u{E003}·m\u{E002}2\u{E003}·...·m\u{E002}e\u{E003}        and       c ≡ n\u{E000}e\u{E001} mod m\u{E002}i\u{E003}  for all m\u{E002}i\u{E003} ∈ M.            Then is     c = n\u{E000}e\u{E001}.",
                "    The number c' = n\u{E000}e\u{E001} satisfies the simultaneous congruence c ≡ n\u{E000}e\u{E001} mod m\u{E002}i\u{E003}  for all m\u{E002}i\u{E003} ∈ M,\n    and      0 ≤ c' < m\u{E002}1\u{E003}·m\u{E002}2\u{E003}·...·m\u{E002}e\u{E003},   since n < m\u{E002}i\u{E003} for all m\u{E002}i\u{E003} ∈ M.\n    After the Chinese Remainder Theorem such a solution c' is unique, thus is c = c'.",
                "When you send a message n to many addressees and you encrypt by  c\u{E002}i\u{E003} = n\u{E000}e\u{E001} (mod m\u{E002}i\u{E003}),\nthen use the exponent e less than e times.\nOtherwise an attacker builds the simultaneous congruence  c ≡ c\u{E002}i\u{E003} mod m\u{E002}i\u{E003}  from cipher texts c\u{E002}i\u{E003} and simply solves it with the Chinese Remainder Theorem. The e-th root of c is n.\n\nA sufficient means against the low exponent attack are big encryption exponents e.",
            ]),
            ZTPage(id: "4.2 - Multiplikativität", title: "Multiplicativity", tool: .rsa, blocks: [
                "Multiplicativity:\n    Let (m, a) be a public RSA key.\n    If two messages n\u{E002}1\u{E003} and n\u{E002}2\u{E003} are encrypted, one gets\nc\u{E002}1\u{E003} ≡ n\u{E002}1\u{E003}\u{E000}a\u{E001} mod m    and    c\u{E002}2\u{E003} ≡ n\u{E002}2\u{E003}\u{E000}a\u{E001} mod m.\n    For c = c\u{E002}1\u{E003}·c\u{E002}2 \u{E003} holds:\nc = c\u{E002}1\u{E003}·c\u{E002}2\u{E003}  ≡ (n\u{E002}1\u{E003}·n\u{E002}2\u{E003})\u{E000}a\u{E001} mod m",
                "Thus a swindler can enlarge a cipher text c\u{E002}1\u{E003} by a false addition c\u{E002}2\u{E003} .\nThe addressee can realize this swindle, if the plain text has some constant structure which gets hurt when two plain texts are multiplied. A structure for this purpose could be, for example, that the first symbol accords with the last symbol.",
            ]),
            ZTPage(id: "4.2 - RSA machen lang", title: "RSA with your own numbers", tool: .rsa, blocks: [
                "ab here with BC suchen",
            ]),
        ]))
        chapters.append(ZTChapter(number: "4.3", title: "Other Ciphers", pages: [
            ZTPage(id: "4.3 - 01", title: "The Rabin cipher", tool: .rabin, blocks: [
                "For x ∈ ℙ is  c\u{E000}x–1\u{E001} ≡ 1 mod x.  \"Little Fermat\"",
                "with the Euclidian algorithm",
                "In the Rabin cipher Alice chooses two primes p, q such that p ≡ q ≡ 3 mod 4.\nHer public key is  m = p·q,  her private key is (p, q).",
                "Bob encrypts:     c = n\u{E000}2\u{E001} (mod m)\nAlice decrypts by extracting the root from c. This can be done as follows:",
                "Alice computes:     P = c\u{E000}(p+1)/4\u{E001} (mod p),     Q = c\u{E000}(q+1)/4\u{E001} (mod q)\nNotice:           4 | p+1,             4 | q+1\nThen ±P are the square roots of c in ℤ\u{E002}p\u{E003},  and ±Q likewise in ℤ\u{E002}q\u{E003}, because\n\n    (c\u{E000}(x+1)/4\u{E001})\u{E000}2\u{E001}  =  c\u{E000}(x+1)/2\u{E001}  =  (c\u{E000}x–1+2\u{E001})\u{E000}1/2\u{E001}  =  (c\u{E000}x–1\u{E001}·c\u{E000}2\u{E001})\u{E000}1/2\u{E001}  ≡  c\u{E000}2/2\u{E001}  =  c mod x    for x ∈ ℙ.",
                "Alice computes the four square roots in ℤ\u{E002}m\u{E003} with the Chinese Remainder Theorem:\nShe identifies coefficients x, y such that  x·p + y·q = 1.\nThen she computes  r = (x·p·Q + y·q·P) (mod m),    s = (x·p·Q – y·q·P) (mod m).",
                "One of the four square roots  ±r,  ±s  is the message n.\nAlice has to try which one it is. She will choose the one that provides the most sensible text.",
            ]),
            ZTPage(id: "4.3 - Diffie-Hellman", title: "Diffie-Hellman key exchange", tool: .diffieHellman, blocks: [
                "Diffie and Hellman found a method, how to agree on a secret key if an eavesdropper is present.",
                "Alice and Bob agree on a secret key while being overheard:\n1. They publicly choose a prime p and a primitive root g mod p.\n2. Alice secretly chooses a number a ∈ {1, 2, ..., p–2} and sends Bob A = g\u{E000}a\u{E001} (mod p).\n3. Bob secretly chooses a number b ∈ {1, 2, ..., p–2} and sends Alice B = g\u{E000}b\u{E001} (mod p).\n4. Both compute the same secret key g\u{E000}a·b\u{E001} (mod p):\n    Alice computes B\u{E000}a\u{E001} (mod p) = g\u{E000}a·b\u{E001} (mod p).\n    Bob computes A\u{E000}b\u{E001} (mod p) = g\u{E000}a·b\u{E001} (mod p).",
                "The eavesdropper has to solve the Diffie-Hellman problem:  He knows p, g, A and B,\n       but not the key g\u{E000}a·b\u{E001} (mod p) or the exponents a, b.\n       For getting a or b, he has to compute discrete logarithms in ℤ\u{E002}p\u{E003}*.\n       But discrete logarithms in ℤ\u{E002}p\u{E003}* are very irregular and hard to compute.",
                "Danger:  Man-in-the-middle attack\nThe eavesdropper exchanges keys with Alice and Bob without being noticed.",
            ]),
            ZTPage(id: "4.3 - ElGamal", title: "The ElGamal cipher", tool: .elgamal, blocks: [
                "The ElGamal cipher is closely related to the Diffie-Hellman key exchange.\n\nAlice chooses a prime p and a primitive root g mod p.\nShe chooses any number a ∈ {1, 2, ..., p–2} and computes A = g\u{E000}a\u{E001} (mod p).\nHer public key is (p, g, A). Her secret key is the exponent a.",
                "Bob encrypts n:  He chooses any number b ∈ {1, 2, ..., p–2} and computes\n1. c = A\u{E000}b\u{E001}·n (mod p).    The factor A\u{E000}b\u{E001} = (g\u{E000}a\u{E001})\u{E000}b\u{E001}    is the secret key in Diffie-Hellman.\n2. B = g\u{E000}b\u{E001} (mod p).     The number  B = g\u{E000}b\u{E001}     is Bob's part in Diffie-Hellman.\nBob sends (B, c).\nA drawback of this method is that B doubles the length of the sent packet.",
                "For p ∈ ℙ is  g\u{E000}p–1\u{E001} ≡ 1 mod p.  \"Little Fermat\"",
                "Alice computes     B\u{E000}p–1–a\u{E001}·c (mod p)   and gets n, because\n    B\u{E000}p–1–a\u{E001}·c  ≡  g\u{E000}b·(p–1–a)\u{E001}·A\u{E000}b\u{E001}·n  ≡  (g\u{E000}p–1\u{E001})\u{E000}b\u{E001}·(g\u{E000}a\u{E001})\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  ≡  A\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  ≡  n mod p",
                "Bob has to choose b anew for each new message n. Otherwise holds:\n    c ≡ A\u{E000}b\u{E001}·n mod p,      c' ≡ A\u{E000}b\u{E001}·n' mod p\n    ⇒    c'·c\u{E000}–1\u{E001} ≡ n'·n\u{E000}–1\u{E001} mod p      ⇒    n' ≡ c'·c\u{E000}–1\u{E001}·n mod p.  Anybody who knows n can read n'.",
            ]),
            ZTPage(id: "4.3 - ElGamal2", title: "ElGamal and elliptic curves", tool: .elgamal, blocks: [
                "When using the ElGamal cipher Bob encrypts each message with a new exponent.\nThe opponent doesn't even realize, if the same message is sent twice.\nThis hampers the opponent's statistics.",
                "extension of \"Euler-Fermat\":\nIn each group G holds:  a\u{E000}|G|\u{E001} = e (neutral)  for all a ∈ G.",
                "The ElGamal cipher is not restricted to groups of prime residue classes,\nbut is possible in each cyclic group G where discrete logarithms are hard to compute.\n\nThe group-order |G| is not secret. Alice needs it for decryption:\nAlice computes     B\u{E000}|G|–a\u{E001}·c  in G   and gets n, because\n    B\u{E000}|G|–a\u{E001}·c  =  g\u{E000}b·(|G|–a)\u{E001}·A\u{E000}b\u{E001}·n  =  (g\u{E000}|G|\u{E001})\u{E000}b\u{E001}·(g\u{E000}a\u{E001})\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  =  A\u{E000}–b\u{E001}·A\u{E000}b\u{E001}·n  =  n",
                "Example:     The group of points of an elliptic curve over ℤ\u{E002}p\u{E003}* with p ∈ ℙ\nSomehow the messages must be related to group elements.\nFor details see in the Literature menu after [elliptic curves], especially:\nhttp://www.mi.uni-erlangen.de/~ruppert/WS0001",
                "end of this lesson",
            ]),
        ]))
        return ZTLesson(number: 4, title: "Public Key Cryptography", chapters: chapters)
    }
    static func lesson5() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "5.1", title: "Finding Divisors", pages: [
            ZTPage(id: "5.1 - 01", title: "Finding divisors", tool: .trialDivision, blocks: [
                "This lesson is about decomposing natural numbers n into factors.\nFactorization is another word for factor decomposition.\nAs factors are wanted non-trivial divisors, thus divisors between 1 and n. \nPrimes are special: The factorization of a prime is the prime itself.",
                "The simplest method is the trial division, that can also be used as a prime number test:\n    Divide n by all primes 2, 3, 5, 7, 11, ... to see whether a remainder is left.\n    If up to the root of n no divisor has been found, n is a prime.\n    If n is big, one does not go up to the root of n, but only up to 10000, for instance,\n    and applies other methods then.\n    The trial division is good for finding small divisors.",
                "When a divisor d has been found, one gets its complementary divisor by the division n/d\nand hence the factor decomposition  n = d · n/d.\nBy factorizing the divisors d and n/d, then their divisors and all divisors still to come,\none gets the prime decomposition of n, which is needed, for instance, for computing φ(n).",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.2", title: "Fermat Factorization", pages: [
            ZTPage(id: "5.2 - 01", title: "Fermat factorization", tool: .fermatFactor, blocks: [
                "If for n holds    n = a\u{E000}2\u{E001} – b\u{E000}2\u{E001}  with a, b ∈ ℕ, then the factorization of n is simply     \u{E002}n = (a + b)·(a – b).\u{E003}",
                "Each product of two odd numbers u·v, u > v, can be written this way, because for  \n     n = u·v     with  a = (u+v)/2      and  b = (u–v)/2      holds:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = n.\nExample:\n    15 = 15·1    with  a = (15+1)/2 = 8     and  b = (15–1)/2 = 7    holds:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = 64 – 49 = 15\n    15 = 5·3     with  a = (5+3)/2 = 4    and  b = (5–3)/2 = 1    holds:  a\u{E000}2\u{E001} – b\u{E000}2\u{E001} = 16 – 1 = 15",
                "Fermat's factorization method replaces a with the values  ⌈√n⌉,  ⌈√n⌉ + 1, ...\n     and tests wether a\u{E000}2\u{E001} – n is a square.\n              If so, then a\u{E000}2\u{E001} – n = b\u{E000}2\u{E001} yields the factorization  n = (a + b)·(a – b).",
                "Example:     n = 39\n              ⌈√n⌉ = 7\n    7\u{E000}2\u{E001} – n = 49 – 39 = 10\n    8\u{E000}2\u{E001} – n = 64 – 39 = 25 = 5\u{E000}2\u{E001}  Bingo!\n    ⇒   n = 8\u{E000}2\u{E001} – 5\u{E000}2\u{E001} = (8 + 5)·(8 – 5) = 13 · 3",
            ]),
            ZTPage(id: "5.2 - Fermat Abbruch", title: "When does the method stop?", tool: .fermatFactor, blocks: [
                "If up to a = ⌊(n+9)/6⌋ no square b\u{E000}2\u{E001} has been found, then n is prime.",
                "Example:     n = 47\n               ⌈√n⌉ = 7        limit = ⌊(n+9)/6⌋ = 9\n    7\u{E000}2\u{E001} – n = 49 – 47 = 2\n    8\u{E000}2\u{E001} – n = 64 – 47 = 17\n    9\u{E000}2\u{E001} – n = 81 – 47 = 34\n    ⇒   n is prime.",
                "Move the blue ball\nReason",
            ]),
            ZTPage(id: "5.2 - Quadrate erkennen", title: "Recognizing squares", tool: .fermatFactor, blocks: [
                "Having calculated a\u{E000}2\u{E001}, the next squares are easily found, since the difference between the squares  grows steadily by 2. The first difference is (a+1)\u{E000}2\u{E001} – a\u{E000}2\u{E001} = 2·a + 1.",
                "For deciding whether a\u{E000}2\u{E001} – n is square, one not necessarily needs to extract the root.\nSquares, for example, never end with 2, 3, 7 or 8.\nModulo 10 there are only the quadratic residues {0, 1, 4, 5, 6, 9}.",
                "If a number x is a quadratic non-residue with any module, then x is no square.\nSo one first examines x with several modules, e.g. the odd primes < 20.  \nOnly if x is a quadratic residue with each of these modules, one must extract the root.\nAn examination mod 2 is useless, since each number is a quadratic residue mod 2.\nAn examination mod 16 is good, since only 4 numbers are quadratic residues mod 16.\n\nExample",
                "The Fermat factorization is good, if the factors of n are close together.\nThe worst case of Fermat's method is exactly the best case of the trial divison and vice versa.\nSo it's a good idea to combine both methods.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.3", title: "Pollard's Rho Factorization", pages: [
            ZTPage(id: "5.3 - 01", title: "The birthday paradox", tool: .birthday, blocks: [
                "How many persons are needed at a party before you should bet that there are duplicate birthdays?",
                "when it is more likely to win than to loose",
                "The days of the year are\ncounted from 1 to 365,\nthus 32 is February 1.\nFebruary 29 is ignored.",
                "The right column says how many persons have their birthdays on the day left.",
                "Birthday Paradox:\n    On Earth only 23 persons are needed.     Proof\n    In general:\n    If the year has n days, little more than √n persons are needed.",
                "birthday     persons\n{> 365    each betting wins\n(For simplification each year has 365 days.)\n   k    bettings     won bettings",
            ]),
            ZTPage(id: "5.3 - pollard rho", title: "The idea of Pollard's Rho", tool: .rhoSequence, blocks: [
                "the greek letter Rho",
                "Pollard's ρ-factorization starts a pseudo-random sequence of values:\n    x\u{E002}1\u{E003} := random(0, n–1)\n    x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)\nx\u{E002}1\u{E003} ∈ ℤ is the initial value, f is a polynomial with coefficients ∈ ℤ, like x\u{E000}2\u{E001} + 1.",
                "Let d be a non-trivial divisor of n.\nThen it is likely that there exist x\u{E002}i\u{E003} and x\u{E002}j\u{E003} such that:\n    x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d\n    x\u{E002}i\u{E003} ≠ x\u{E002}j\u{E003} mod n",
                "After the birthday paradox this case occurs after little more than √d sequence members.\nThen holds:     d divides x\u{E002}i\u{E003} – x\u{E002}j\u{E003} ,  but n doesn't divide x\u{E002}i\u{E003} – x\u{E002}j\u{E003} .\n    Thus  GCD(x\u{E002}i\u{E003} – x\u{E002}j\u{E003}, n)  yields a non-trivial divisor of n.",
                "The question is, how to find the correct x\u{E002}i\u{E003} and x\u{E002}j\u{E003} quickly.\nIf GCD(x\u{E002}i\u{E003} – x\u{E002}j\u{E003}, n) had to be calculated for all combinations of sequence members x\u{E002}i\u{E003} and x\u{E002}j\u{E003} ,\nthe algorithm would be worse than trial division.",
            ]),
            ZTPage(id: "5.3 - Kreise", title: "Sequences run in cycles", tool: .rhoSequence, blocks: [
                "Due to  x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)  the sequence runs cyclically after n members at latest.\nNow let d be a non-trivial divisor of n.\nIf for two sequence members holds x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d,  then due to  x\u{E002}i+1\u{E003} := f(x\u{E002}i\u{E003}) (mod n)\n    also holds x\u{E002}i+k\u{E003} ≡ x\u{E002}j+k\u{E003} mod d  for all k ∈ ℕ.\nThe reduction mod n subtracts multiples of d, so it preserves the congruence mod d.\nHence the sequence also forms a cycle mod d – which can be smaller than the cycle mod n.",
                "Example:  n = 15,   f(x) = x\u{E000}2\u{E001} + 1,  random initial value x\u{E002}1\u{E003} = 3.\ni        1    2    3    4    5    6    7    8    9\nx\u{E002}i\u{E003} mod 15    3    10    11    2    5    11    2    5    ...",
                "The values of the cycle, that return, form the period.\nThe values at the beginning, that do not return, form the preperiod.",
                "One looks for members of the sequence such that x\u{E002}i\u{E003} ≡ x\u{E002}j\u{E003} mod d.\nSince the sequence runs cyclically, a cycle finding algorithm is helpful.",
            ]),
            ZTPage(id: "5.3 - Floyd, Brent", title: "Floyd and Brent", tool: .rhoSequence, blocks: [
                "When Pollard introduced his ρ-algorithm in 1975, he used\nFloyd's cycle finding algorithm:\nFloyd starts two variables  x and y at the same value\nand computes in each step:\n     x\u{E002}i+1 \u{E003}:= f(x\u{E002}i\u{E003}),    x\u{E002}i+2 \u{E003}:= f(x\u{E002}i+1\u{E003})\n    y\u{E002}j+1 \u{E003}:= f(y\u{E002}j\u{E003})\nThus x runs through the sequence twice as fast as y\nand soon overtakes y. Then the cycle is found.",
                "In 1980 Brent introduced a cycle finding algorithm,\nthat in each step performs only one calculation:\n    If i is a power of 2, set y := x\u{E002}i\u{E003}.\n    Compute  x\u{E002}i+1 \u{E003}:= f(x\u{E002}i\u{E003})  and\n    compare the new value x\u{E002}i\u{E003} with y.\nBrent illustration with numbers",
                "Pollard eternalized the picture in the name ρ-algorithm.",
            ]),
            ZTPage(id: "5.3 - pollard rho Algo", title: "The Rho algorithm", tool: .pollardRho, blocks: [
                "The runtime of the cycle finding algorithm depends on the initial value x\u{E002}1\u{E003}. Hence, when having reached a certain limit, one tries another initial value. The limit is based on the birthday paradox and the fact that n ∉ ℙ has a divisor d ≤ √n .",
                "Algorithm:    Comments:\nlimit := sqrt( sqrt(n) ) + 1000    # birthday paradox for divisor of n\nx := random(0, n–1)    # random initial value x\ni := 1\nd := 1\nwhile d = 1, repeat  {    # Brent's cycle findung algorithm\n    j := i\n    y := x    # y stores x\u{E002}j \u{E003}, when j = power of 2\n    while i < 2·j, repeat  {\n        x := f(x) (mod n)    # usually f(x) = x\u{E000}2\u{E001} + 1.\n        i := i + 1\n          if x = y or i > limit, then stop    # try new initial value x\n        d := GCD( x–y, n )    # want a cycle mod d, not mod n.\n        if d > 1, then output: d    # divisor of n found\ninitial value",
                "The runtime also depends on:\n·  the sequence function f, which can be changed as well,\n    as long as it provides integer values\n·  the module n, which cannot be changed,\n    as it is just being factorized\nx := f(x) (mod n)",
                "The algorithm finds the cycle faster, if next to the latest the latest but one x\u{E002}j\u{E003} is stored:  y and y1\nBelow one has to calculate:\nd := GCD( (x–y)·(x–y1), n)\ny1 := y",
                "For finding a cycle mod n\nsimply test whether x = y.",
            ]),
            ZTPage(id: "5.3 - Pollard Rho demo", title: "Pollard's Rho in action", tool: .pollardRho, blocks: [
                "x\u{E002}i+1\u{E003} := x\u{E002}i\u{E003}\u{E000}2\u{E001} + 1 (mod n)",
                "sqrt( sqrt(n) ) + 1000  is approximized\nby 10⌊digitcount(n) / 4⌋ + 1000",
                "j    x\u{E002}j\u{E003}      i    x\u{E002}i\u{E003}     Limit for i:",
                "No non-trivial divisor has been found.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.4", title: "Pollard's p–1 Factorization", pages: [
            ZTPage(id: "5.4 - 01", title: "The idea of Pollard's p–1", tool: .pollardPm1, blocks: [
                "Pollard also found a factorization method that exploits \"Little Fermat\".\nLet n have the prime divisor p. Let a be randomly chosen and coprime to n – and thus to p.\n⇒      a\u{E000}p–1\u{E001} ≡ 1 mod p    \"Little Fermat\"\n⇒      p | a\u{E000}p–1\u{E001}–1",
                "⇒      GCD( a\u{E000}p–1\u{E001}–1, n ) > 1\nIf     GCD( a\u{E000}p–1\u{E001}–1, n ) < n,  one has found a non-trivial divisor of n – but unfortunately the exponent p–1 is unknown, if p is unknown.",
                "Idea:    Choose a multiple of p–1 as exponent.\n1. Due to  a\u{E000}(p–1)·z\u{E001} = (a\u{E000}p–1\u{E001})\u{E000}z\u{E001} ≡ 1 mod p  the above trick also works with (p–1)·z for all z ∈ ℤ.\n2. Choose as exponent a product k of many primes – and hope that p–1 | k.",
                "Let     p | a\u{E000}p–1\u{E001}–1  and luckily  p–1 | k.\n⇒    p | a\u{E000}k\u{E001}–1    One computes a\u{E000}k\u{E001} (mod n) by \"square & multiply\".\n⇒    p | a\u{E000}k\u{E001} (mod n) – 1    Because the reduction mod n subtracts multiples of p, as p | n.\nIf    GCD(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  we are successful.",
            ]),
            ZTPage(id: "5.4 - faktbas", title: "Factor base and B-smoothness", tool: .pollardPm1, blocks: [
                "Let     p | a\u{E000}p–1\u{E001}–1  and  p–1 | k.\n⇒    p | a\u{E000}k\u{E001}–1    Calculate a\u{E000}k\u{E001} (mod n) by \"square & multiply\".\n⇒    p | a\u{E000}k\u{E001} (mod n) – 1    because the reduction mod n subtracts multiples of p.\nIf    GCD(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  stop successfully.",
                "Let     p | a\u{E000}p–1\u{E001}–1  and  p–1 | k.",
                "If    GCD(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) < n,  we are successful.",
                "The exponent k is built this way:\nChoose a number B and compute k as the product of all prime powers ≤ B.\nExample:    B = 10     ⇒       k = 2\u{E000}3\u{E001}·5·7 = 280",
                "This concept is borrowed from the concept B-smooth:\n    If p–1 has no prime > B as divisor, p–1 is called B-smooth.\nB-smoothness makes no restriction for the exponent of a prime divisor.\nExample:      2\u{E000}3\u{E001}·5·7 = 280 is 7-smooth, but not 7-fed.",
                "If  p–1 | k,  in other words: if p–1 has no prime power > B as divisor, then p–1 is called B-fed.\n\nThe p–1 method hopes there is a prime divisor p of n such that p–1 is B-fed.\nTherefore one wants to make B as big as possible.",
                "But if B is too big, then for all prime divisors q of n holds that q–1 is B-fed.\n⇒    q | a\u{E000}k\u{E001} (mod n) – 1    for all prime divisors q of n\nIf in this situation n has no prime divisor q twice, then holds:\n    GCD(  a\u{E000}k\u{E001} (mod n) – 1,  n  ) = n.   So one finds no divisor < n.",
                "The case GCD = n means in general: The order of [a]\u{E002}n\u{E003} divides k. This is obvious for a = 1.\nThus one decreases B or changes a. But there are numbers n that are helpless:  Example",
            ]),
            ZTPage(id: "5.4 - p-1 demo", title: "Pollard's p–1 in action", tool: .pollardPm1, blocks: [
                "This is already a true divisor of n. That was good luck!",
                "    ⇒  a is coprime to all divisors of n.\n    Let p be a prime divisor of n, and luckily be p–1 | k.\n      ⇒  a\u{E000}k\u{E001} ≡ 1 mod p,      since a\u{E000}p–1\u{E001} ≡ 1 mod p (\"Little Fermat\")\n      ⇒  p | a\u{E000}k\u{E001}–1\n      ⇒  p | a\u{E000}k\u{E001} (mod n) –1,    since the reduction subtracts multiples of p.\n      ⇒  GCD( a\u{E000}k\u{E001} (mod n) –1, n ) > 1\na\u{E000}k\u{E001} (mod n)",
            ]),
            ZTPage(id: "5.4 - ECM", title: "Elliptic curves (ECM)", tool: .factorize, blocks: [
                "Consider a\u{E000}k\u{E001} in the decomposition ℤ\u{E002}n\u{E003} @ ℤ\u{E002}p\u{E003}× ℤ\u{E002}q\u{E003}× ... .\nGCD( a\u{E000}k\u{E001}–1, n) provides a multiple of p,\nif        a\u{E000}k\u{E001}–1 = (0, ...)\nthus    a\u{E000}k\u{E001}     = (1, ...)\nBy exponentiation with exponent k one hopes to reach the neutral element 1 of the group ℤ\u{E002}p\u{E003}*.\nThis succeeds, if luckily k is a multiple of the group order p–1.\nBesides groups of residue classes there are groups related to p with orders different from p–1.\nThey provide new chances for k.\nThis is exploited for factorization by the elliptic curve method (ECM).\nDescriptions are listed in the literature glossary after [elliptic curves].",
                "Its exponent is the global variable pollardk,\nwhich can be computed by function faktbas(b) from file prims.txt.\nSince BC is not very fast, even faktbas(10000) generates an exponent,\nwhere calculations take considerable time. It consists of 4349 decimals.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "5.5", title: "Quadratic Sieve Factorization", pages: [
            ZTPage(id: "5.5 - 01", title: "The Quadratic Sieve", tool: .factorize, blocks: [
                "Translation of a description from [Buchmann]:\n\nOne of the most efficient factorization methods is the Quadratic Sieve.\n\nThe principle:\nOne identifies integers x and y for which holds:\n   x\u{E000}2\u{E001} ≡ y\u{E000}2\u{E001} mod n  and\n   x  ≠ ±y  mod n\nThen n is a divisor of x\u{E000}2\u{E001} – y\u{E000}2\u{E001} = (x – y)·(x + y), but neither of x – y nor of x + y.\nThus GCD(x – y, n) is a non-trivial divisor of n.\n\nIdentification of x and y:\nThe above principle is also applied in other factorization algorithms, for instance in the\nnumber field sieve. The methods differ in how x and y are found.\nIn the quadratic sieve it works as follows:\n\nLet  m = ⌊√n⌋  and  f(X) = (X + m)\u{E000}2\u{E001} – n.\nExample:  n = 7429.  Thus is  m = 86,   f(X) = (X + 86)\u{E000}2\u{E001} – 7429. It holds\n  f(–3)  =  83\u{E000}2\u{E001} – 7429  =  –540  =  –1·2\u{E000}2\u{E001}·3\u{E000}3\u{E001}·5\n  f(1)    =  87\u{E000}2\u{E001} – 7429  =    140  =       2\u{E000}2\u{E001}·5·7\n  f(2)    =  88\u{E000}2\u{E001} – 7429  =    315  =       3\u{E000}2\u{E001}·5·7\nFrom this follows\n  83\u{E000}2\u{E001}  ≡  –1·2\u{E000}2\u{E001}·3\u{E000}3\u{E001}·5 mod 7429\n  87\u{E000}2\u{E001}  ≡       2\u{E000}2\u{E001}·5·7 mod 7429\n  88\u{E000}2\u{E001}  ≡       3\u{E000}2\u{E001}·5·7 mod 7429\nBy multiplying the last two congruences one gets\n  (87·88)\u{E000}2\u{E001} ≡ (2·3·5·7)\u{E000}2\u{E001} mod n\nThus one sets\n  x = 227 ≡ 87·88 mod n\n  y = 210 ≡ 2·3·5·7 mod n\n\nThis example yields numbers s where f(s) has only small prime factors. How to find such numbers will be explained below. One utilizes that \n  (s + m)\u{E000}2\u{E001} ≡ f(s) mod n\nand selects congruences of this shape whose products on the left and right side are squares. The left side of a congruence always is square. Thus the product of any left sides is square. On the right sides the prime decompositions are known; thus one gets a square, when the exponents of all prime factors and the exponent of –1 are even.\n\nSelection of suitable congruences:\nIn the above example one can see directly which congruences must be multiplied so that the product of the right sides yield a square. For big numbers n one must select suitable congruences from more than 100000 possible congruences. Here one applies linear algebra.\n\nExample:\n   (–1·2\u{E000}2\u{E001}·3\u{E000}3\u{E001}·5)\u{E000}u\u{E001} · (2\u{E000}2\u{E001}·5·7)\u{E000}v\u{E001} · (3\u{E000}2\u{E001}·5·7)\u{E000}w\u{E001}\n   (–1)\u{E000}u\u{E001} · 2\u{E000}2·u+2·v\u{E001} · 3\u{E000}3·u+2·w\u{E001} · 5\u{E000}u+v+w\u{E001} · 7\u{E000}v+w\u{E001}\nis square. This number is square, if the exponent of –1 and the exponents of all primes are even. One gets the following system of congruences:\n           u ≡ 0 mod 2\n  2·u+2·v ≡ 0 mod 2\n 3·u+2·w ≡ 0 mod 2\n   u+v+w ≡ 0 mod 2\n       v+w ≡ 0 mod 2\nThe coefficients of the unknown u, v, w can be reduced modulo 2. One gets the simpler system\n           u ≡ 0 mod 2\n   u+v+w ≡ 0 mod 2\n       v+w ≡ 0 mod 2.\nFrom this one gets the solution\n   u = 0,  v = w = 1.\n\nIn general:\nOne chooses a natural number B. One looks for small integers s for which f(s) only has small prime factors in the factorbase  F(B) = {p ∈ ℙ: p ≤ B} ∪ {–1}.\nSuch values f(s) are called B-smooth. When one has found as many numbers as the factorbase has elements, one builds the corresponding linear system of congruences and solves it.\nSince the system of congruences is a linear system of equations over the field ℤ\u{E002}2\u{E003} , one can solve it with the Gauss algorithm. But since the number of equations and variables in general is very big, one prefers special methods, which won't be further explained here. (Buchmann somewhere else mentions an algorithm by Wiedemann for thinnly filled systems of equations).\n\nThe sieve:\nStill to be explained is, how to find numbers s for which f(s) is B-smooth. One could compute f(s) for s = 0, ±1, ±2, ... and then test by trial division whether f(s) is B-smooth. But this is very laborious. For checking that f(s) is not B-smooth, one must divide f(s) by all primes p ≤ B. In general factorbases are very big, thus trial division can take very long. Faster is a sieve method.\nOne looks for all s∈S for which f(s) is B-smooth. One first calculates all values f(s), s∈S.\nFor each prime p from the factorbase one divides all values f(s) by the highest possible p-power. The B-smooth values f(s) are exactly the ones where remains 1 or –1.\n\nFor deciding which values f(s) = (s + m)\u{E000}2\u{E001} – n are divisible by a prime p from the factorbase, one first identifies the numbers s∈{0, 1, ..., p–1} for which f(s) is divisible by p. Since the polynomial f(X) has at most two roots modulo p, there are either two, one or no numbers s.\nFor small primes one can find the roots by trial and error.\nIf p is big, one must apply different methods (see below [4]). By wandering from these roots  through the sieve interval rightwards and leftwards in steps of length p, one finds all s-values for which f(s) is divisible by p. This procedure is called sieve with p. One divides only divisible values f(s). There are no unsuccessful trial divisions any more.\n\nExample:\nLike above  n = 7429,  m = 86,   f(X) = (X + 86)\u{E000}2\u{E001} – 7429.\nAs factorbase take the set {2, 3, 5, 7} ∪ {–1},\nas sieve interval the set {–3, –2, ..., 3}.  Then the sieve looks like this:\n\n s       –3        –2        –1       0       1       2       3\n(s + m)\u{E000}2\u{E001} – n    –540    –373    –204    –33    140    315    492\nsieve with 2    –135          –51          35        123\nsieve with 3       –5          –17    –11          35      41\nsieve with 5       –1                   7       7\nsieve with 7                       1       1\n\n\nThe sieve can be made much more efficient. See [28].\n\nLiterature:\n[4]     E. Bach and J. Shallit. Algorithmic number theory. MIT Press, Cambridge, Massachusetts     and London, England, 1996.\n[28]    H. Riesel. Prime numbers and computer methods for factorization. Birkhäuser, 1994.",
                "end of this lesson",
            ]),
        ]))
        return ZTLesson(number: 5, title: "Factorization", chapters: chapters)
    }
    static func lesson6() -> ZTLesson {
        var chapters: [ZTChapter] = []
        chapters.append(ZTChapter(number: "6.1", title: "Finding Exponents", pages: [
            ZTPage(id: "6.1 - 01", title: "Discrete logarithms", tool: .dlogEnum, blocks: [
                "Let G be a finite cyclic group, g be a generator of G and a an element of G.\nThe smallest not negative number x with g\u{E000}x\u{E001} = a is called discrete logarithm of a to base g.",
                "· a prime, e.g. 2, or\n· a power of an odd prime, e.g. 9, or\n· twice of the above, e.g. 4 or 18.\n(ℤ/m)* is cyclic  ⇔  m is",
                "The discrete logarithm in general is very irregular and hard to find.\n\nThe simplest method is the enumeration: Sequencially replace x with all group elements a and test whether g\u{E000}x\u{E001} = a is true. But this can take a very long time.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.2", title: "Shanks's Babystep Giantstep Method", pages: [
            ZTPage(id: "6.2 - 01", title: "The babystep giantstep idea", tool: .bsgs, blocks: [
                "This algorithm solves g\u{E000}x\u{E001} = a faster than enumeration, but it needs more memory space:\n          Solve the lower equation, roughly spoken, this way:\n          Collect all right sides, compare them to the left sides, until they are equal.\nSet     w = ⌈√n ⌉ , where n is the group's order.\nIdea:   g\u{E000}x\u{E001} = g\u{E000}q·w+r\u{E001} = a             (with q, r ∈ ℕ\u{E002}0\u{E003} and  0 ≤ r < w)\n          ⇔   g\u{E000}q·w\u{E001} = a·g\u{E000}–r \u{E001}",
                "The collected right sides form the babysteps B = { (a·g\u{E000}–r\u{E001}, r) | 0 ≤ r < w }.\nIf B contains a pair (1, r), it is clear at once that  q = 0  and  x = r.",
                "Giantsteps: Try for q = 1, 2, 3, ... whether B contains a pair (g\u{E000}q·w\u{E001}, ...).\nIf so, the second component of the pair is the wanted r such that  g\u{E000}q·w\u{E001} = a·g\u{E000}–r\u{E001},\nand hence the discrete logarithm is  x = q·w + r .\nFor speeding-up one first sets d = g\u{E000}w\u{E001}  and in each giantstep only computes d\u{E000}q\u{E001}.",
                "To enable fast checks whether B contains a pair (d\u{E000}q\u{E001}, ...),\none keeps the babysteps in a hash table, sorted by their first components.",
            ]),
            ZTPage(id: "6.2 - Baby-Giant", title: "Babystep giantstep in action", tool: .bsgs, blocks: [
                "6.2 Shanks's Babystep-Giantstep-Method – Examples in ℤ\u{E002}m\u{E003}*",
                "Babysteps (a·g\u{E000}–r\u{E001}, r),  0 ≤ r < w.             Hashtable",
                "As soon as  g\u{E000}w·q\u{E001} = a·g\u{E000}–r\u{E001},  holds  a = g\u{E000}w·q+r\u{E001} = g\u{E000}x\u{E001}.",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.3", title: "Pollard's Rho Algorithm", pages: [
            ZTPage(id: "6.3 - 01", title: "Pollard's Rho for logarithms", tool: .dlogEnum, blocks: [
                "For solving g\u{E000}x\u{E001} = a in G with generator g, one can also use Pollard's Rho algorithm.\nIts advantage: constant need of memory. Like in its application for factorization,\none calculates a pseudo random sequence searching for a cycle:",
                "Divide G into three subsets G\u{E002}1\u{E003}, G\u{E002}2\u{E003}, G\u{E002}3\u{E003} and define a function f: G → G with\n    g·b    if b ∈ G\u{E002}1\u{E003}\n    f(b) =    b\u{E000}2\u{E001}    if b ∈ G\u{E002}2\u{E003}\n    a·b    if b ∈ G\u{E002}3\u{E003}\nChoose a random z\u{E002}1\u{E003} ∈ {1, ..., |G|}, set    b\u{E002}1\u{E003} = g\u{E000}z\u{E001}1   and continue with  b\u{E002}i+1\u{E003} = f(b\u{E002}i\u{E003}).",
                "Keep an account of the number of factors g and a. Set  y\u{E002}1\u{E003} = 0  and then:\n    z\u{E002}i\u{E003} + 1    (mod |G|)    if b\u{E002}i\u{E003} ∈ G\u{E002}1\u{E003}    y\u{E002}i\u{E003}         if b\u{E002}i\u{E003} ∈ G\u{E002}1\u{E003}\n    z\u{E002}i+1\u{E003} =    2·z\u{E002}i\u{E003}     (mod |G|)    if b\u{E002}i\u{E003} ∈ G\u{E002}2\u{E003}               y\u{E002}i+1\u{E003} =    2·y\u{E002}i\u{E003}     (mod |G|)    if b\u{E002}i\u{E003} ∈ G\u{E002}2\u{E003}\n    z\u{E002}i\u{E003}         if b\u{E002}i\u{E003} ∈ G\u{E002}3\u{E003}    y\u{E002}i\u{E003} + 1    (mod |G|)    if b\u{E002}i\u{E003} ∈ G\u{E002}3\u{E003}    z counts the factors g,     y counts the factors a.\nFor the members of the sequence holds:     b\u{E002}i\u{E003} = g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i",
            ]),
            ZTPage(id: "6.3 - Pollard log", title: "Solving the congruence", tool: .dlogEnum, blocks: [
                "For the members of the sequence b\u{E002}i\u{E003} ∈ G holds:     b\u{E002}i\u{E003} = g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i\n\nAfter the birthday paradox the members of the sequence b\u{E002}i\u{E003} recur after k ≈ √ |G| steps.",
                "Then holds:    g\u{E000}z\u{E001}i · a\u{E000}y\u{E001}i  =  g\u{E000}z\u{E001}i+k · a\u{E000}y\u{E001}i+k\nand hence:    g\u{E000}z\u{E001}i \u{E000}– z\u{E001}i+k  =  a\u{E000}y\u{E001}i+k \u{E000}– y\u{E001}i\nFor the discrete logarithm x of a to base g  holds thus:     z\u{E002}i \u{E003}–z\u{E002}i+k\u{E003}  ≡  x·(y\u{E002}i+k\u{E003} – y\u{E002}i\u{E003})  mod |G|",
                "If this congruence has several solutions, the correct one can be found by trial and error.\nIf there are too many, one repeats the calculation with a new initial value z\u{E002}1\u{E003}.\n\nExamples in groups of prime residue classes:",
            ]),
        ]))
        chapters.append(ZTChapter(number: "6.4", title: "Other Methods", pages: [
            ZTPage(id: "6.4 - 01", title: "Other methods", tool: .dlogEnum, blocks: [
                "[Buchmann] continuous the course with stronger methods:\n\n·  Pohlig-Hellman algorithm\n    If the prime decomposition of the group's order |G| is known,\n    one solves g\u{E000}x\u{E001} = a in many small groups\n    and constructs from this the solution in G.\n\n·  Index Calculus methods\n    They are related with Quadratic Sieve and Number Field Sieve for factorization.",
                "end of this lesson",
            ]),
        ]))
        return ZTLesson(number: 6, title: "Discrete Logarithms", chapters: chapters)
    }
    static let glossary: [ZTGlossaryEntry] = [
        ZTGlossaryEntry(term: "addition of residue classes", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "algebraic structure", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "alphabet", pageID: "4.1 - Cäsar"),
        ZTGlossaryEntry(term: "associative", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "asymmetric cryptography", pageID: "4.1 - asym"),
        ZTGlossaryEntry(term: "babystep giantstep algorithmus", pageID: "6.2 - 01"),
        ZTGlossaryEntry(term: "B-fed", pageID: "5.4 - faktbas"),
        ZTGlossaryEntry(term: "bijective", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "binomial formula", pageID: "2.4 - zyklisch komplett"),
        ZTGlossaryEntry(term: "birthday paradox", pageID: "5.3 - 01"),
        ZTGlossaryEntry(term: "Brent's cycle finding algorithm", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "Caesar cipher", pageID: "4.1 - Cäsar"),
        ZTGlossaryEntry(term: "canonical prime decomposition", pageID: "1.2 - kanonische PFZ"),
        ZTGlossaryEntry(term: "Cartesian product", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "Carmichael number", pageID: "3.2 - Carmichael"),
        ZTGlossaryEntry(term: "Chinese remainder theorem", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "cipher", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "clock setting", pageID: "2.2 - Uhren verstellen"),
        ZTGlossaryEntry(term: "closed", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "coefficients of a linear combination", pageID: "1.3 - 01"),
        ZTGlossaryEntry(term: "commutative", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "complementary divisor", pageID: "1.1 - 01"),
        ZTGlossaryEntry(term: "composed number", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "congruence", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "congruences, solving", pageID: "2.2 - Kongruenzen lösen"),
        ZTGlossaryEntry(term: "connection", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "cycle finding algorithm", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "cyclic group", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "cyclic group of prime residue classes", pageID: "2.4 - zyklisch komplett"),
        ZTGlossaryEntry(term: "cipher text", pageID: "4.1 - 01"),
        ZTGlossaryEntry(term: "decomposition of a ring", pageID: "2.2 - Zerlegung Ring"),
        ZTGlossaryEntry(term: "decryption function", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "Diffie-Hellman key exchange", pageID: "4.3 - Diffie-Hellman"),
        ZTGlossaryEntry(term: "digital signature", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "direct product", pageID: "2.2 - Zerlegung Ring"),
        ZTGlossaryEntry(term: "discrete logarithm", pageID: "6.1 - 01"),
        ZTGlossaryEntry(term: "distributive", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "divisibility criteria", pageID: "2.1 - Quersummen"),
        ZTGlossaryEntry(term: "divisibility rules", pageID: "1.1 - Teiler in Z"),
        ZTGlossaryEntry(term: "divisible", pageID: "1.1 - Teiler in Z"),
        ZTGlossaryEntry(term: "division with remainder", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "divisor", pageID: "1.1 - 01"),
        ZTGlossaryEntry(term: "divisor set", pageID: "1.1 - Teilermenge"),
        ZTGlossaryEntry(term: "ElGamal cipher", pageID: "4.3 - ElGamal"),
        ZTGlossaryEntry(term: "elliptic curve", pageID: "4.3 - ElGamal2"),
        ZTGlossaryEntry(term: "elliptic curve factorization", pageID: "5.4 - ECM"),
        ZTGlossaryEntry(term: "encryption function", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "enumeration", pageID: "6.1 - 01"),
        ZTGlossaryEntry(term: "equivalence class", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "equivalence relation", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "Eratosthenes, sieve of", pageID: "1.2 - Eratosthenes"),
        ZTGlossaryEntry(term: "Euclidian algorithm", pageID: "1.3 - Euklid Ablauf"),
        ZTGlossaryEntry(term: "Euler function", pageID: "2.2 - Euler-Funktion"),
        ZTGlossaryEntry(term: "Euler function, computing (1)", pageID: "2.2 - Berechnung Euler 1"),
        ZTGlossaryEntry(term: "Euler function, computing (2)", pageID: "2.2 - Berechnung Euler 2"),
        ZTGlossaryEntry(term: "Euler-Fermat, theorem", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "factor decomposition", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "factoring out of roots", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "factorization", pageID: "5.1 - 01"),
        ZTGlossaryEntry(term: "Fermat factorization", pageID: "5.2 - 01"),
        ZTGlossaryEntry(term: "Fermat number", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "Fermat's last theorem", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Fermat's little theorem", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Fermat test", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "field", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Floyd's cycle finding algorithm", pageID: "5.3 - Floyd, Brent"),
        ZTGlossaryEntry(term: "frequency analysis", pageID: "4.1 - Häuf"),
        ZTGlossaryEntry(term: "fundamental theorem of arithmetic", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "GCD", pageID: "1.1 - Def ggT"),
        ZTGlossaryEntry(term: "GCD as linear combination", pageID: "1.3 - Eigenschaften ggT"),
        ZTGlossaryEntry(term: "generation", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "generator", pageID: "2.3 - Erzeugnis"),
        ZTGlossaryEntry(term: "group", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "homomorphism", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "injective", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "integer quotient", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "inverse element", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "isomorphism", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "key", pageID: "4.1 - Schlüssel"),
        ZTGlossaryEntry(term: "Lagrange's theorem", pageID: "2.3 - Lagrange"),
        ZTGlossaryEntry(term: "LCM", pageID: "1.4 - 01"),
        ZTGlossaryEntry(term: "little Fermat", pageID: "2.2 - Fermat, Euler"),
        ZTGlossaryEntry(term: "Lucas-Lehmer test", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "liar", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "liar, strong", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "linear combination", pageID: "1.3 - 01"),
        ZTGlossaryEntry(term: "Mersenne number", pageID: "3.1 - Mersenne, Fermat"),
        ZTGlossaryEntry(term: "Miller-Rabin test", pageID: "3.3 - 01"),
        ZTGlossaryEntry(term: "modulus", pageID: "2.1 - Kongruenz"),
        ZTGlossaryEntry(term: "Montgomery multiplication", pageID: "2.2 - modulare Potenz"),
        ZTGlossaryEntry(term: "monoid", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "multiple", pageID: "1.1 - Teiler in Z"),
        ZTGlossaryEntry(term: "multiples set", pageID: "1.4 - 01"),
        ZTGlossaryEntry(term: "multiplication of residue classes", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "neutral element", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Number Field Sieve", pageID: "5.5 - 01"),
        ZTGlossaryEntry(term: "one-element", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "one-way function", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "order of an element", pageID: "2.3 - ord(a)"),
        ZTGlossaryEntry(term: "order of an element, computing", pageID: "2.3 - ord(a) berechnen"),
        ZTGlossaryEntry(term: "order of a group", pageID: "2.3 - |G|"),
        ZTGlossaryEntry(term: "order of a witness", pageID: "3.2 - Zeugen Staffel"),
        ZTGlossaryEntry(term: "plain text", pageID: "4.1 - 01"),
        ZTGlossaryEntry(term: "Pollard, p–1 factorization", pageID: "5.4 - 01"),
        ZTGlossaryEntry(term: "Pollard, Rho: factorization", pageID: "5.3 - 01"),
        ZTGlossaryEntry(term: "Pollard, Rho: discrete logarithm", pageID: "6.3 - 01"),
        ZTGlossaryEntry(term: "polynomial", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "polynomial, root", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "positive generation", pageID: "2.3 - pos Erz"),
        ZTGlossaryEntry(term: "powers and associativity", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "powers in a group", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "prime", pageID: "1.1 - Def ggT"),
        ZTGlossaryEntry(term: "prime residue class", pageID: "2.2 - Zm*"),
        ZTGlossaryEntry(term: "prime residue classes, group of", pageID: "2.2 - Zm*"),
        ZTGlossaryEntry(term: "prime factor", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "prime decomposition", pageID: "1.2 - Fundamentalsatz"),
        ZTGlossaryEntry(term: "prime divisor", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "prime number", pageID: "1.2 - 01"),
        ZTGlossaryEntry(term: "prime number theorem", pageID: "3.1 - 01"),
        ZTGlossaryEntry(term: "prime number test", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "primitive residue class", pageID: "2.4 - 01"),
        ZTGlossaryEntry(term: "primitive root", pageID: "2.4 - 01"),
        ZTGlossaryEntry(term: "primitive root, computing", pageID: "2.4 - finden"),
        ZTGlossaryEntry(term: "private key", pageID: "4.1 - asym"),
        ZTGlossaryEntry(term: "probabilistic test", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "pseudo prime", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "pseudo prime, strong", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "public key", pageID: "4.1 - asym"),
        ZTGlossaryEntry(term: "quadratic residue", pageID: "5.2 - Quadrate erkennen"),
        ZTGlossaryEntry(term: "Quadratic Sieve factorization", pageID: "5.5 - 01"),
        ZTGlossaryEntry(term: "Rabin cipher", pageID: "4.3 - 01"),
        ZTGlossaryEntry(term: "reduction mod m", pageID: "2.1 - Standardvertreter"),
        ZTGlossaryEntry(term: "regular", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "remainder", pageID: "2.1 - Division mit Rest"),
        ZTGlossaryEntry(term: "representative", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "residue class", pageID: "2.1 - Restklassen"),
        ZTGlossaryEntry(term: "residue classes, set of all", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "residue class ring", pageID: "2.1 - Restklassenring"),
        ZTGlossaryEntry(term: "ring", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "root of a polynomial", pageID: "2.4 - Polynome"),
        ZTGlossaryEntry(term: "RSA cipher", pageID: "4.2 - 01"),
        ZTGlossaryEntry(term: "semigroup", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "simultaneous clock setting", pageID: "2.2 - Uhren verstellen"),
        ZTGlossaryEntry(term: "simultaneous congruence", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "solving congruences", pageID: "2.2 - Kongruenzen lösen"),
        ZTGlossaryEntry(term: "square & multiply", pageID: "2.2 - schnelle Potenz"),
        ZTGlossaryEntry(term: "subgroup", pageID: "2.3 - |G|"),
        ZTGlossaryEntry(term: "surjective", pageID: "2.2 - Chinesischer Restsatz"),
        ZTGlossaryEntry(term: "standard representative", pageID: "2.1 - Standardvertreter"),
        ZTGlossaryEntry(term: "text as number", pageID: "4.1 - Text -> Zahl"),
        ZTGlossaryEntry(term: "transversal sums", pageID: "2.1 - Quersummen"),
        ZTGlossaryEntry(term: "trapdoor function", pageID: "4.2 - trapdoor"),
        ZTGlossaryEntry(term: "trial division", pageID: "3.1 - Tests"),
        ZTGlossaryEntry(term: "triangle numbers", pageID: "2.1 - Wozu mod"),
        ZTGlossaryEntry(term: "unit", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "unity group", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "Vigenère cipher", pageID: "4.1 - Häuf"),
        ZTGlossaryEntry(term: "well-defined", pageID: "2.1 - Summe, Produkt"),
        ZTGlossaryEntry(term: "witness", pageID: "3.2 - 01"),
        ZTGlossaryEntry(term: "witness, strong", pageID: "3.3 - stark pseudo"),
        ZTGlossaryEntry(term: "zero divisor", pageID: "2.1 - 01"),
        ZTGlossaryEntry(term: "zero-element", pageID: "2.1 - 01"),
    ]
}
