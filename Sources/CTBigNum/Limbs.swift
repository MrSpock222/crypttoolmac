import Foundation

/// Low level multi-precision routines on little-endian `UInt64` limb vectors.
///
/// All pointer based routines work on raw, *not necessarily normalised* limb ranges. The array
/// based helpers return normalised arrays (no leading zero limbs, zero = `[]`).
@usableFromInline
enum Limbs {
    typealias Ptr = UnsafeMutablePointer<UInt64>
    typealias CPtr = UnsafePointer<UInt64>

    static let karatsubaThreshold = 40

    // MARK: - Normalisation / comparison

    @inline(__always)
    static func normalize(_ a: inout [UInt64]) {
        while let last = a.last, last == 0 { a.removeLast() }
    }

    @inline(__always)
    static func normalizedCount(_ a: CPtr, _ n: Int) -> Int {
        var k = n
        while k > 0 && a[k - 1] == 0 { k -= 1 }
        return k
    }

    /// Compares two normalised limb arrays.
    static func compare(_ a: [UInt64], _ b: [UInt64]) -> Int {
        if a.count != b.count { return a.count < b.count ? -1 : 1 }
        var i = a.count - 1
        while i >= 0 {
            if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
            i -= 1
        }
        return 0
    }

    /// Compares raw ranges of equal length `n`.
    @inline(__always)
    static func compare(_ a: CPtr, _ b: CPtr, _ n: Int) -> Int {
        var i = n - 1
        while i >= 0 {
            if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
            i -= 1
        }
        return 0
    }

    // MARK: - In-place add / sub on pointers

    /// r[0..<nr] += a[0..<na] (na <= nr). Returns the carry out of r[nr-1].
    @discardableResult
    @inline(__always)
    static func addInPlace(_ r: Ptr, _ nr: Int, _ a: CPtr, _ na: Int) -> UInt64 {
        var carry: UInt64 = 0
        var i = 0
        while i < na {
            let (s1, o1) = r[i].addingReportingOverflow(a[i])
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[i] = s2
            carry = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            i += 1
        }
        while carry != 0 && i < nr {
            let (s, o) = r[i].addingReportingOverflow(carry)
            r[i] = s
            carry = o ? 1 : 0
            i += 1
        }
        return carry
    }

    /// r[0..<nr] -= a[0..<na] (na <= nr). Returns the borrow out of r[nr-1].
    @discardableResult
    @inline(__always)
    static func subInPlace(_ r: Ptr, _ nr: Int, _ a: CPtr, _ na: Int) -> UInt64 {
        var borrow: UInt64 = 0
        var i = 0
        while i < na {
            let (s1, o1) = r[i].subtractingReportingOverflow(a[i])
            let (s2, o2) = s1.subtractingReportingOverflow(borrow)
            r[i] = s2
            borrow = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            i += 1
        }
        while borrow != 0 && i < nr {
            let (s, o) = r[i].subtractingReportingOverflow(borrow)
            r[i] = s
            borrow = o ? 1 : 0
            i += 1
        }
        return borrow
    }

    // MARK: - Multiplication

    /// Schoolbook product, r[0..<na+nb] must be zero on entry.
    @inline(__always)
    static func mulSchool(_ r: Ptr, _ a: CPtr, _ na: Int, _ b: CPtr, _ nb: Int) {
        for i in 0..<na {
            let ai = a[i]
            if ai == 0 { continue }
            var carry: UInt64 = 0
            let ri = r + i
            for j in 0..<nb {
                let (hi, lo) = ai.multipliedFullWidth(by: b[j])
                let (s1, o1) = lo.addingReportingOverflow(ri[j])
                let (s2, o2) = s1.addingReportingOverflow(carry)
                ri[j] = s2
                carry = hi &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            }
            ri[nb] = carry
        }
    }

    /// Schoolbook squaring (uses symmetry), r[0..<2n] must be zero on entry.
    static func sqrSchool(_ r: Ptr, _ a: CPtr, _ n: Int) {
        // off-diagonal products
        for i in 0..<n {
            let ai = a[i]
            if ai == 0 { continue }
            var carry: UInt64 = 0
            let ri = r + i
            var j = i + 1
            while j < n {
                let (hi, lo) = ai.multipliedFullWidth(by: a[j])
                let (s1, o1) = lo.addingReportingOverflow(ri[j])
                let (s2, o2) = s1.addingReportingOverflow(carry)
                ri[j] = s2
                carry = hi &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
                j += 1
            }
            ri[n] = carry
        }
        // double
        var top: UInt64 = 0
        for k in 0..<(2 * n) {
            let v = r[k]
            r[k] = (v << 1) | top
            top = v >> 63
        }
        // diagonal
        var carry: UInt64 = 0
        for i in 0..<n {
            let (hi, lo) = a[i].multipliedFullWidth(by: a[i])
            let (s1, o1) = r[2 * i].addingReportingOverflow(lo)
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[2 * i] = s2
            let c1: UInt64 = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            let (t1, p1) = r[2 * i + 1].addingReportingOverflow(hi)
            let (t2, p2) = t1.addingReportingOverflow(c1)
            r[2 * i + 1] = t2
            carry = (p1 ? 1 : 0) &+ (p2 ? 1 : 0)
        }
    }

    /// Full product r = a * b. r[0..<na+nb] must be zero on entry. Uses Karatsuba for large operands.
    static func mulInto(_ r: Ptr, _ a: CPtr, _ na: Int, _ b: CPtr, _ nb: Int) {
        if na < nb { mulInto(r, b, nb, a, na); return }
        if nb == 0 { return }
        if nb < karatsubaThreshold {
            if a == b && na == nb { sqrSchool(r, a, na) } else { mulSchool(r, a, na, b, nb) }
            return
        }
        if na >= 2 * nb {
            // unbalanced: chunk the longer operand
            let tmp = Ptr.allocate(capacity: 2 * nb)
            defer { tmp.deallocate() }
            var off = 0
            while off < na {
                let len = min(nb, na - off)
                tmp.initialize(repeating: 0, count: len + nb)
                mulInto(tmp, a + off, len, b, nb)
                addInPlace(r + off, na + nb - off, tmp, len + nb)
                off += len
            }
            return
        }
        let m = na / 2
        let na1 = na - m, nb1 = nb - m
        let square = (a == b && na == nb)
        // z0 and z2 directly into r
        mulInto(r, a, m, square ? a : b, m)
        mulInto(r + 2 * m, a + m, na1, square ? a + m : b + m, nb1)
        // sa = a0 + a1, sb = b0 + b1
        let la = na1 + 1
        let lb = max(m, nb1) + 1
        let sa = Ptr.allocate(capacity: la)
        sa.initialize(repeating: 0, count: la)
        sa.update(from: a + m, count: na1)
        addInPlace(sa, la, a, m)
        let sb: Ptr
        if square {
            sb = sa
        } else {
            sb = Ptr.allocate(capacity: lb)
            sb.initialize(repeating: 0, count: lb)
            if nb1 >= m {
                sb.update(from: b + m, count: nb1)
                addInPlace(sb, lb, b, m)
            } else {
                sb.update(from: b, count: m)
                addInPlace(sb, lb, b + m, nb1)
            }
        }
        let lbb = square ? la : lb
        let lz = la + lbb
        let z1 = Ptr.allocate(capacity: lz)
        z1.initialize(repeating: 0, count: lz)
        let nsa = normalizedCount(sa, la), nsb = normalizedCount(sb, lbb)
        mulInto(z1, sa, nsa, sb, nsb)
        subInPlace(z1, lz, r, 2 * m)
        subInPlace(z1, lz, r + 2 * m, na + nb - 2 * m)
        let nz = min(normalizedCount(z1, lz), na + nb - m)
        addInPlace(r + m, na + nb - m, z1, nz)
        z1.deallocate()
        if !square { sb.deallocate() }
        sa.deallocate()
    }

    static func mul(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
        if a.isEmpty || b.isEmpty { return [] }
        let n = a.count + b.count
        var r = [UInt64](repeating: 0, count: n)
        r.withUnsafeMutableBufferPointer { rp in
            a.withUnsafeBufferPointer { ap in
                b.withUnsafeBufferPointer { bp in
                    mulInto(rp.baseAddress!, ap.baseAddress!, a.count, bp.baseAddress!, b.count)
                }
            }
        }
        normalize(&r)
        return r
    }

    static func square(_ a: [UInt64]) -> [UInt64] {
        if a.isEmpty { return [] }
        let n = 2 * a.count
        var r = [UInt64](repeating: 0, count: n)
        r.withUnsafeMutableBufferPointer { rp in
            a.withUnsafeBufferPointer { ap in
                mulInto(rp.baseAddress!, ap.baseAddress!, a.count, ap.baseAddress!, a.count)
            }
        }
        normalize(&r)
        return r
    }

    // MARK: - Array add / sub

    static func add(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
        let (x, y) = a.count >= b.count ? (a, b) : (b, a)
        if y.isEmpty { return x }
        var r = x
        r.append(0)
        r.withUnsafeMutableBufferPointer { rp in
            y.withUnsafeBufferPointer { yp in
                _ = addInPlace(rp.baseAddress!, rp.count, yp.baseAddress!, y.count)
            }
        }
        normalize(&r)
        return r
    }

    /// a - b, requires a >= b.
    static func sub(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
        if b.isEmpty { return a }
        var r = a
        r.withUnsafeMutableBufferPointer { rp in
            b.withUnsafeBufferPointer { bp in
                _ = subInPlace(rp.baseAddress!, rp.count, bp.baseAddress!, b.count)
            }
        }
        normalize(&r)
        return r
    }

    // MARK: - Single limb helpers

    /// a * m + c
    static func mulSmall(_ a: [UInt64], _ m: UInt64, add c: UInt64 = 0) -> [UInt64] {
        var r = [UInt64](repeating: 0, count: a.count + 1)
        var carry = c
        for i in 0..<a.count {
            let (hi, lo) = a[i].multipliedFullWidth(by: m)
            let (s, o) = lo.addingReportingOverflow(carry)
            r[i] = s
            carry = hi &+ (o ? 1 : 0)
        }
        r[a.count] = carry
        normalize(&r)
        return r
    }

    /// In-place a = a * m + c (a may grow by one limb).
    static func mulAddSmallInPlace(_ a: inout [UInt64], _ m: UInt64, _ c: UInt64) {
        var carry = c
        a.withUnsafeMutableBufferPointer { p in
            for i in 0..<p.count {
                let (hi, lo) = p[i].multipliedFullWidth(by: m)
                let (s, o) = lo.addingReportingOverflow(carry)
                p[i] = s
                carry = hi &+ (o ? 1 : 0)
            }
        }
        if carry != 0 { a.append(carry) }
    }

    /// Returns (a / d, a % d) for a single limb divisor d != 0.
    static func divSmall(_ a: [UInt64], _ d: UInt64) -> ([UInt64], UInt64) {
        var q = [UInt64](repeating: 0, count: a.count)
        var rem: UInt64 = 0
        var i = a.count - 1
        while i >= 0 {
            let (qq, rr) = d.dividingFullWidth((rem, a[i]))
            q[i] = qq
            rem = rr
            i -= 1
        }
        normalize(&q)
        return (q, rem)
    }

    /// In-place a /= d, returns remainder.
    @discardableResult
    static func divSmallInPlace(_ a: inout [UInt64], _ d: UInt64) -> UInt64 {
        var rem: UInt64 = 0
        a.withUnsafeMutableBufferPointer { p in
            var i = p.count - 1
            while i >= 0 {
                let (qq, rr) = d.dividingFullWidth((rem, p[i]))
                p[i] = qq
                rem = rr
                i -= 1
            }
        }
        normalize(&a)
        return rem
    }

    /// a mod d for single limb d != 0.
    static func modSmall(_ a: [UInt64], _ d: UInt64) -> UInt64 {
        var rem: UInt64 = 0
        a.withUnsafeBufferPointer { p in
            var i = p.count - 1
            while i >= 0 {
                rem = d.dividingFullWidth((rem, p[i])).remainder
                i -= 1
            }
        }
        return rem
    }

    // MARK: - Shifts

    static func shiftLeft(_ a: [UInt64], _ bits: Int) -> [UInt64] {
        if a.isEmpty || bits == 0 { return a }
        let limbShift = bits / 64, bitShift = bits % 64
        var r = [UInt64](repeating: 0, count: a.count + limbShift + 1)
        if bitShift == 0 {
            for i in 0..<a.count { r[i + limbShift] = a[i] }
        } else {
            var carry: UInt64 = 0
            for i in 0..<a.count {
                r[i + limbShift] = (a[i] << UInt64(bitShift)) | carry
                carry = a[i] >> UInt64(64 - bitShift)
            }
            r[a.count + limbShift] = carry
        }
        normalize(&r)
        return r
    }

    static func shiftRight(_ a: [UInt64], _ bits: Int) -> [UInt64] {
        if bits == 0 { return a }
        let limbShift = bits / 64, bitShift = bits % 64
        if limbShift >= a.count { return [] }
        let n = a.count - limbShift
        var r = [UInt64](repeating: 0, count: n)
        if bitShift == 0 {
            for i in 0..<n { r[i] = a[i + limbShift] }
        } else {
            for i in 0..<n {
                let lo = a[i + limbShift] >> UInt64(bitShift)
                let hi = (i + limbShift + 1 < a.count) ? a[i + limbShift + 1] << UInt64(64 - bitShift) : 0
                r[i] = lo | hi
            }
        }
        normalize(&r)
        return r
    }

    // MARK: - Division (Knuth, TAOCP Vol. 2, Algorithm D)

    /// Returns (quotient, remainder) of a / b; b must be non-empty (non-zero) and normalised.
    static func divMod(_ a: [UInt64], _ b: [UInt64]) -> ([UInt64], [UInt64]) {
        precondition(!b.isEmpty, "Division by zero")
        if compare(a, b) < 0 { return ([], a) }
        if b.count == 1 {
            let (q, r) = divSmall(a, b[0])
            return (q, r == 0 ? [] : [r])
        }
        let n = b.count
        let m = a.count - n
        let s = b[n - 1].leadingZeroBitCount
        // normalised divisor and dividend (dividend gets one extra limb)
        var vn = [UInt64](repeating: 0, count: n)
        var un = [UInt64](repeating: 0, count: a.count + 1)
        if s == 0 {
            for i in 0..<n { vn[i] = b[i] }
            for i in 0..<a.count { un[i] = a[i] }
        } else {
            let rs = UInt64(64 - s), ls = UInt64(s)
            for i in stride(from: n - 1, to: 0, by: -1) { vn[i] = (b[i] << ls) | (b[i - 1] >> rs) }
            vn[0] = b[0] << ls
            un[a.count] = a[a.count - 1] >> rs
            for i in stride(from: a.count - 1, to: 0, by: -1) { un[i] = (a[i] << ls) | (a[i - 1] >> rs) }
            un[0] = a[0] << ls
        }
        var q = [UInt64](repeating: 0, count: m + 1)
        vn.withUnsafeBufferPointer { vp in
            un.withUnsafeMutableBufferPointer { up in
                q.withUnsafeMutableBufferPointer { qp in
                    divKnuth(up.baseAddress!, vp.baseAddress!, n, m, qp.baseAddress!)
                }
            }
        }
        // remainder = un[0..<n] >> s
        var r = [UInt64](repeating: 0, count: n)
        if s == 0 {
            for i in 0..<n { r[i] = un[i] }
        } else {
            let rs = UInt64(64 - s), ls = UInt64(s)
            for i in 0..<(n - 1) { r[i] = (un[i] >> ls) | (un[i + 1] << rs) }
            r[n - 1] = (un[n - 1] >> ls) | (un[n] << rs)
        }
        normalize(&q)
        normalize(&r)
        return (q, r)
    }

    /// Core of algorithm D. `un` has m+n+1 limbs, `vn` n >= 2 limbs with top bit set.
    /// Quotient (m+1 limbs) goes to q, remainder stays (normalised) in un[0..<n].
    static func divKnuth(_ un: Ptr, _ vn: CPtr, _ n: Int, _ m: Int, _ q: Ptr) {
        let vtop = vn[n - 1], vsec = vn[n - 2]
        var j = m
        while j >= 0 {
            let ujn = un[j + n], ujn1 = un[j + n - 1], ujn2 = un[j + n - 2]
            var qhat: UInt64
            var rhat: UInt64
            var rhatOverflow = false
            if ujn >= vtop {
                // qhat = b - 1, rhat = ujn*b + ujn1 - (b-1)*vtop = ujn1 + vtop (as ujn == vtop)
                qhat = UInt64.max
                let (r, o) = ujn1.addingReportingOverflow(vtop)
                rhat = r
                rhatOverflow = o
            } else {
                (qhat, rhat) = vtop.dividingFullWidth((ujn, ujn1))
            }
            // correct estimate: while qhat*vsec > rhat*b + ujn2
            while !rhatOverflow {
                let (ph, pl) = qhat.multipliedFullWidth(by: vsec)
                if ph > rhat || (ph == rhat && pl > ujn2) {
                    qhat &-= 1
                    let (r, o) = rhat.addingReportingOverflow(vtop)
                    rhat = r
                    rhatOverflow = o
                } else {
                    break
                }
            }
            // multiply and subtract
            var borrow: UInt64 = 0
            var carry: UInt64 = 0
            let u = un + j
            for i in 0..<n {
                let (ph, pl) = qhat.multipliedFullWidth(by: vn[i])
                let (pl2, o) = pl.addingReportingOverflow(carry)
                carry = ph &+ (o ? 1 : 0)
                let (t, b1) = u[i].subtractingReportingOverflow(pl2)
                let (t2, b2) = t.subtractingReportingOverflow(borrow)
                u[i] = t2
                borrow = (b1 ? 1 : 0) &+ (b2 ? 1 : 0)
            }
            let (t, b1) = u[n].subtractingReportingOverflow(carry)
            let (t2, b2) = t.subtractingReportingOverflow(borrow)
            u[n] = t2
            if b1 || b2 {
                // add back
                qhat &-= 1
                var c: UInt64 = 0
                for i in 0..<n {
                    let (s1, o1) = u[i].addingReportingOverflow(vn[i])
                    let (s2, o2) = s1.addingReportingOverflow(c)
                    u[i] = s2
                    c = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
                }
                u[n] = u[n] &+ c
            }
            q[j] = qhat
            j -= 1
        }
    }

    // MARK: - Bit helpers

    static func bitLength(_ a: [UInt64]) -> Int {
        guard let last = a.last else { return 0 }
        return (a.count - 1) * 64 + (64 - last.leadingZeroBitCount)
    }

    static func trailingZeroBits(_ a: [UInt64]) -> Int {
        for (i, l) in a.enumerated() where l != 0 {
            return i * 64 + l.trailingZeroBitCount
        }
        return 0
    }
}
