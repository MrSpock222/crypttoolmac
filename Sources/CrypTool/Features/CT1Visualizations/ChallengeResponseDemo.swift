import AppKit
import SwiftUI

// Native port of CT1's "Authentisierungsverfahren im Netz" (Challenge-Response-Demo,
// ChallengeResponse/*.cpp): a small network (Client, Router 1/2, Server 1/2, Angreifer) in
// which the user as attacker connects/disconnects lines, attacks computers, masks himself
// (man in the middle) and tries to authenticate at Server 1. Scenario logic, data values,
// protocol steps and messages follow Scenario.cpp / ChallengeResponseDlg.cpp.

extension CT1Visualizations {
    static func openChallengeResponse() {
        WindowPresenter.tool(id: "ct1-challenge-response", title: "Challenge-Response Demonstration", size: CGSize(width: 1040, height: 760)) {
            ChallengeResponseView()
        }
    }
}

// MARK: - Model

@MainActor
final class CRScenario: ObservableObject {
    enum Mode: Int, CaseIterable, Identifiable {
        case start, einfuehrung, passwort, einmalpasswoerter, crSymmetrisch, crAsymmetrisch, wechselseitig
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .start: return "Start"
            case .einfuehrung: return "Introduction"
            case .passwort: return "Password"
            case .einmalpasswoerter: return "One-time passwords"
            case .crSymmetrisch: return "Challenge-Response (symmetric)"
            case .crAsymmetrisch: return "Challenge-Response (asymmetric)"
            case .wechselseitig: return "Mutual authentication"
            }
        }
    }

    enum Action: Int { case nothing, connect, disconnect, attack, removeAttack }

    // computers
    static let client = 0, router1 = 1, router2 = 2, server1 = 3, server2 = 4, attacker = 5
    static let names = ["Client", "Router 1", "Router 2", "Server 1", "Server 2", "Attacker"]
    static let rects: [CGRect] = [CGRect(x: 180, y: 140, width: 40, height: 40), CGRect(x: 300, y: 140, width: 40, height: 40),
                                  CGRect(x: 420, y: 140, width: 40, height: 40), CGRect(x: 540, y: 40, width: 40, height: 40),
                                  CGRect(x: 540, y: 240, width: 40, height: 40), CGRect(x: 300, y: 240, width: 40, height: 40)]
    // wires: (a, b, from, to)
    static let wC_R1 = 0, wR1_R2 = 1, wR2_S1 = 2, wR2_S2 = 3, wA_R1 = 4, wA_R2 = 5
    static let wires: [(Int, Int, CGPoint, CGPoint)] = [
        (client, router1, CGPoint(x: 220, y: 160), CGPoint(x: 300, y: 160)),
        (router1, router2, CGPoint(x: 340, y: 160), CGPoint(x: 420, y: 160)),
        (router2, server1, CGPoint(x: 460, y: 140), CGPoint(x: 540, y: 60)),
        (router2, server2, CGPoint(x: 460, y: 180), CGPoint(x: 540, y: 260)),
        (attacker, router1, CGPoint(x: 320, y: 240), CGPoint(x: 320, y: 180)),
        (attacker, router2, CGPoint(x: 340, y: 260), CGPoint(x: 420, y: 180)),
    ]

    // captions (IDS_dataCaption_*)
    static let cPasswort = "Password: ", cEinmal = "Current password: ", cKey = "Key: "
    static let cPrivC = "Private Key (Client): ", cPubC = "Public Key (Client): "
    static let cPrivS = "Private Key (Server): ", cPubS = "Public Key (Server): "
    static let cChS = "Challenge from server: ", cRespS = "Response to server: "
    static let cChC = "Challenge from client: ", cRespC = "Response from client: "

    struct Line: Equatable { var label: String; var value: String }

    struct Packet: Identifiable {
        let id = UUID()
        var data: [Line]
        var last: Int
        var target: Int
        var attackerCopy: Bool
        var wire: Int? = nil
        var fromNode = 0
        var progress: Double = 0
        var fresh = true
    }

    @Published var mode: Mode = .start
    @Published var action: Action = .nothing
    @Published var connected: [Bool] = [true, true, true, true, false, false]
    @Published var underAttack: [Bool] = [false, false, false, false, false, false]
    @Published var data: [[Line]] = Array(repeating: [], count: 6)
    @Published var packets: [Packet] = []
    @Published var masked = false
    @Published var protocolRunning = false
    @Published var alert: String?
    @Published var speed: Double = 1

    private var protocolPacketID: UUID?
    private var authenticator = client
    private var step = 0
    private var authenticationFailed = false
    private var checkAuthenticationFailed = false
    private var authenticateAttacker = false
    private var timer: Timer?

    // scenario values (Scenario.cpp)
    private let vPasswort = "secret", vEinmal = "123456", vKey = "a3c2b1"
    private let vPrivC = "her7sj", vPubC = "her7sj", vPrivS = "98zwr3", vPubS = "2j658d"
    private var vChS = "a76zup", vChC = "9cxn4f"

    var networkVisible: Bool { mode != .start }

    var modeText: String {
        switch mode {
        case .start:
            return "Welcome to the demonstration of the Challenge-Response-protocol.\nYou will develop the protocol in several scenarios.\nThe different scenarios can be selected by the buttons on the left side. It makes sense to wade through the scenarios top down.\nYou can get further information by the use of the scenario help. You should take a look at the help before your first usage.\n\nPlease continue with 'Introduction' now."
        case .einfuehrung:
            return "Introduction: The above shown network with its elements forms the basis of the following scenarios:\nQuadrates illustrate computers and their users,\nlines show the network connections between these.\nYour cast will be the role of the attacker and your task is to get information to authenticate yourself at Server 1. For that purpose the actions link and unlink as well as attack station and quit attacking station are available. All actions can be performed by choosing the corresponding button and then click on the desired station or conduction. Connections between the attacker and a router can be established by choosing 'Link' and click on the according router. By pushing one of the 'Authenticate...' buttons, the authentication protocol is started and data packets are sent between the computers. Attacked computers send a copy of all packets as well as all their secret data at the attacker. By choosing 'Mask' you can start a man-in-the-middle-attack.\nTo restore the initial state of a scenario press 'Reset scenario'."
        case .passwort:
            return "Password: In this scenario the client authenticates himself by means of a password that he and server 1 know.\n\nYour job is to authenticate yourself as attacker at server 1 so that he expects you to be the client."
        case .einmalpasswoerter:
            return "One-time passwords: To avoid the password scenario attack, the client and server 1 have agreed to change their password after every authentication. They have therefore created a list of one-time passwords that they both know. After using a password, it is marked as used and then never reused.\n\nYour exercise is to play the role of an attacker feigning the legitimate client to become authenticated by server 1."
        case .crSymmetrisch:
            return "Challenge Response (with symmetric encryption): After the attack at the one-time-passwords client and servers use symmetric encryption by means of a secret key now. In order to minimize the organizational effort, not each pair of client and server get an own key, but all confidential parties get a common secret key. For authentication the server sends a random number, called Challenge, to the client. By the use of encryption the client generates the response and sends it back to the server. The server decrypts the response and checks whether the decrypted response conforms with the sent one. If that is the case, authentication is successful; otherwise the client is rejected. The server can trust the client, because no outsider knows the secret key and therefore can not generate the correct Response.\n\nBut maybe something has been overlooked by them...you can find more hints in the online help."
        case .crAsymmetrisch:
            return "Challenge Response (with asymmetric encryption): This time the Challenge Response procedure is performed with asymmetric (public key) encryption. Each participant holds his own pair of keys, consisting of a public key that everyone knows and a secret one that only the owner knows. Again, for authentication the server sends a challenge to the client, who signs it with his secret key and then sends the result back to the server. Now everyone, knowing the client´s public key, including the server, can verify the response: this means that the challenge was signed with the client´s private key.\n\nEven so the attacker perhaps can authenticate himself as client at server 1 by a trick."
        case .wechselseitig:
            return "Mutual Authentication: This scenario is based upon asymmetric encryption, too. But this time it is used synchronous in both directions. Viz the server sends a challenge to the client, which the client signs and returns to the server with his own challenge. Now the server can verify by the use of the client´s public key that the signed challenge (response from the client) can only derive from the client, because he is the only one with the according private key. To prove his own identity, the server signs the client´s challenge by the use of his private key and returns this to the client. Now, the client can verify the origin of the server´s response by means of the server´s public key. Thus both can be sure to know to whom they talk and basing on that establish a secure (encrypted) channel by exchanging an asymmetrical encrypted session key. Thus an attack at the level of protocols gets impossible. You can give all previous solutions a try, but you won´t be able to crack that protocol. But please take attacks to crack the encryption or the physical and logical connections into account. Attacking cryptographic methods can be tried with CrypTool. For more information according attacks to the physical or logical operations please see the online help."
        }
    }

    // MARK: data helpers (CData)

    func value(_ c: Int, _ label: String) -> String { data[c].first { $0.label == label }?.value ?? "" }

    func change(_ c: Int, _ label: String, _ v: String) {
        for i in data[c].indices where data[c][i].label == label { data[c][i].value = v }
    }

    private func rotate(_ s: String) -> String { s.isEmpty ? s : String(s.dropFirst()) + String(s.first!) }
    private func first(_ s: String) -> String { s.isEmpty ? "" : String(s.first!) }

    // MARK: modes

    func changeMode(_ m: Mode) {
        guard !protocolRunning else { return }
        mode = m
        packets = []
        data = Array(repeating: [], count: 6)
        let A = Self.attacker, C = Self.client, S1 = Self.server1, S2 = Self.server2
        func lines(_ l: [(String, String)], values: Bool) -> [Line] { l.map { Line(label: $0.0, value: values ? $0.1 : "") } }
        switch m {
        case .start, .einfuehrung:
            break
        case .passwort:
            let n = [(Self.cPasswort, vPasswort)]
            data[A] = lines(n, values: false); data[S1] = lines(n, values: true); data[C] = lines(n, values: true)
        case .einmalpasswoerter:
            let n = [(Self.cEinmal, vEinmal)]
            data[A] = lines(n, values: false); data[S1] = lines(n, values: true); data[C] = lines(n, values: true)
        case .crSymmetrisch:
            let n = [(Self.cKey, vKey), (Self.cChS, ""), (Self.cRespS, "")]
            data[A] = lines(n, values: false)
            for c in [S1, S2, C] { data[c] = lines(n, values: true) }
        case .crAsymmetrisch:
            var n = [(Self.cPrivC, ""), (Self.cPubC, vPubC), (Self.cChS, ""), (Self.cRespS, "")]
            for c in [A, S1, S2] { data[c] = lines(n, values: true) }
            n[0].1 = vPrivC
            data[C] = lines(n, values: true)
        case .wechselseitig:
            var n = [(Self.cPrivC, ""), (Self.cPubC, vPubC), (Self.cPrivS, ""), (Self.cPubS, vPubS),
                     (Self.cChS, ""), (Self.cRespS, ""), (Self.cChC, ""), (Self.cRespC, "")]
            for c in [A, S2] { data[c] = lines(n, values: true) }
            n[0].1 = vPrivC
            data[C] = lines(n, values: true)
            n[0].1 = ""; n[2].1 = vPrivS
            data[S1] = lines(n, values: true)
        }
    }

    func resetScenario() {
        guard mode != .start else { return }
        stopTimer()
        protocolRunning = false
        connected = [true, true, true, true, false, false]
        underAttack = [false, false, false, false, false, false]
        masked = false
        changeMode(mode)
    }

    // MARK: routing (next-hop table of CScenario::calculateShortestWays)

    /// Line on which computer `a` forwards a packet for `b` (nil = no route, packet is lost).
    func route(from a: Int, to b: Int) -> Int? {
        let R12 = connected[Self.wR1_R2], A1 = connected[Self.wA_R1], A2 = connected[Self.wA_R2]
        func w(_ i: Int) -> Int? { connected[i] ? i : nil }
        if a == b { return nil }
        switch a {
        case Self.client: return w(Self.wC_R1)
        case Self.server1: return w(Self.wR2_S1)
        case Self.server2: return w(Self.wR2_S2)
        case Self.router1:
            switch b {
            case Self.client: return w(Self.wC_R1)
            case Self.attacker: return A1 ? Self.wA_R1 : (R12 && A2 ? Self.wR1_R2 : nil)
            default: return R12 ? Self.wR1_R2 : (A1 && A2 ? Self.wA_R1 : nil)
            }
        case Self.router2:
            switch b {
            case Self.server1: return w(Self.wR2_S1)
            case Self.server2: return w(Self.wR2_S2)
            case Self.attacker: return A2 ? Self.wA_R2 : (R12 && A1 ? Self.wR1_R2 : nil)
            default: return R12 ? Self.wR1_R2 : (A1 && A2 ? Self.wA_R2 : nil)
            }
        default: // attacker
            switch b {
            case Self.client, Self.router1: return A1 ? Self.wA_R1 : (R12 && A2 ? Self.wA_R2 : nil)
            default: return A2 ? Self.wA_R2 : (R12 && A1 ? Self.wA_R1 : nil)
            }
        }
    }

    var attackerCanMask: Bool { !connected[Self.wR1_R2] && connected[Self.wA_R1] && connected[Self.wA_R2] }

    private func reachable(_ c: Int) -> Bool {
        let A1 = connected[Self.wA_R1], A2 = connected[Self.wA_R2], R12 = connected[Self.wR1_R2]
        switch c {
        case Self.router1: return A1 || (A2 && R12)
        case Self.router2: return (A1 && R12) || A2
        case Self.server2: return ((A1 && R12) || A2) && connected[Self.wR2_S2]
        default: return false
        }
    }

    // MARK: clicks (CScenario::mouseClick)

    func click(at p: CGPoint) {
        guard networkVisible else { return }
        let comp = Self.rects.firstIndex { $0.insetBy(dx: -3, dy: -3).contains(p) }
        let wire = Self.wires.indices.first { distance(p, Self.wires[$0].2, Self.wires[$0].3) < 7 }
        switch action {
        case .nothing:
            return
        case .connect, .disconnect:
            let on = action == .connect
            if let comp {
                if comp == Self.router1 { connected[Self.wA_R1] = on }
                if comp == Self.router2 { connected[Self.wA_R2] = on }
            } else if let wire {
                if on && (wire == Self.wA_R1 || wire == Self.wA_R2) { connected[wire] = true } else if !on || wire < 4 { connected[wire] = on }
            }
            if !on {
                for c in 0..<5 where underAttack[c] && route(from: Self.attacker, to: c) == nil { underAttack[c] = false }
            }
        case .attack, .removeAttack:
            guard let comp, comp != Self.attacker else { return }
            if comp == Self.client || comp == Self.server1 {
                if action == .attack { alert = "This station is protected too strong!" }
                return
            }
            if !reachable(comp) { alert = "You have no link up to this computer!"; return }
            underAttack[comp] = action == .attack
            if action == .attack && comp == Self.server2 && mode == .crSymmetrisch {
                change(Self.attacker, Self.cKey, vKey)      // the poorly protected Server 2 reveals the shared key
            }
        }
        if masked && !attackerCanMask {
            alert = "By use of that connection-configuration masking is not possible."
            masked = false
        }
    }

    private func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(1, dx * dx + dy * dy)))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    func toggleMask() {
        if protocolRunning {
            if !masked { alert = "Masking only is possible before starting the protocol." }
            masked = false
            return
        }
        if masked { masked = false; return }
        if attackerCanMask { masked = true } else {
            alert = "By use of that connection-configuration masking is not possible."
        }
    }

    // MARK: protocol (CScenario::initiateProtocol / protocolStep)

    func startProtocol(attacker: Bool) {
        guard mode != .start else { alert = "You have not selected a scenario."; return }
        guard !protocolRunning else { alert = "Protocol is already running!"; return }
        authenticateAttacker = attacker
        protocolRunning = true
        authenticationFailed = false
        checkAuthenticationFailed = false
        step = 0
        authenticator = attacker ? Self.attacker : Self.client
        packets = []
        protocolStep()
        startTimer()
    }

    private func send(_ lines: [Line], from: Int, to: Int) {
        packets.removeAll { $0.id == protocolPacketID }
        let p = Packet(data: lines, last: from, target: to, attackerCopy: false)
        protocolPacketID = p.id
        packets.append(p)
    }

    private func finishProtocol() {
        packets.removeAll { $0.id == protocolPacketID }
        protocolPacketID = nil
        protocolRunning = false
    }

    private func protocolStep() {
        let auth = authenticator, S1 = Self.server1
        switch mode {
        case .start:
            finishProtocol()
        case .einfuehrung:
            switch step {
            case 0: send([Line(label: Self.cPasswort, value: value(auth, Self.cPasswort))], from: S1, to: auth)
            case 1: send([Line(label: Self.cPasswort, value: value(auth, Self.cPasswort))], from: auth, to: S1)
            default: finishProtocol()
            }
        case .passwort:
            switch step {
            case 0:
                checkAuthenticationFailed = true
                send([Line(label: Self.cPasswort, value: value(auth, Self.cPasswort))], from: auth, to: S1)
            default: finishProtocol()
            }
        case .einmalpasswoerter:
            switch step {
            case 0:
                checkAuthenticationFailed = true
                send([Line(label: Self.cEinmal, value: value(auth, Self.cEinmal))], from: auth, to: S1)
            default:
                let np = rotate(value(Self.client, Self.cEinmal))     // next password of the list
                change(Self.client, Self.cEinmal, np)
                change(S1, Self.cEinmal, np)
                finishProtocol()
            }
        case .crSymmetrisch:
            switch step {
            case 0:
                vChS = rotate(vChS)
                change(S1, Self.cChS, vChS)
                change(S1, Self.cRespS, first(value(S1, Self.cKey)) + value(S1, Self.cChS))
                send([Line(label: Self.cChS, value: value(S1, Self.cChS))], from: S1, to: auth)
            case 1:
                checkAuthenticationFailed = true
                change(auth, Self.cRespS, first(value(auth, Self.cKey)) + value(auth, Self.cChS))
                send([Line(label: Self.cRespS, value: value(auth, Self.cRespS))], from: auth, to: S1)
            default: finishProtocol()
            }
        case .crAsymmetrisch:
            switch step {
            case 0:
                vChS = rotate(vChS)
                change(S1, Self.cChS, vChS)
                change(S1, Self.cRespS, first(value(S1, Self.cPubC)) + value(S1, Self.cChS))
                send([Line(label: Self.cChS, value: value(S1, Self.cChS))], from: S1, to: auth)
            case 1:
                checkAuthenticationFailed = true
                if auth == Self.client {
                    change(auth, Self.cRespS, first(value(auth, Self.cPrivC)) + value(auth, Self.cChS))
                }
                send([Line(label: Self.cRespS, value: value(auth, Self.cRespS))], from: auth, to: S1)
            default: finishProtocol()
            }
        case .wechselseitig:
            switch step {
            case 0:
                vChS = rotate(vChS)
                change(S1, Self.cChS, vChS)
                send([Line(label: Self.cChS, value: value(S1, Self.cChS))], from: S1, to: auth)
            case 1:
                vChC = rotate(vChC)
                change(auth, Self.cChC, vChC)
                if auth == Self.client {
                    change(auth, Self.cRespS, first(value(auth, Self.cPrivC)) + value(auth, Self.cChS) + value(auth, Self.cChC))
                }
                send([Line(label: Self.cRespS, value: value(auth, Self.cRespS)), Line(label: Self.cChC, value: value(auth, Self.cChC))],
                     from: auth, to: S1)
            case 2:
                let ver = String(value(S1, Self.cRespS).dropFirst())
                let chS = value(S1, Self.cChS), chC = value(S1, Self.cChC)
                guard ver.hasPrefix(chS) && ver.hasSuffix(chC) else {
                    authenticationFailed = true
                    finishProtocol()
                    return
                }
                change(S1, Self.cRespC, first(vPrivS) + vChC + vChS)
                send([Line(label: Self.cRespC, value: value(S1, Self.cRespC))], from: S1, to: auth)
            default: finishProtocol()
            }
        }
    }

    // MARK: packet movement (CScenario::onTick)

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopTimer() { timer?.invalidate(); timer = nil }

    private func tick() {
        let dt = (1.0 / 30) / 0.9 * max(0.25, speed)       // ~0.9 s per line at speed 1
        var i = 0
        while i < packets.count {
            var p = packets[i]
            if p.fresh { p.fresh = false; packets[i] = p; i += 1; continue }
            if let w = p.wire {
                p.progress += dt
                if p.progress >= 1 {
                    let wire = Self.wires[w]
                    p.last = p.fromNode == wire.0 ? wire.1 : wire.0
                    p.wire = nil
                    p.progress = 0
                    packets[i] = p
                    if !arrive(index: i) { continue }      // packet removed or replaced
                } else {
                    packets[i] = p
                }
            } else {
                packets[i] = p
                if !arrive(index: i) { continue }
            }
            i += 1
        }
        if packets.isEmpty { finishTick() }
    }

    /// The packet at `index` is in computer `last`. Returns false if the slot no longer holds
    /// the same packet (removed).
    private func arrive(index: Int) -> Bool {
        var p = packets[index]
        let c = p.last
        var removed = false
        if c == p.target {
            if checkAuthenticationFailed && p.target != Self.attacker && !p.attackerCopy {
                if value(p.target, p.data[0].label) != p.data[0].value { authenticationFailed = true }
            } else {
                for l in p.data { change(p.target, l.label, l.value) }
            }
            if c == Self.attacker { for l in p.data { change(Self.attacker, l.label, l.value) } }
            if underAttack[c] && !p.attackerCopy { spawnCopy(of: p, at: c) }
            if !p.attackerCopy {
                step += 1
                packets.remove(at: index)
                if p.id == protocolPacketID { protocolPacketID = nil }
                protocolStep()
            } else {
                packets.remove(at: index)
            }
            removed = true
        } else {
            if let w = route(from: c, to: p.target) {
                p.wire = w; p.fromNode = c; p.progress = 0
                packets[index] = p
            } else {
                packets.remove(at: index)
                if p.id == protocolPacketID { protocolPacketID = nil }
                removed = true
            }
            if c == Self.attacker { for l in p.data { change(Self.attacker, l.label, l.value) } }
            if underAttack[c] && !p.attackerCopy { spawnCopy(of: p, at: c) }
        }
        return !removed
    }

    private func spawnCopy(of p: Packet, at c: Int) {
        var copy = Packet(data: [p.data[0]], last: c, target: Self.attacker, attackerCopy: true)
        copy.fresh = false
        packets.append(copy)
    }

    private func finishTick() {
        stopTimer()
        if protocolRunning {
            protocolRunning = false
            alert = "The protocol was disturbed."
        } else if authenticationFailed {
            alert = "Authentication failed."
        } else if authenticateAttacker {
            alert = "Authentication of attacker was successful."
        } else if masked && mode != .wechselseitig {
            alert = "Authentication of attacker as 'Man In The Middle' successful by the use of masking."
        } else {
            alert = "Authentication of client successful."
        }
    }

    func packetPosition(_ p: Packet) -> CGPoint {
        if let w = p.wire {
            let wire = Self.wires[w]
            let (a, b) = p.fromNode == wire.0 ? (wire.2, wire.3) : (wire.3, wire.2)
            return CGPoint(x: a.x + (b.x - a.x) * p.progress, y: a.y + (b.y - a.y) * p.progress)
        }
        let r = Self.rects[p.last]
        return CGPoint(x: r.midX, y: r.midY)
    }
}

// MARK: - Scenario help (from CT1's online help hid_cr_sz_* / hid_cr_sol_*)

enum CRHelp {
    static func text(_ m: CRScenario.Mode) -> (scenario: String, solution: String?) {
        switch m {
        case .start, .einfuehrung:
            return ("The module shows in several scenarios how a client authenticates himself to a server and how an attacker tries to pass himself off as the client.\n\nUsage: Choose an action on the right (Link, Unlink, Attack station, Quit attacking station) and then click on a connection or a station. Connections between the attacker and a router are established by choosing 'Link' and clicking on the router. The two buttons 'Authenticate client' and 'Authenticate attacker' start the respective protocol. Attacked stations (red) send the attacker a copy of all packets passing through. 'Mask' enables a man-in-the-middle-attack.", nil)
        case .passwort:
            return ("If you click on 'Authenticate client' a secret password will be sent from client to server 1. This is known to the server and it compares the password forwarded with its own. If they match the server accepts the client’s identity.\n\nYour task as attacker is to spy out the password and use it in order to be accepted by the server as a client as well.",
                    "1. You create a connection between the attacker’s computer and Router 1 or Router 2.\n2. Attack Router 1 or Router 2 (it must appear red now).\n3. You start the protocol from the client via the button 'Authenticate client'. As soon as the data packet is transferred from the attacked router, a copy is forwarded to you so you can obtain the password.\n4. Now you can start the protocol from the attacker’s computer via the button 'Authenticate attacker' and you will be authenticated because you know the password.")
        case .einmalpasswoerter:
            return ("Client and Server 1 agree upon a secret list of passwords that are to be dealt with step-by-step. After each authentication both delete the used password from their lists. This time simple tapping will not help you further. Please take note of the hint that you are still in a position to intervene with the protocol procedure.",
                    "1. You create a connection between the attacker’s computer and router 1.\n2. Attack router 1.\n3. Separate the connection between router 1 and router 2.\n4. You start the protocol from the client. Router 1 forwards a copy of the packet with the password to you; the disconnection disturbs the protocol (\"The protocol was disturbed.\").\n5. Now revoke the separation of router 1 and router 2 and authenticate yourself as attacker with the still current password (from the server's point of view).")
        case .crSymmetrisch:
            return ("Server 1 sends a random number to the client called challenge. The client encrypts this number with a secret key and returns the result as response to Server 1 who knows the secret key as well and checks the response.\n\nBecause every station uses symmetric cryptography, Server 1, Server 2 and Client share the same symmetric key for reasons of efficiency. (Otherwise, with n parties there would need to be ½·n·(n−1) different keys.)",
                    "All communication partners use the same key – if only one of these parties is vulnerable the whole system gets compromised.\n1. Connect yourself to Router 1 or Router 2.\n2. Then attack Server 2 (it stands for an insufficiently protected server) so you can obtain the secret key.\n3. Then you can start the protocol from the attacker’s computer.")
        case .crAsymmetrisch:
            return ("The server sends a challenge to the client, who signs it with his secret key and then sends the result back to the server as response. Everyone knowing the client's public key can verify the response.",
                    "Man-in-the-middle-attack: The attacker makes sure that all data packets are transferred through him and identifies himself to the client as Server 1 and to Server 1 as client.\n1. You create a connection between the attacker and the two routers.\n2. Separate the connection between the two routers.\n3. Put on your masking.\n4. Start the protocol from the client. Finally, you (attacker) will be authenticated instead of the client. This solution works, by the way, for all previous scenarios too.")
        case .wechselseitig:
            return ("The server sends a challenge to the client, who signs it and returns it and an additional challenge to the server. The server verifies the response and for his part signs the client's challenge. Thus both can be sure who they communicate with and can, for example, exchange an asymmetrically encrypted session key.",
                    "It is not possible to attack that protocol on protocol level: An attacker can eavesdrop the communication, but he will not get one of the private keys. Thus the two parties can establish a secure channel which the attacker cannot eavesdrop.")
        }
    }
}

// MARK: - View

struct ChallengeResponseView: View {
    @StateObject private var sc = CRScenario()
    @CTState private var showHelp = false
    @CTState private var showSolution = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            scenarioButtons
                .frame(width: 210)
                .padding(10)
            Divider()
            VStack(spacing: 0) {
                networkCanvas
                Divider()
                HStack(spacing: 10) {
                    Button("Reset scenario") { sc.resetScenario() }.disabled(!sc.networkVisible || sc.protocolRunning)
                    Spacer()
                    Image(systemName: "tortoise").foregroundStyle(.secondary)
                    Slider(value: Binding(get: { log2(sc.speed) }, set: { sc.speed = pow(2, $0) }), in: -2...2).frame(width: 90)
                    Image(systemName: "hare").foregroundStyle(.secondary)
                    Button("Scenario help") { showSolution = false; showHelp = true }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                ScrollView {
                    Text(sc.modeText).frame(maxWidth: .infinity, alignment: .leading).padding(8).textSelection(.enabled)
                }
                .frame(height: 150)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .alert(sc.alert ?? "", isPresented: Binding(get: { sc.alert != nil }, set: { if !$0 { sc.alert = nil } })) {
            Button("OK") { sc.alert = nil }
        }
        .sheet(isPresented: $showHelp) { helpSheet }
        .onDisappear { sc.stopTimer() }
    }

    private var scenarioButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            modeButton(.start)
            modeButton(.einfuehrung)
            GroupBox("Scenarios") {
                VStack(spacing: 6) {
                    ForEach([CRScenario.Mode.passwort, .einmalpasswoerter, .crSymmetrisch, .crAsymmetrisch, .wechselseitig]) { modeButton($0) }
                }
                .padding(.vertical, 4)
            }
            if sc.networkVisible { actionButtons }
            Spacer()
        }
    }

    private func modeButton(_ m: CRScenario.Mode) -> some View {
        Button { sc.changeMode(m) } label: {
            Text(m.title).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(sc.mode == m ? .accentColor : nil)
        .background(sc.mode == m ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .disabled(sc.protocolRunning)
    }

    private var actionButtons: some View {
        GroupBox("Actions") {
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $sc.action) {
                    Text("None").tag(CRScenario.Action.nothing)
                    Text("Link").tag(CRScenario.Action.connect)
                    Text("Unlink").tag(CRScenario.Action.disconnect)
                    Text("Attack station").tag(CRScenario.Action.attack)
                    Text("Quit attacking station").tag(CRScenario.Action.removeAttack)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
        }
    }

    private var networkCanvas: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 720, geo.size.height / 400)
            let ox = max(0, (geo.size.width - 720 * s) / 2) - 10 * s
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in drawNetwork(ctx, scale: s, ox: ox) }
                if sc.networkVisible {
                    // protocol buttons (CT1: next to the client and the attacker)
                    Button { sc.startProtocol(attacker: false) } label: {
                        Text("Authenticate client").multilineTextAlignment(.center).font(.caption).fixedSize()
                    }
                    .position(x: ox + 200 * s, y: 96 * s)
                    VStack(spacing: 4) {
                        Button { sc.startProtocol(attacker: true) } label: {
                            Text("Authenticate attacker").multilineTextAlignment(.center).font(.caption).fixedSize()
                        }
                        Toggle("Mask", isOn: Binding(get: { sc.masked }, set: { _ in sc.toggleMask() }))
                            .toggleStyle(.button).font(.caption)
                    }
                    .position(x: ox + 225 * s, y: 330 * s)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { loc in
                sc.click(at: CGPoint(x: (loc.x - ox) / s, y: loc.y / s))
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func drawNetwork(_ ctx: GraphicsContext, scale s: CGFloat, ox: CGFloat) {
        guard sc.networkVisible else {
            ctx.draw(Text("Challenge-Response").font(.system(size: 28 * s, weight: .bold)), at: CGPoint(x: ox + 380 * s, y: 170 * s))
            return
        }
        func P(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * s, y: p.y * s) }
        // wires
        for (i, w) in CRScenario.wires.enumerated() {
            var path = Path(); path.move(to: P(w.2)); path.addLine(to: P(w.3))
            if sc.connected[i] {
                ctx.stroke(path, with: .color(i >= 4 ? .red : .primary), lineWidth: 3 * s)
            } else {
                ctx.stroke(path, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5 * s, dash: [4 * s, 4 * s]))
            }
        }
        // computers
        for c in 0..<6 {
            let r = CRScenario.rects[c]
            let rect = CGRect(x: ox + r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s)
            let red = c == CRScenario.attacker || sc.underAttack[c]
            ctx.fill(Path(rect), with: .color(red ? Color.red.opacity(0.12) : Color.blue.opacity(0.08)))
            ctx.stroke(Path(rect), with: .color(red ? .red : .blue), lineWidth: 2.5 * s)
            let name = Text(CRScenario.names[c]).font(.system(size: 12 * s, weight: .semibold)).foregroundColor(red ? .red : .primary)
            if c == CRScenario.attacker {
                ctx.draw(name, at: CGPoint(x: rect.maxX + 4 * s, y: rect.maxY - 6 * s), anchor: .leading)
            } else {
                ctx.draw(name, at: CGPoint(x: rect.midX, y: rect.minY - 9 * s))
            }
            // data below the computer (values hidden except for the attacker)
            for (i, l) in sc.data[c].enumerated() {
                let shown = c == CRScenario.attacker ? l.value : String(repeating: "*", count: l.value.count)
                let t = Text(l.label + shown).font(.system(size: 9.5 * s, design: .monospaced)).foregroundColor(red ? .red : .primary)
                if c == CRScenario.client {      // left of the client (keeps the attacker area free)
                    ctx.draw(t, at: CGPoint(x: rect.maxX, y: rect.maxY + (8 + 12 * CGFloat(i)) * s), anchor: .trailing)
                } else {
                    ctx.draw(t, at: CGPoint(x: rect.minX - 2 * s, y: rect.maxY + (8 + 12 * CGFloat(i)) * s), anchor: .leading)
                }
            }
        }
        // packets
        for p in sc.packets {
            let c = P(sc.packetPosition(p))
            let rect = CGRect(x: c.x - 9 * s, y: c.y - 6 * s, width: 18 * s, height: 12 * s)
            ctx.fill(Path(rect), with: .color(p.attackerCopy ? Color.red.opacity(0.85) : Color.yellow))
            ctx.stroke(Path(rect), with: .color(.black), lineWidth: 1)
            var x = Path()
            x.move(to: CGPoint(x: rect.minX, y: rect.minY)); x.addLine(to: CGPoint(x: rect.midX, y: rect.midY)); x.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.stroke(x, with: .color(.black), lineWidth: 1)
            ctx.draw(Text(p.data[0].label.trimmingCharacters(in: CharacterSet(charactersIn: ": "))).font(.system(size: 8.5 * s)),
                     at: CGPoint(x: c.x, y: c.y + 13 * s))
        }
    }

    private var helpSheet: some View {
        let h = CRHelp.text(sc.mode)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Scenario help: \(sc.mode.title)").font(.title3.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(h.scenario).fixedSize(horizontal: false, vertical: true)
                    if let sol = h.solution {
                        if showSolution {
                            Text("Solution").font(.headline)
                            Text(sol).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Button("Show solution") { showSolution = true }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("Close") { showHelp = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(18)
        .frame(width: 560, height: 420)
    }
}
