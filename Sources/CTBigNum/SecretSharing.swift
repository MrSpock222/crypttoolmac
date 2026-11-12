import Foundation
import CTCommon

// MARK: - Chinese remainder theorem

/// Chinese remainder theorem for arbitrary (also non-coprime) moduli.
public enum ChineseRemainder {
    /// Solves x ≡ remainders[i] (mod moduli[i]). Returns the smallest non-negative solution and
    /// the combined modulus lcm(moduli), or nil if the system is inconsistent, the arrays differ
    /// in length, are empty or contain a zero modulus.
    public static func solve(remainders: [BigUInt], moduli: [BigUInt]) -> (solution: BigUInt, modulus: BigUInt)? {
        guard remainders.count == moduli.count, !moduli.isEmpty else { return nil }
        guard !moduli.contains(where: { $0.isZero }) else { return nil }
        var x = remainders[0] % moduli[0]
        var m = moduli[0]
        for i in 1..<moduli.count {
            let mi = moduli[i]
            let ai = remainders[i] % mi
            let g = m.gcd(mi)
            // need x + m·t ≡ ai (mod mi)  ⇔  m·t ≡ ai − x (mod mi)
            let diff = BigInt(ai) - BigInt(x)
            let dm = diff.modulo(g)
            if !dm.isZero { return nil }
            let mig = mi / g
            let mg = m / g
            let rhs = (diff / BigInt(g)).modulo(mig)
            let t: BigUInt
            if mig.isOne {
                t = 0
            } else {
                guard let inv = (mg % mig).inverse(modulo: mig) else { return nil }
                t = (rhs * inv) % mig
            }
            x = x + m * t
            m = m * mig
            x = x % m
        }
        return (x, m)
    }
}

// MARK: - Shamir secret sharing

/// Shamir's (k, n) threshold scheme over GF(p).
public enum ShamirSecretSharing {
    /// One share (x, f(x)).
    public struct Share: Hashable, Codable, Sendable {
        public var x: BigUInt
        public var y: BigUInt
        public init(x: BigUInt, y: BigUInt) { self.x = x; self.y = y }
    }

    /// Splits `secret` into `shareCount` shares, any `threshold` of which reconstruct it.
    /// f(x) = secret + a1·x + … + a(k−1)·x^(k−1) mod prime; shares are (i, f(i)) for i = 1…n.
    /// `coefficients` (a1 … a(k−1)) are chosen randomly in 1…p−1 if nil.
    public static func split(secret: BigUInt, threshold: Int, shareCount: Int, prime: BigUInt,
                             coefficients: [BigUInt]? = nil) throws -> (shares: [Share], coefficients: [BigUInt]) {
        let xs = (1...max(1, shareCount)).map { BigUInt($0) }
        return try split(secret: secret, threshold: threshold, shareCount: shareCount, prime: prime,
                         coefficients: coefficients, xValues: xs)
    }

    /// Variant with explicit x values (CT1 uses random distinct public values).
    public static func split(secret: BigUInt, threshold: Int, shareCount: Int, prime: BigUInt,
                             coefficients: [BigUInt]?, xValues: [BigUInt]) throws -> (shares: [Share], coefficients: [BigUInt]) {
        guard threshold >= 1 else { throw CTError("Der Schwellenwert muss mindestens 1 sein.") }
        guard shareCount >= threshold else {
            throw CTError("Der Schwellenwert darf nicht größer als die Anzahl der Teilnehmer sein.")
        }
        guard Primality.isProbablePrime(prime) else { throw CTError("Der Modul \(prime) ist keine Primzahl.") }
        guard secret < prime else { throw CTError("Das Geheimnis muss kleiner als die Primzahl \(prime) sein.") }
        guard BigUInt(shareCount) < prime else {
            throw CTError("Die Primzahl muss größer als die Anzahl der Teilnehmer sein.")
        }
        guard xValues.count == shareCount else { throw CTError("Anzahl der x-Werte passt nicht zur Teilnehmerzahl.") }
        guard Set(xValues.map { $0 % prime }).count == shareCount, !xValues.contains(where: { ($0 % prime).isZero }) else {
            throw CTError("Die öffentlichen x-Werte müssen verschieden und ungleich 0 (mod p) sein.")
        }
        var coeffs: [BigUInt]
        if let c = coefficients {
            guard c.count == threshold - 1 else {
                throw CTError("Es werden genau \(threshold - 1) Koeffizienten benötigt.")
            }
            coeffs = c.map { $0 % prime }
        } else {
            coeffs = (0..<(threshold - 1)).map { _ in BigUInt.random(below: prime - 1) + 1 }
        }
        let shares = xValues.map { x in Share(x: x, y: evaluate(secret: secret, coefficients: coeffs, at: x, prime: prime)) }
        return (shares, coeffs)
    }

    /// f(x) mod p (Horner scheme).
    public static func evaluate(secret: BigUInt, coefficients: [BigUInt], at x: BigUInt, prime: BigUInt) -> BigUInt {
        var acc = BigUInt()
        for c in coefficients.reversed() { acc = (acc * x + c) % prime }
        return (acc * x + secret) % prime
    }

    /// Lagrange interpolation at x = 0. Uses all given shares (duplicate x values are ignored).
    public static func reconstruct(_ shares: [Share], prime: BigUInt) -> BigUInt {
        var seen = Set<BigUInt>()
        let pts = shares.filter { seen.insert($0.x % prime).inserted }
        var result = BigUInt()
        for (i, si) in pts.enumerated() {
            var num = BigUInt(1), den = BigUInt(1)
            for (j, sj) in pts.enumerated() where j != i {
                num = (num * (sj.x % prime)) % prime
                den = (den * (sj.x % prime).subtractedModulo(si.x % prime, prime)) % prime
            }
            guard let dinv = den.inverse(modulo: prime) else { continue }
            let li = (num * dinv) % prime
            result = (result + si.y * li) % prime
        }
        return result
    }

    /// Lagrange basis values l_i(0) for the given shares (for display of the computation).
    public static func lagrangeCoefficients(_ shares: [Share], prime: BigUInt) -> [BigUInt] {
        shares.enumerated().map { (i, si) in
            var num = BigUInt(1), den = BigUInt(1)
            for (j, sj) in shares.enumerated() where j != i {
                num = (num * (sj.x % prime)) % prime
                den = (den * (sj.x % prime).subtractedModulo(si.x % prime, prime)) % prime
            }
            return den.inverse(modulo: prime).map { (num * $0) % prime } ?? 0
        }
    }

    /// "f(x) = s + a1·x + a2·x^2 (mod p)" as in CT1's secret sharing dialog.
    public static func polynomialString(secret: BigUInt, coefficients: [BigUInt], prime: BigUInt) -> String {
        var s = "f(x) = \(secret)"
        for (i, c) in coefficients.enumerated() {
            s += " + \(c)·x"
            if i > 0 { s += "^\(i + 1)" }
        }
        return s + " (mod \(prime))"
    }
}

// MARK: - Secret sharing with the Chinese remainder theorem (CT1)

/// Secret sharing with the Chinese remainder theorem.
///
/// Two variants are offered:
///
/// * **Simple API** (`split(secret:shareCount:threshold:)` / `reconstruct(shares:moduli:)`):
///   Mignotte's threshold scheme. Pairwise coprime moduli m₁ < … < m_n are chosen around the
///   size of the secret such that the product of the k−1 largest moduli is smaller than the
///   secret and the product of the k smallest moduli is larger. Party i receives s mod m_i.
///   Any k shares give the secret directly by the CRT; fewer shares only give s mod P with
///   P < s, i.e. a wrong value. Requires a secret that is not too small (error otherwise).
///
/// * **CT1 variant** (`split(secret:shareCount:threshold:lowerBound:upperBound:)` → `Setup`,
///   `reconstruct(shares:moduli:w:)`), as in CT1's "Secret-Sharing mittels CRT"
///   (Asmuth–Bloom style): t random primes m₁ < … < m_t from [lowerBound, upperBound]
///   (default 2^108 … 2^109); min(k) = product of the k smallest, max(k−1) = product of the
///   k−1 largest moduli, w = ⌊min(k) / max(k−1)⌋. The secret s (0 ≤ s < w) is hidden in
///   s' = s + a·w with random a such that s' < min(k). Party i receives s' mod m_i. Any k
///   shares give s' by the CRT, hence s = s' mod w.
public enum CRTSecretSharing {
    /// CT1 default bounds for the random primes: 2^108 … 2^109.
    public static let defaultLowerBound = BigUInt(1) << 108
    public static let defaultUpperBound = BigUInt(1) << 109
    /// CT1 limits: 2…7 parties.
    public static let maxParties = 7

    /// All intermediate values of a CT1-style sharing (for the "Rechenweg" display and the log).
    public struct Setup: Hashable, Codable, Sendable {
        /// Moduli in ascending order.
        public var moduli: [BigUInt]
        /// Shares s' mod m_i.
        public var shares: [BigUInt]
        public var threshold: Int
        /// Product of the `threshold` smallest moduli.
        public var minK: BigUInt
        /// Product of the `threshold − 1` largest moduli.
        public var maxKMinus1: BigUInt
        /// w = ⌊min(k) / max(k−1)⌋ (at least 1); the secret must be smaller than w.
        public var w: BigUInt
        public var secret: BigUInt
        /// Random factor a.
        public var a: BigUInt
        /// s' = s + a·w
        public var sPrime: BigUInt
    }

    // MARK: Simple API (Mignotte)

    /// Mignotte threshold scheme: returns ascending prime moduli and the shares s mod m_i.
    /// Any `threshold` shares reconstruct the secret with `reconstruct(shares:moduli:)`.
    /// Throws if the parameters are invalid or the secret is too small for the chosen
    /// threshold/number of shares (it must exceed the product of k−1 distinct primes).
    public static func split(secret: BigUInt, shareCount: Int, threshold: Int) throws -> (moduli: [BigUInt], shares: [BigUInt]) {
        let m = try mignotteModuli(secret: secret, shareCount: shareCount, threshold: threshold)
        return (m, m.map { secret % $0 })
    }

    /// n consecutive primes ≥ start.
    static func consecutivePrimes(from start: BigUInt, count: Int) -> [BigUInt] {
        var out: [BigUInt] = []
        var p = start < 2 ? BigUInt(2) : (Primality.isProbablePrime(start) ? start : Primality.nextPrime(after: start))
        for _ in 0..<count {
            out.append(p)
            p = Primality.nextPrime(after: p)
        }
        return out
    }

    static func products(_ m: [BigUInt], threshold k: Int) -> (minK: BigUInt, maxK1: BigUInt) {
        var minK = BigUInt(1), maxK1 = BigUInt(1)
        for i in 0..<k { minK *= m[i] }
        if k > 1 { for i in (m.count - k + 1)..<m.count { maxK1 *= m[i] } }
        return (minK, maxK1)
    }

    /// Chooses moduli for Mignotte's scheme (randomised within the admissible range).
    static func mignotteModuli(secret s: BigUInt, shareCount n: Int, threshold k: Int) throws -> [BigUInt] {
        guard n >= 1, k >= 1, k <= n else {
            throw CTError("Der Schwellenwert k muss zwischen 1 und der Anzahl der Anteile n liegen.")
        }
        guard n <= 1000 else { throw CTError("Zu viele Anteile (höchstens 1000).") }
        if k == 1 {
            // every single share must determine the secret: all moduli > s
            let start = s + 1 + BigUInt.random(below: max(s, 1000))
            return consecutivePrimes(from: start, count: n)
        }
        // minK(B) and maxK1(B) grow with the start value B of the prime sequence
        func ok(_ B: BigUInt) -> (minOK: Bool, maxOK: Bool, moduli: [BigUInt]) {
            let m = consecutivePrimes(from: B, count: n)
            let (minK, maxK1) = products(m, threshold: k)
            return (minK > s, maxK1 < s, m)
        }
        // smallest B with minK(B) > s (binary search)
        var lo = BigUInt(2), hi = max(s.nthRoot(k) + 2, BigUInt(3))
        while !ok(hi).minOK { hi = hi << 1 }
        while lo < hi {
            let mid = (lo + hi) >> 1
            if ok(mid).minOK { hi = mid } else { lo = mid + 1 }
        }
        let bMin = lo
        guard ok(bMin).maxOK else {
            throw CTError("Das Geheimnis \(s) ist für k = \(k) und n = \(n) zu klein: das Produkt der k−1 größten Moduln wäre nicht kleiner als das Geheimnis. Bitte eine größere Zahl wählen.")
        }
        // largest B with maxK1(B) < s
        var lo2 = bMin, hi2 = s
        while lo2 < hi2 {
            let mid = (lo2 + hi2 + 1) >> 1
            if ok(mid).maxOK { lo2 = mid } else { hi2 = mid - 1 }
        }
        let bMax = lo2
        // random start in [bMin, bMax]; verify (prime gaps can make a random start fail)
        for _ in 0..<20 {
            let B = BigUInt.random(in: bMin...bMax)
            let r = ok(B)
            if r.minOK && r.maxOK { return r.moduli }
        }
        return ok(bMin).moduli
    }

    // MARK: CT1 variant

    /// Splits a secret (random secret 0 ≤ s < w if nil, as CT1 does) with random prime moduli in
    /// [lowerBound, upperBound].
    public static func split(secret: BigUInt?, shareCount: Int, threshold: Int,
                             lowerBound: BigUInt, upperBound: BigUInt) throws -> Setup {
        guard shareCount >= 2 else { throw CTError("Es werden mindestens 2 Teilnehmer benötigt.") }
        guard threshold >= 2, threshold <= shareCount else {
            throw CTError("Die Anzahl der zur Rekonstruktion nötigen Teilnehmer muss zwischen 2 und \(shareCount) liegen.")
        }
        guard lowerBound < upperBound else { throw CTError("Die untere Grenze muss kleiner als die obere Grenze sein.") }
        var primes = Set<BigUInt>()
        var attempts = 0
        while primes.count < shareCount {
            attempts += 1
            if attempts > 50 * shareCount {
                throw CTError("Im angegebenen Bereich konnten nicht genügend verschiedene Primzahlen gefunden werden.")
            }
            if let p = Primality.randomPrime(in: lowerBound...upperBound) { primes.insert(p) } else {
                throw CTError("Im angegebenen Bereich liegt keine Primzahl.")
            }
        }
        return try split(secret: secret, moduli: Array(primes), threshold: threshold)
    }

    /// Splits a secret with the given (pairwise coprime) moduli ("manuelle Eingabe" in CT1).
    public static func split(secret: BigUInt?, moduli: [BigUInt], threshold: Int) throws -> Setup {
        let m = moduli.sorted()
        let t = m.count
        guard t >= 2, threshold >= 1, threshold <= t else {
            throw CTError("Ungültige Anzahl von Moduln oder ungültiger Schwellenwert.")
        }
        for i in 0..<t {
            guard m[i] > 1 else { throw CTError("Die Moduln müssen größer als 1 sein.") }
            for j in (i + 1)..<t where !m[i].gcd(m[j]).isOne {
                throw CTError("Die Moduln \(m[i]) und \(m[j]) sind nicht teilerfremd.")
            }
        }
        var minK = BigUInt(1)
        for i in 0..<threshold { minK *= m[i] }
        var maxK1 = BigUInt(1)
        if threshold > 1 { for i in (t - threshold + 1)..<t { maxK1 *= m[i] } }
        var w = minK / maxK1
        if w.isZero { w = 1 }
        let s: BigUInt
        if let given = secret {
            guard given < w else {
                throw CTError("Das Geheimnis muss kleiner als w = \(w) sein (w = ⌊min(k)/max(k−1)⌋).")
            }
            s = given
        } else {
            s = BigUInt.random(below: w)
        }
        // a random with s + a·w < min(k)
        let aBound = (minK - s + w - 1) / w      // number of a with s + a·w < minK
        let a = aBound.isZero ? BigUInt() : BigUInt.random(below: aBound)
        let sPrime = s + a * w
        let shares = m.map { sPrime % $0 }
        return Setup(moduli: m, shares: shares, threshold: threshold, minK: minK, maxKMinus1: maxK1,
                     w: w, secret: s, a: a, sPrime: sPrime)
    }

    /// Combines shares by the CRT and returns the CRT solution (for the simple Mignotte API this
    /// is the secret). For the CT1 variant pass `w` to obtain s = s' mod w. Returns nil if the
    /// system is inconsistent.
    public static func reconstruct(shares: [BigUInt], moduli: [BigUInt], w: BigUInt? = nil) -> BigUInt? {
        guard let (x, _) = ChineseRemainder.solve(remainders: shares, moduli: moduli) else { return nil }
        if let w = w, !w.isZero { return x % w }
        return x
    }

    /// Number of candidates for s' that remain when only the given moduli are known
    /// (min(k) / ∏ used moduli, rounded up) – 1 means the secret is determined.
    public static func remainingCandidates(usedModuli: [BigUInt], setup: Setup) -> BigUInt {
        var prod = BigUInt(1)
        for m in usedModuli { prod *= m }
        if prod >= setup.minK { return 1 }
        return (setup.minK + prod - 1) / prod
    }
}

// MARK: - Diffie-Hellman

/// Diffie–Hellman key exchange in Z_p^* (CT1 "Diffie-Hellman-Demo").
public enum DiffieHellman {
    /// Generates a safe prime p = 2q + 1 with `bits` bits and a random generator g of Z_p^*.
    public static func generateParameters(bits: Int) -> (prime: BigUInt, generator: BigUInt) {
        let p = Primality.randomSafePrime(bits: max(bits, 5))
        return (p, randomGenerator(safePrime: p))
    }

    /// A random generator of Z_p^* for a safe prime p (g² ≠ 1 and g^q ≠ 1 mod p).
    public static func randomGenerator(safePrime p: BigUInt) -> BigUInt {
        while true {
            let g = BigUInt.random(below: p - 3) + 2
            if isGenerator(g, safePrime: p) { return g }
        }
    }

    /// CT1's generator check for a safe prime p = 2q + 1: 1 < g < p, g² ≢ 1 and g^q ≢ 1 (mod p).
    public static func isGenerator(_ g: BigUInt, safePrime p: BigUInt) -> Bool {
        guard g > 1, g < p else { return false }
        let q = (p - 1) / 2
        if ((g * g) % p).isOne { return false }
        if g.power(q, modulus: p).isOne { return false }
        return true
    }

    /// Random secret exponent 2 ≤ a ≤ p − 2.
    public static func randomSecret(prime p: BigUInt) -> BigUInt {
        p > 4 ? BigUInt.random(below: p - 3) + 2 : 1
    }

    /// Public value g^secret mod p.
    public static func publicValue(secret: BigUInt, generator: BigUInt, prime: BigUInt) -> BigUInt {
        generator.power(secret, modulus: prime)
    }

    /// Shared key (other public value)^secret mod p.
    public static func sharedKey(otherPublic: BigUInt, secret: BigUInt, prime: BigUInt) -> BigUInt {
        otherPublic.power(secret, modulus: prime)
    }
}

// MARK: - DSA

/// DSA domain parameters (FIPS 186 style).
public struct DSAParameters: Codable, Hashable, Sendable {
    public var p: BigUInt
    public var q: BigUInt
    public var g: BigUInt
    public init(p: BigUInt, q: BigUInt, g: BigUInt) { self.p = p; self.q = q; self.g = g }
}

/// DSA key pair (x private, y = g^x mod p public).
public struct DSAKeyPair: Codable, Hashable, Sendable {
    public var parameters: DSAParameters
    public var x: BigUInt
    public var y: BigUInt
    public init(parameters: DSAParameters, x: BigUInt) {
        self.parameters = parameters
        self.x = x
        self.y = parameters.g.power(x, modulus: parameters.p)
    }
}

/// Digital Signature Algorithm (hash values are truncated to the bit length of q).
public enum DSA {
    /// Generates domain parameters with |p| = L and |q| = N bits (e.g. 1024/160, 2048/256).
    public static func generateParameters(L: Int, N: Int) -> DSAParameters {
        precondition(L > N + 1 && N >= 8)
        let q = Primality.randomPrime(bits: N)
        let twoQ = 2 * q
        while true {
            let X = BigUInt.random(bits: L, exact: true)
            let c = X % twoQ
            let p = X - c + 1
            if p.bitLength != L { continue }
            if Primality.fastProbablePrime(p) {
                var h = BigUInt(2)
                while true {
                    let g = h.power((p - 1) / q, modulus: p)
                    if g > 1 { return DSAParameters(p: p, q: q, g: g) }
                    h += 1
                }
            }
        }
    }

    /// Random key pair for the given parameters.
    public static func generateKey(parameters: DSAParameters) -> DSAKeyPair {
        DSAKeyPair(parameters: parameters, x: BigUInt.random(below: parameters.q - 1) + 1)
    }

    static func hashToInteger(_ hash: [UInt8], bits: Int) -> BigUInt {
        let h = BigUInt(bigEndianBytes: hash)
        let hb = hash.count * 8
        return hb > bits ? h >> (hb - bits) : h
    }

    /// Signs a hash value; returns (r, s).
    public static func sign(hash: [UInt8], key: DSAKeyPair) -> (r: BigUInt, s: BigUInt) {
        let pr = key.parameters
        let z = hashToInteger(hash, bits: pr.q.bitLength)
        while true {
            let k = BigUInt.random(below: pr.q - 1) + 1
            let r = pr.g.power(k, modulus: pr.p) % pr.q
            if r.isZero { continue }
            guard let kinv = k.inverse(modulo: pr.q) else { continue }
            let s = (kinv * ((z + key.x * r) % pr.q)) % pr.q
            if s.isZero { continue }
            return (r, s)
        }
    }

    /// Verifies a signature (r, s) for a hash value with the public value y.
    public static func verify(hash: [UInt8], r: BigUInt, s: BigUInt, parameters pr: DSAParameters, publicKey y: BigUInt) -> Bool {
        guard r > 0, r < pr.q, s > 0, s < pr.q else { return false }
        guard let w = s.inverse(modulo: pr.q) else { return false }
        let z = hashToInteger(hash, bits: pr.q.bitLength)
        let u1 = (z * w) % pr.q
        let u2 = (r * w) % pr.q
        let v = ((pr.g.power(u1, modulus: pr.p) * y.power(u2, modulus: pr.p)) % pr.p) % pr.q
        return v == r
    }
}
