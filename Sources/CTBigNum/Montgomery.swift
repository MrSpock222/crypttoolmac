import Foundation

/// Montgomery arithmetic modulo an odd modulus n > 1, with a small register file of residues.
///
/// Not thread safe (uses internal scratch space) – create one context per task.
final class MontgomeryContext {
    typealias Ptr = UnsafeMutablePointer<UInt64>
    typealias CPtr = UnsafePointer<UInt64>

    let s: Int
    let modulus: BigUInt
    let n: Ptr
    let nInv: UInt64
    private let t: Ptr
    let rSquared: Ptr
    let oneR: Ptr
    let regs: Ptr
    let regCount: Int

    init(modulus: BigUInt, registers: Int = 0) {
        precondition(modulus.isOdd && modulus > 1, "Montgomery: Modul muss ungerade und > 1 sein")
        self.modulus = modulus
        s = modulus.limbs.count
        n = Ptr.allocate(capacity: s)
        n.initialize(from: modulus.limbs, count: s)
        // -n^-1 mod 2^64 via Newton iteration
        let n0 = modulus.limbs[0]
        var inv: UInt64 = 1
        for _ in 0..<7 { inv = inv &* (2 &- n0 &* inv) }
        nInv = 0 &- inv
        t = Ptr.allocate(capacity: s + 2)
        t.initialize(repeating: 0, count: s + 2)
        rSquared = Ptr.allocate(capacity: s)
        oneR = Ptr.allocate(capacity: s)
        let r2 = (BigUInt(1) << (128 * s)) % modulus
        let r1 = (BigUInt(1) << (64 * s)) % modulus
        MontgomeryContext.store(r2, into: rSquared, s)
        MontgomeryContext.store(r1, into: oneR, s)
        regCount = registers
        regs = Ptr.allocate(capacity: max(1, registers * s))
        regs.initialize(repeating: 0, count: max(1, registers * s))
    }

    deinit {
        n.deallocate()
        t.deallocate()
        rSquared.deallocate()
        oneR.deallocate()
        regs.deallocate()
    }

    @inline(__always)
    static func store(_ x: BigUInt, into p: Ptr, _ s: Int) {
        let c = x.limbs.count
        precondition(c <= s)
        for i in 0..<s { p[i] = i < c ? x.limbs[i] : 0 }
    }

    // MARK: Raw pointer operations (all operands s limbs, fully reduced)

    /// r = a * b * R^-1 mod n. r may alias a and/or b.
    @inline(__always)
    func mulRaw(_ r: Ptr, _ a: CPtr, _ b: CPtr) {
        MontgomeryContext.montMul(r, a, b, n, t, s, nInv)
    }

    /// Montgomery product with fused multiply/reduce loop (FIOS). Kept as a static, non-inlined
    /// function on plain pointers: this lets the optimiser produce a tight loop (≈4× faster than
    /// the same code as an inlined instance method).
    @inline(never)
    static func montMul(_ r: Ptr, _ a: CPtr, _ b: CPtr, _ n: CPtr, _ t: Ptr, _ s: Int, _ nInv: UInt64) {
        for k in 0..<(s + 2) { t[k] = 0 }
        for i in 0..<s {
            let bi = b[i]
            let (ph0, pl0) = a[0].multipliedFullWidth(by: bi)
            let (x0, ox) = pl0.addingReportingOverflow(t[0])
            var c1 = ph0 &+ (ox ? 1 : 0)
            let m = x0 &* nInv
            let (qh0, ql0) = m.multipliedFullWidth(by: n[0])
            let (_, oy) = ql0.addingReportingOverflow(x0)
            var c2 = qh0 &+ (oy ? 1 : 0)
            var j = 1
            while j < s {
                let (ph, pl) = a[j].multipliedFullWidth(by: bi)
                let (x1, o1) = pl.addingReportingOverflow(t[j])
                let (x2, o2) = x1.addingReportingOverflow(c1)
                c1 = ph &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
                let (qh, ql) = m.multipliedFullWidth(by: n[j])
                let (y1, o3) = ql.addingReportingOverflow(x2)
                let (y2, o4) = y1.addingReportingOverflow(c2)
                c2 = qh &+ (o3 ? 1 : 0) &+ (o4 ? 1 : 0)
                t[j - 1] = y2
                j += 1
            }
            let (z1, o5) = t[s].addingReportingOverflow(c1)
            let (z2, o6) = z1.addingReportingOverflow(c2)
            t[s - 1] = z2
            t[s] = t[s + 1] &+ (o5 ? 1 : 0) &+ (o6 ? 1 : 0)
            t[s + 1] = 0
        }
        if t[s] != 0 || Limbs.compare(t, n, s) >= 0 {
            Limbs.subInPlace(t, s + 1, n, s)
        }
        for k in 0..<s { r[k] = t[k] }
    }

    /// r = a + b mod n
    @inline(__always)
    func addRaw(_ r: Ptr, _ a: CPtr, _ b: CPtr) {
        let s = self.s
        var carry: UInt64 = 0
        for i in 0..<s {
            let (s1, o1) = a[i].addingReportingOverflow(b[i])
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[i] = s2
            carry = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
        }
        if carry != 0 || Limbs.compare(r, n, s) >= 0 {
            Limbs.subInPlace(r, s, n, s)
        }
    }

    /// r = a - b mod n
    @inline(__always)
    func subRaw(_ r: Ptr, _ a: CPtr, _ b: CPtr) {
        let s = self.s
        var borrow: UInt64 = 0
        for i in 0..<s {
            let (s1, o1) = a[i].subtractingReportingOverflow(b[i])
            let (s2, o2) = s1.subtractingReportingOverflow(borrow)
            r[i] = s2
            borrow = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
        }
        if borrow != 0 {
            Limbs.addInPlace(r, s, n, s)
        }
    }

    /// r = a / 2 mod n (n odd). Works in Montgomery form as well (division by 2 is linear).
    @inline(__always)
    func halfRaw(_ r: Ptr, _ a: CPtr) {
        let s = self.s
        if a[0] & 1 == 0 {
            for i in 0..<s {
                r[i] = (a[i] >> 1) | (i + 1 < s ? a[i + 1] << 63 : 0)
            }
        } else {
            // (a + n) / 2 with the carry bit shifted in on top
            var carry: UInt64 = 0
            for i in 0..<s {
                let (s1, o1) = a[i].addingReportingOverflow(n[i])
                let (s2, o2) = s1.addingReportingOverflow(carry)
                r[i] = s2
                carry = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            }
            for i in 0..<s {
                r[i] = (r[i] >> 1) | (i + 1 < s ? r[i + 1] << 63 : carry << 63)
            }
        }
    }

    // MARK: Register operations

    @inline(__always) func reg(_ i: Int) -> Ptr { regs + i * s }

    @inline(__always) func mul(_ d: Int, _ a: Int, _ b: Int) { mulRaw(reg(d), reg(a), reg(b)) }
    @inline(__always) func sqr(_ d: Int, _ a: Int) { mulRaw(reg(d), reg(a), reg(a)) }
    @inline(__always) func add(_ d: Int, _ a: Int, _ b: Int) { addRaw(reg(d), reg(a), reg(b)) }
    @inline(__always) func sub(_ d: Int, _ a: Int, _ b: Int) { subRaw(reg(d), reg(a), reg(b)) }
    @inline(__always) func half(_ d: Int, _ a: Int) { halfRaw(reg(d), reg(a)) }

    @inline(__always) func copy(_ d: Int, _ a: Int) {
        if d != a { reg(d).update(from: reg(a), count: s) }
    }

    /// Register d = Montgomery form of (x mod n).
    func set(_ d: Int, _ x: BigUInt) {
        let v = x < modulus ? x : x % modulus
        let p = reg(d)
        MontgomeryContext.store(v, into: p, s)
        mulRaw(p, p, rSquared)
    }

    /// Register d = Montgomery form of 1.
    func setOne(_ d: Int) { reg(d).update(from: oneR, count: s) }

    /// Register d = 0.
    func setZero(_ d: Int) { reg(d).update(repeating: 0, count: s) }

    /// Converts register i back to a normal residue.
    func get(_ i: Int) -> BigUInt {
        let tmp = Ptr.allocate(capacity: s)
        defer { tmp.deallocate() }
        tmp.update(repeating: 0, count: s)
        tmp[0] = 1
        mulRaw(tmp, reg(i), tmp)
        return BigUInt(limbs: Array(UnsafeBufferPointer(start: tmp, count: s)))
    }

    /// The raw register contents (x·R mod n). gcd(raw, n) == gcd(x, n) since R is coprime to n.
    func raw(_ i: Int) -> BigUInt {
        BigUInt(limbs: Array(UnsafeBufferPointer(start: reg(i), count: s)))
    }

    func isZero(_ i: Int) -> Bool {
        let p = reg(i)
        for k in 0..<s where p[k] != 0 { return false }
        return true
    }

    func equal(_ a: Int, _ b: Int) -> Bool { Limbs.compare(reg(a), reg(b), s) == 0 }

    func isOne(_ i: Int) -> Bool { Limbs.compare(reg(i), oneR, s) == 0 }

    /// d = a^e (registers). Uses a 4-bit fixed window; needs registers `tableBase` …
    /// `tableBase+15` as scratch (must not include d or a).
    func pow(_ d: Int, _ a: Int, _ e: BigUInt, tableBase: Int) {
        if e.isZero { setOne(d); return }
        let k = 4
        setOne(tableBase)
        copy(tableBase + 1, a)
        for i in 2..<16 { mul(tableBase + i, tableBase + i - 1, a) }
        let bl = e.bitLength
        var pos = ((bl + k - 1) / k) * k
        var first = true
        while pos > 0 {
            pos -= k
            var w = 0
            for b in stride(from: pos + k - 1, through: pos, by: -1) {
                w = (w << 1) | (e.bit(at: b) ? 1 : 0)
            }
            if first {
                if w == 0 { continue }
                copy(d, tableBase + w)
                first = false
            } else {
                for _ in 0..<k { sqr(d, d) }
                if w != 0 { mul(d, d, tableBase + w) }
            }
        }
    }
}

// MARK: - Modular exponentiation

extension BigUInt {
    /// Modular exponentiation `self^e mod modulus` (modulus > 0).
    ///
    /// Odd moduli use Montgomery multiplication with a sliding-free fixed window, single word
    /// moduli use native 128-bit arithmetic, even moduli fall back to Knuth-D reduction.
    public func power(_ e: BigUInt, modulus m: BigUInt) -> BigUInt {
        precondition(!m.isZero, "Modul darf nicht null sein")
        if m.isOne { return BigUInt() }
        if e.isZero { return 1 }
        let base = self < m ? self : self % m
        if base.isZero { return BigUInt() }
        if let mm = m.uint64Value {
            return BigUInt(BigUInt.powMod64(base.limbs[0], e, mm))
        }
        if m.isOdd {
            return BigUInt.montgomeryPower(base, e, m)
        }
        // even modulus: plain left-to-right binary method with 4-bit window
        var table = [BigUInt](repeating: 1, count: 16)
        for i in 1..<16 { table[i] = (table[i - 1] * base) % m }
        var result = BigUInt(1)
        let bl = e.bitLength
        var pos = ((bl + 3) / 4) * 4
        while pos > 0 {
            pos -= 4
            var w = 0
            for b in stride(from: pos + 3, through: pos, by: -1) { w = (w << 1) | (e.bit(at: b) ? 1 : 0) }
            if !result.isOne {
                for _ in 0..<4 { result = result.squared() % m }
            }
            if w != 0 { result = (result * table[w]) % m }
        }
        return result
    }

    /// Modular exponentiation with an `Int` exponent.
    public func power(_ e: Int, modulus m: BigUInt) -> BigUInt {
        precondition(e >= 0)
        return power(BigUInt(e), modulus: m)
    }

    static func montgomeryPower(_ base: BigUInt, _ e: BigUInt, _ m: BigUInt) -> BigUInt {
        let bl = e.bitLength
        let k: Int
        switch bl {
        case ..<24: k = 2
        case ..<80: k = 3
        case ..<240: k = 4
        case ..<700: k = 5
        default: k = 6
        }
        let tsize = 1 << k
        // registers: 0 = result, 1 = base, 2... = table
        let ctx = MontgomeryContext(modulus: m, registers: tsize + 2)
        ctx.set(1, base)
        let tb = 2
        ctx.setOne(tb)
        ctx.copy(tb + 1, 1)
        if tsize > 2 { for i in 2..<tsize { ctx.mul(tb + i, tb + i - 1, 1) } }
        var pos = ((bl + k - 1) / k) * k
        var first = true
        while pos > 0 {
            pos -= k
            var w = 0
            for b in stride(from: pos + k - 1, through: pos, by: -1) { w = (w << 1) | (e.bit(at: b) ? 1 : 0) }
            if first {
                if w == 0 { continue }
                ctx.copy(0, tb + w)
                first = false
            } else {
                for _ in 0..<k { ctx.sqr(0, 0) }
                if w != 0 { ctx.mul(0, 0, tb + w) }
            }
        }
        return ctx.get(0)
    }

    /// (a * b) mod m for 64-bit values.
    @inline(__always)
    static func mulMod64(_ a: UInt64, _ b: UInt64, _ m: UInt64) -> UInt64 {
        let (hi, lo) = a.multipliedFullWidth(by: b)
        return m.dividingFullWidth((hi % m, lo)).remainder
    }

    /// a^e mod m for 64-bit a, m.
    static func powMod64(_ a: UInt64, _ e: BigUInt, _ m: UInt64) -> UInt64 {
        var result: UInt64 = 1 % m
        var base = a % m
        let bl = e.bitLength
        for i in 0..<bl {
            if e.bit(at: i) { result = mulMod64(result, base, m) }
            if i + 1 < bl { base = mulMod64(base, base, m) }
        }
        return result
    }

    /// a^e mod m for 64-bit values.
    static func powMod64(_ a: UInt64, _ e: UInt64, _ m: UInt64) -> UInt64 {
        var result: UInt64 = 1 % m
        var base = a % m
        var k = e
        while k > 0 {
            if k & 1 == 1 { result = mulMod64(result, base, m) }
            k >>= 1
            if k > 0 { base = mulMod64(base, base, m) }
        }
        return result
    }
}
