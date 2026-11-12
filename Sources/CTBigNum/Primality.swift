import Foundation
import CTCommon

/// Primality test methods offered by CT1 ("Primzahltest").
public enum PrimeTestMethod: String, CaseIterable, Codable, Sendable {
    case millerRabin, solovayStrassen, fermat, aks, trialDivision

    /// German display name.
    public var displayName: String {
        switch self {
        case .millerRabin: return "Miller-Rabin"
        case .solovayStrassen: return "Solovay-Strassen"
        case .fermat: return "Fermat"
        case .aks: return "AKS"
        case .trialDivision: return "Probedivision"
        }
    }

    /// True for the randomised (probabilistic) tests.
    public var isProbabilistic: Bool {
        switch self {
        case .millerRabin, .solovayStrassen, .fermat: return true
        case .aks, .trialDivision: return false
        }
    }
}

/// Primality tests and prime generation.
public enum Primality {

    // MARK: Small primes

    /// Sieve of Eratosthenes: all primes <= limit.
    public static func sieve(upTo limit: Int) -> [Int] {
        if limit < 2 { return [] }
        var composite = [Bool](repeating: false, count: limit + 1)
        var primes: [Int] = []
        primes.reserveCapacity(Int(Double(limit) / max(1, log(Double(limit)) - 1.1)) + 10)
        var i = 2
        while i <= limit {
            if !composite[i] {
                primes.append(i)
                if i <= limit / i {
                    var j = i * i
                    while j <= limit { composite[j] = true; j += i }
                }
            }
            i += 1
        }
        return primes
    }

    /// All primes below 2^16 (6542 primes).
    static let smallPrimes: [UInt64] = sieve(upTo: 65535).map { UInt64($0) }

    /// Groups of small primes whose product fits into 64 bits, for fast trial division:
    /// (product, index range in `smallPrimes`).
    static let primeProducts: [(UInt64, Range<Int>)] = {
        var out: [(UInt64, Range<Int>)] = []
        var i = 1 // skip 2
        while i < smallPrimes.count {
            var prod: UInt64 = 1
            let start = i
            while i < smallPrimes.count {
                let (p, o) = prod.multipliedReportingOverflow(by: smallPrimes[i])
                if o { break }
                prod = p
                i += 1
            }
            out.append((prod, start..<i))
        }
        return out
    }()

    /// Returns a prime factor p <= limit (limit < 2^16 effective) of n, or nil.
    /// n itself is returned if n is a small prime.
    static func smallFactor(_ n: BigUInt, limit: UInt64 = 65535) -> UInt64? {
        if n.isZero { return nil }
        if n.isEven { return 2 }
        for (prod, range) in primeProducts {
            if smallPrimes[range.lowerBound] > limit { break }
            let r = n.remainder(dividingBy: prod)
            for idx in range {
                let p = smallPrimes[idx]
                if p > limit { break }
                if r % p == 0 { return p }
            }
        }
        return nil
    }

    // MARK: Public entry points

    /// Largest n + 1 supported by the AKS implementation (2^62).
    public static let aksLimit = BigUInt(1) << 62

    /// Tests `n` with the chosen method. For the probabilistic methods `rounds` random bases are
    /// used. Returns false if the operation was cancelled (check `cancel?.isCancelled`).
    /// AKS is only practical for small n (≈0.25 s for n ≈ 10^6, ≈5 s for n ≈ 2^31) and returns
    /// false for n ≥ `aksLimit` – use `aks(_:)` to distinguish "not supported" (nil).
    /// Trial division is practical up to ~2^64 and runs until cancelled for larger n.
    public static func test(_ n: BigUInt, method: PrimeTestMethod, rounds: Int = 40,
                            cancel: CancellationToken? = nil) -> Bool {
        switch method {
        case .millerRabin: return millerRabin(n, rounds: rounds, cancel: cancel)
        case .solovayStrassen: return solovayStrassen(n, rounds: rounds, cancel: cancel)
        case .fermat: return fermat(n, rounds: rounds, cancel: cancel)
        case .aks: return aks(n, cancel: cancel) ?? false
        case .trialDivision: return trialDivision(n, cancel: cancel) ?? false
        }
    }

    /// Strong probable prime test with Baillie-PSW (Miller-Rabin base 2 + strong Lucas test)
    /// plus two random Miller-Rabin bases. Deterministic for n < 2^64.
    public static func isProbablePrime(_ n: BigUInt) -> Bool {
        if let v = n.uint64Value { return isPrime64(v) }
        if let f = smallFactor(n, limit: 1000) { return BigUInt(f) == n }
        let ctx = MontgomeryContext(modulus: n, registers: 24)
        let nm1 = n - 1
        let s = nm1.trailingZeroBitCount
        let d = nm1 >> s
        ctx.set(3, nm1)
        if !mrRound(ctx, d: d, s: s, base: 2) { return false }
        if !strongLucas(n) { return false }
        for _ in 0..<2 {
            let a = BigUInt.random(below: n - 3) + 2
            if !mrRound(ctx, d: d, s: s, base: a) { return false }
        }
        return true
    }

    /// Deterministic primality test for 64-bit values (Miller-Rabin with 12 fixed bases).
    public static func isPrime64(_ n: UInt64) -> Bool {
        if n < 2 { return false }
        for p: UInt64 in [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37] {
            if n == p { return true }
            if n % p == 0 { return false }
        }
        if n < 1681 { return true } // 41^2
        let nm1 = n - 1
        let s = nm1.trailingZeroBitCount
        let d = nm1 >> UInt64(s)
        outer: for a: UInt64 in [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37] {
            var x = BigUInt.powMod64(a, d, n)
            if x == 1 || x == nm1 { continue }
            for _ in 1..<max(1, s) {
                x = BigUInt.mulMod64(x, x, n)
                if x == nm1 { continue outer }
                if x == 1 { return false }
            }
            return false
        }
        return true
    }

    // MARK: Miller-Rabin

    /// One strong-probable-prime round with base `base` (context register 3 must hold n-1).
    static func mrRound(_ ctx: MontgomeryContext, d: BigUInt, s: Int, base: BigUInt) -> Bool {
        ctx.set(1, base)
        if ctx.isZero(1) { return true }
        ctx.pow(0, 1, d, tableBase: 4)
        if ctx.isOne(0) || ctx.equal(0, 3) { return true }
        var i = 1
        while i < s {
            ctx.sqr(0, 0)
            if ctx.equal(0, 3) { return true }
            if ctx.isOne(0) { return false }
            i += 1
        }
        return false
    }

    /// Single Miller-Rabin round with a given base (n odd > 2); true = "n is a strong probable
    /// prime to base a".
    public static func isStrongProbablePrime(_ n: BigUInt, base a: BigUInt) -> Bool {
        if n < 2 { return false }
        if n == 2 || n == 3 { return true }
        if n.isEven { return false }
        let nm1 = n - 1
        let s = nm1.trailingZeroBitCount
        let d = nm1 >> s
        var x = a.power(d, modulus: n)
        if x.isOne || x == nm1 || x.isZero { return true }
        for _ in 1..<max(1, s) {
            x = (x * x) % n
            if x == nm1 { return true }
            if x.isOne { return false }
        }
        return false
    }

    /// Miller-Rabin test with `rounds` random bases.
    public static func millerRabin(_ n: BigUInt, rounds: Int = 40, cancel: CancellationToken? = nil) -> Bool {
        if n < 2 { return false }
        if n == 2 || n == 3 { return true }
        if n.isEven { return false }
        if n < 5 { return true }
        let nm1 = n - 1
        let s = nm1.trailingZeroBitCount
        let d = nm1 >> s
        if let v = n.uint64Value {
            let d64 = d.uint64Value!
            outer: for _ in 0..<max(1, rounds) {
                if cancel?.isCancelled == true { return false }
                let a = UInt64.random(in: 2...(v - 2))
                var x = BigUInt.powMod64(a, d64, v)
                if x == 1 || x == v - 1 { continue }
                for _ in 1..<max(1, s) {
                    x = BigUInt.mulMod64(x, x, v)
                    if x == v - 1 { continue outer }
                    if x == 1 { return false }
                }
                return false
            }
            return true
        }
        let ctx = MontgomeryContext(modulus: n, registers: 24)
        ctx.set(3, nm1)
        for _ in 0..<max(1, rounds) {
            if cancel?.isCancelled == true { return false }
            let a = BigUInt.random(below: n - 3) + 2
            if !mrRound(ctx, d: d, s: s, base: a) { return false }
        }
        return true
    }

    // MARK: Solovay-Strassen / Fermat

    /// Solovay-Strassen test with `rounds` random bases: a^((n-1)/2) ≡ (a/n) mod n.
    public static func solovayStrassen(_ n: BigUInt, rounds: Int = 40, cancel: CancellationToken? = nil) -> Bool {
        if n < 2 { return false }
        if n == 2 || n == 3 { return true }
        if n.isEven { return false }
        let nm1 = n - 1
        let e = nm1 >> 1
        for _ in 0..<max(1, rounds) {
            if cancel?.isCancelled == true { return false }
            let a = BigUInt.random(below: n - 3) + 2
            let j = a.jacobi(n)
            if j == 0 { return false }
            let x = a.power(e, modulus: n)
            if j == 1 ? !x.isOne : x != nm1 { return false }
        }
        return true
    }

    /// Fermat test with `rounds` random bases: a^(n-1) ≡ 1 mod n.
    public static func fermat(_ n: BigUInt, rounds: Int = 40, cancel: CancellationToken? = nil) -> Bool {
        if n < 2 { return false }
        if n == 2 || n == 3 { return true }
        if n.isEven { return false }
        let nm1 = n - 1
        for _ in 0..<max(1, rounds) {
            if cancel?.isCancelled == true { return false }
            let a = BigUInt.random(below: n - 3) + 2
            if !a.power(nm1, modulus: n).isOne { return false }
        }
        return true
    }

    // MARK: Strong Lucas test (Selfridge parameters)

    /// Strong Lucas probable prime test with Selfridge's method A parameters (n odd, > 2).
    static func strongLucas(_ n: BigUInt) -> Bool {
        if n.isPerfectSquare { return false }
        // find D in 5, -7, 9, -11, … with (D/n) = -1
        var dAbs: UInt64 = 5
        var dNeg = false
        var iterations = 0
        while true {
            let dd = BigUInt(dAbs)
            var j = dd.jacobi(n)
            if dNeg && j != 0 {
                // (-1/n) = 1 if n ≡ 1 mod 4 else -1
                if n.low64 & 3 == 3 { j = -j }
            }
            if j == -1 { break }
            if j == 0 && dd % n != 0 { return false } // D shares a factor with n
            dAbs += 2
            dNeg.toggle()
            iterations += 1
            if iterations > 1000 { return false }
        }
        // P = 1, Q = (1 - D) / 4
        let D: BigUInt = dNeg ? n - BigUInt(dAbs) % n : BigUInt(dAbs) % n
        // Q = (1 - D)/4 as signed integer: D = ±dAbs
        let qSigned: Int64 = dNeg ? Int64((1 + dAbs) / 4) : -Int64((dAbs - 1) / 4)
        let Q: BigUInt = qSigned >= 0 ? BigUInt(UInt64(qSigned)) % n : n - BigUInt(UInt64(-qSigned)) % n
        let np1 = n + 1
        let s = np1.trailingZeroBitCount
        let d = np1 >> s
        // registers: 0 U, 1 V, 2 Qk, 3 D, 4 Q, 5 tmp, 6 tmp2
        let ctx = MontgomeryContext(modulus: n, registers: 8)
        ctx.setOne(0)              // U_1 = 1
        ctx.setOne(1)              // V_1 = P = 1
        ctx.set(3, D)
        ctx.set(4, Q)
        ctx.copy(2, 4)             // Q^1
        let bl = d.bitLength
        var b = bl - 2
        while b >= 0 {
            // doubling: U2k = Uk*Vk, V2k = Vk^2 - 2Q^k, Q^2k = (Q^k)^2
            ctx.mul(0, 0, 1)
            ctx.sqr(1, 1)
            ctx.add(5, 2, 2)
            ctx.sub(1, 1, 5)
            ctx.sqr(2, 2)
            if d.bit(at: b) {
                // U_{2k+1} = (P*U + V)/2, V_{2k+1} = (D*U + P*V)/2, Q^{2k+1} = Q^{2k} * Q
                ctx.add(5, 0, 1)          // U + V
                ctx.mul(6, 3, 0)          // D*U
                ctx.add(6, 6, 1)          // D*U + V
                ctx.half(0, 5)
                ctx.half(1, 6)
                ctx.mul(2, 2, 4)
            }
            b -= 1
        }
        if ctx.isZero(0) || ctx.isZero(1) { return true }
        for _ in 1..<max(1, s) {
            // V_{2k} = V_k^2 - 2 Q^k
            ctx.sqr(1, 1)
            ctx.add(5, 2, 2)
            ctx.sub(1, 1, 5)
            if ctx.isZero(1) { return true }
            ctx.sqr(2, 2)
        }
        return false
    }

    // MARK: Trial division

    /// Deterministic primality by trial division. Returns nil if cancelled.
    /// Practical up to ~2^64 (worst case a few seconds); larger n only if they have a small factor.
    public static func trialDivision(_ n: BigUInt, cancel: CancellationToken? = nil) -> Bool? {
        if n < 2 { return false }
        guard let f = smallestFactor(n, cancel: cancel) else { return nil }
        return f == n
    }

    /// Smallest prime factor of n (n itself if n is prime) by trial division, nil if cancelled.
    public static func smallestFactor(_ n: BigUInt, cancel: CancellationToken? = nil,
                                      limit: BigUInt? = nil) -> BigUInt? {
        if n < 2 { return n }
        if let f = smallFactor(n) { return BigUInt(f) }
        let root = n.squareRoot()
        let bound = limit.map { min($0, root) } ?? root
        if bound < 65536 { return n }
        // wheel mod 30 starting at 65537
        let offsets: [UInt64] = [1, 7, 11, 13, 17, 19, 23, 29]
        var base: UInt64 = 65520 // multiple of 30
        let bound64 = bound.uint64Value ?? UInt64.max
        var counter = 0
        if let n64 = n.uint64Value {
            while base <= bound64 {
                for o in offsets {
                    let p = base + o
                    if p < 65536 { continue }
                    if p > bound64 { break }
                    if n64 % p == 0 { return BigUInt(p) }
                }
                base += 30
                counter += 1
                if counter & 0xFFFFF == 0, cancel?.isCancelled == true { return nil }
            }
            return n
        }
        while base <= bound64 {
            for o in offsets {
                let p = base + o
                if p < 65536 { continue }
                if p > bound64 { break }
                if n.remainder(dividingBy: p) == 0 { return BigUInt(p) }
            }
            base += 30
            counter += 1
            if counter & 0x3FFF == 0, cancel?.isCancelled == true { return nil }
            if base > UInt64.max - 60 { break }
        }
        if limit != nil && bound < root { return nil }
        return n
    }

    // MARK: Prime generation

    /// Next prime strictly greater than n.
    public static func nextPrime(after n: BigUInt) -> BigUInt {
        if n < 2 { return 2 }
        var c = n + 1
        if c.isEven { if c == 2 { return 2 }; c += 1 }
        if c.bitLength < 64 {
            var v = c.uint64Value!
            while !isPrime64(v) { v += 2 }
            return BigUInt(v)
        }
        return sieveSearch(start: c, maxSteps: Int.max, upper: nil, test: { isProbablePrime($0) })!
    }

    /// Largest prime strictly smaller than n, nil if none (n <= 2).
    public static func previousPrime(before n: BigUInt) -> BigUInt? {
        if n <= 2 { return nil }
        if n == 3 { return 2 }
        var c = n - 1
        if c.isEven { c -= 1 }
        while c >= 3 {
            if isProbablePrime(c) { return c }
            c -= 2
        }
        return 2
    }

    /// Incremental search from odd `start` (step 2) using a small-prime sieve. Returns the first
    /// candidate passing `test`, or nil if `upper` is exceeded / `maxSteps` reached.
    static func sieveSearch(start: BigUInt, maxSteps: Int, upper: BigUInt?, sieveLimit: Int = 2000,
                            extraCondition: ((UInt64, UInt64) -> Bool)? = nil,
                            test: (BigUInt) -> Bool) -> BigUInt? {
        precondition(start.isOdd)
        let primes = smallPrimes.prefix(while: { $0 < UInt64(sieveLimit) }).dropFirst() // odd primes
        let residues = primes.map { start.remainder(dividingBy: $0) }
        let primeArr = Array(primes)
        var offset: UInt64 = 0
        var steps = 0
        let startSmall = start.bitLength <= 20
        while steps < maxSteps {
            var ok = true
            for i in 0..<primeArr.count {
                let r = (residues[i] + offset) % primeArr[i]
                if r == 0 {
                    // divisible – unless the candidate is the prime itself
                    if startSmall, (start + BigUInt(offset)) == BigUInt(primeArr[i]) { continue }
                    ok = false
                    break
                }
                if let cond = extraCondition, !cond(r, primeArr[i]) { ok = false; break }
            }
            if ok {
                let c = start + BigUInt(offset)
                if let u = upper, c > u { return nil }
                if test(c) { return c }
            } else if let u = upper, offset & 0xFFF == 0, start + BigUInt(offset) > u {
                return nil
            }
            offset += 2
            steps += 1
            if offset > (1 << 40) {
                // re-base to keep offsets small
                let newStart = start + BigUInt(offset)
                return sieveSearch(start: newStart, maxSteps: maxSteps - steps, upper: upper,
                                   sieveLimit: sieveLimit, extraCondition: extraCondition, test: test)
            }
        }
        return nil
    }

    /// Random prime with exactly `bits` bits (bits >= 2).
    public static func randomPrime(bits: Int) -> BigUInt {
        precondition(bits >= 2, "Mindestens 2 Bit")
        return randomPrime(bits: bits, topTwoBits: false)
    }

    /// Random prime with exactly `bits` bits; with `topTwoBits` the two most significant bits are
    /// set (product of two such primes has exactly 2·bits bits – used for RSA).
    public static func randomPrime(bits: Int, topTwoBits: Bool) -> BigUInt {
        precondition(bits >= 2)
        if bits <= 16 {
            let lo = UInt64(1) << UInt64(bits - 1)
            let lo2 = topTwoBits && bits >= 2 ? lo | (lo >> 1) : lo
            let hi = (UInt64(1) << UInt64(bits)) - 1
            let candidates = smallPrimes.filter { $0 >= lo2 && $0 <= hi }
            if let p = candidates.randomElement() { return BigUInt(p) }
            return BigUInt(smallPrimes.first { $0 >= lo }!)
        }
        let upper = (BigUInt(1) << bits) - 1
        let sieveLimit = min(max(bits * 8, 500), 60000)
        while true {
            var c = BigUInt.random(bits: bits, exact: true).settingBit(0)
            if topTwoBits { c = c.settingBit(bits - 2) }
            if let p = sieveSearch(start: c, maxSteps: bits * 30, upper: upper, sieveLimit: sieveLimit,
                                   test: { fastProbablePrime($0) }) {
                return p
            }
        }
    }

    /// Probable prime test used during generation of random primes (candidates are random, so a
    /// few rounds give an error probability far below 2^-100): MR base 2 + rounds by size + Lucas.
    static func fastProbablePrime(_ n: BigUInt) -> Bool {
        if let v = n.uint64Value { return isPrime64(v) }
        let ctx = MontgomeryContext(modulus: n, registers: 24)
        let nm1 = n - 1
        let s = nm1.trailingZeroBitCount
        let d = nm1 >> s
        ctx.set(3, nm1)
        if !mrRound(ctx, d: d, s: s, base: 2) { return false }
        let bits = n.bitLength
        let rounds = bits >= 1024 ? 3 : bits >= 512 ? 5 : bits >= 256 ? 8 : 12
        for _ in 0..<rounds {
            let a = BigUInt.random(below: n - 3) + 2
            if !mrRound(ctx, d: d, s: s, base: a) { return false }
        }
        return strongLucas(n)
    }

    /// Random prime in the closed range, tested with `method` (40 rounds for probabilistic
    /// methods). Returns nil if the range contains no prime.
    public static func randomPrime(in range: ClosedRange<BigUInt>, method: PrimeTestMethod = .millerRabin) -> BigUInt? {
        let lo = max(range.lowerBound, 2)
        let hi = range.upperBound
        if lo > hi { return nil }
        let testFn: (BigUInt) -> Bool = { n in
            switch method {
            case .millerRabin: return n.bitLength <= 64 ? isPrime64(n.uint64Value!) : (fastProbablePrime(n) && millerRabin(n, rounds: 20))
            default: return test(n, method: method)
            }
        }
        let width = hi - lo + 1
        if width <= 20000 {
            // test the candidates in random order: the first prime is uniformly distributed
            var candidates: [BigUInt] = []
            var c = lo
            while c <= hi {
                if c == 2 || (c.isOdd && Primality.smallFactor(c, limit: 50).map({ BigUInt($0) == c }) ?? true) {
                    candidates.append(c)
                }
                c += 1
            }
            candidates.shuffle()
            return candidates.first(where: testFn)
        }
        // random odd start, search upwards, wrap around
        var start = BigUInt.random(in: lo...hi)
        if start.isEven { start += 1 }
        if start > hi { start = lo.isOdd ? lo : lo + 1 }
        if let p = sieveSearch(start: start, maxSteps: Int.max, upper: hi, test: testFn) { return p }
        let s2 = lo.isOdd ? lo : lo + 1
        if lo == 2 && hi >= 2 && start > 2 {
            // 2 is the only even prime
        }
        if let p = sieveSearch(start: s2, maxSteps: Int.max, upper: start, test: testFn) { return p }
        if lo <= 2 && hi >= 2 { return 2 }
        return nil
    }

    /// Random safe prime p = 2q + 1 (q prime) with exactly `bits` bits (bits >= 3).
    public static func randomSafePrime(bits: Int) -> BigUInt {
        precondition(bits >= 3)
        if bits <= 16 {
            let lo = UInt64(1) << UInt64(bits - 1), hi = (UInt64(1) << UInt64(bits)) - 1
            let c = smallPrimes.filter { $0 >= lo && $0 <= hi && isPrime64(($0 - 1) / 2) }
            if let p = c.randomElement() { return BigUInt(p) }
            return 7
        }
        let qbits = bits - 1
        let upper = (BigUInt(1) << qbits) - 1
        let sieveLimit = min(max(bits * 8, 500), 60000)
        while true {
            // q odd with q ≡ … such that neither q nor 2q+1 has a small factor
            let start = BigUInt.random(bits: qbits, exact: true).settingBit(0)
            let found = sieveSearch(start: start, maxSteps: bits * 200, upper: upper, sieveLimit: sieveLimit,
                                    extraCondition: { r, p in (2 * r + 1) % p != 0 },
                                    test: { q in
                                        let p = 2 * q + 1
                                        // cheap Fermat base 2 on p first, then q, then full tests
                                        if !BigUInt(2).power(p - 1, modulus: p).isOne { return false }
                                        return fastProbablePrime(q) && fastProbablePrime(p)
                                    })
            if let q = found { return 2 * q + 1 }
        }
    }

    /// Primes in the closed range in ascending order (at most `limit`).
    public static func primes(in range: ClosedRange<BigUInt>, limit: Int) -> [BigUInt] {
        var out: [BigUInt] = []
        if limit <= 0 { return out }
        let hi = range.upperBound
        // small ranges below 2^32: sieve segment
        if let hi64 = hi.uint64Value, hi64 < (1 << 32), let lo64 = range.lowerBound.uint64Value,
           hi64 - lo64 < 50_000_000 {
            let lo = max(lo64, 2)
            if lo > hi64 { return out }
            let root = Int(BigUInt.isqrt64(hi64)) + 1
            let basePrimes = sieve(upTo: root)
            let size = Int(hi64 - lo + 1)
            var composite = [Bool](repeating: false, count: size)
            for p in basePrimes {
                let pp = UInt64(p)
                var start = max(pp * pp, ((lo + pp - 1) / pp) * pp)
                while start <= hi64 {
                    composite[Int(start - lo)] = true
                    start += pp
                }
            }
            for i in 0..<size where !composite[i] {
                out.append(BigUInt(lo + UInt64(i)))
                if out.count >= limit { break }
            }
            return out
        }
        var c = range.lowerBound
        if isProbablePrime(c) { out.append(c) }
        while out.count < limit {
            c = nextPrime(after: c)
            if c > hi { break }
            out.append(c)
        }
        return out
    }

    /// Number of primes ≤ x (prime counting function π(x)) for moderate x (≤ ~10^9).
    public static func primeCount(upTo x: Int) -> Int {
        sieve(upTo: x).count
    }
}
