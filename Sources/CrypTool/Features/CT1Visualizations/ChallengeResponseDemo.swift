import AppKit
import SwiftUI

// Native port of CT1's "Authentisierungsverfahren im Netz" (Challenge-Response-Demo,
// ChallengeResponse/*.cpp): a small network (Client, Router 1/2, Server 1/2, Angreifer) in
// which the user as attacker connects/disconnects lines, attacks computers, masks himself
// (man in the middle) and tries to authenticate at Server 1. Scenario logic, data values,
// protocol steps and messages follow Scenario.cpp / ChallengeResponseDlg.cpp.

extension CT1Visualizations {
    static func openChallengeResponse() {
        WindowPresenter.tool(id: "ct1-challenge-response", title: "Challenge-Response-Demo", size: CGSize(width: 1040, height: 760)) {
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
            case .einfuehrung: return "Einführung"
            case .passwort: return "Passwort"
            case .einmalpasswoerter: return "Einmalpasswörter"
            case .crSymmetrisch: return "Challenge-Response (symmetrisch)"
            case .crAsymmetrisch: return "Challenge-Response (asymmetrisch)"
            case .wechselseitig: return "Wechselseitige Authentifikation"
            }
        }
    }

    enum Action: Int { case nothing, connect, disconnect, attack, removeAttack }

    // computers
    static let client = 0, router1 = 1, router2 = 2, server1 = 3, server2 = 4, attacker = 5
    static let names = ["Client", "Router 1", "Router 2", "Server 1", "Server 2", "Angreifer"]
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
    static let cPasswort = "Passwort: ", cEinmal = "Aktuelles Passwort:  ", cKey = "Key: "
    static let cPrivC = "Private Key (Client): ", cPubC = "Public Key (Client): "
    static let cPrivS = "Private Key (Server): ", cPubS = "Public Key (Server): "
    static let cChS = "Challenge von Server: ", cRespS = "Response an Server: "
    static let cChC = "Challenge von Client: ", cRespC = "Response an Client: "

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
    private let vPasswort = "geheim", vEinmal = "123456", vKey = "a3c2b1"
    private let vPrivC = "her7sj", vPubC = "her7sj", vPrivS = "98zwr3", vPubS = "2j658d"
    private var vChS = "a76zup", vChC = "9cxn4f"

    var networkVisible: Bool { mode != .start }

    var modeText: String {
        switch mode {
        case .start:
            return "Willkommen zur Demonstration des Challenge-Response-Protokolls.\nDas Protokoll wird in mehreren Szenarien eingeführt.\nMit den Knöpfen auf der linken Seite können Sie zwischen den einzelnen Szenarien wählen. Es ist sinnvoll, die Szenarien von oben nach unten durchzuarbeiten.\nWeiterführende Informationen erhalten Sie in jedem Szenario über die Hilfe zum Szenario. Die Hilfe sollten Sie sich vor der ersten Verwendung ansehen.\n\nBitte fahren Sie nun mit 'Einführung' fort."
        case .einfuehrung:
            return "Einführung: Allen folgenden Szenarien liegt das oben gezeigte Netzwerk mit seinen Elementen zugrunde:\nQuadrate sind Rechner und ihre Benutzer,\nLinien sind die Netzwerkverbindungen dazwischen.\nSie schlüpfen in die Rolle eines Angreifers und versuchen Informationen zu erlangen, mit denen Sie sich bei Server 1 authentifizieren können. Dazu stehen Ihnen die Aktionen Leitungen verbinden und trennen sowie Rechner angreifen und den Angriff auf den Rechner beenden zur Verfügung. Alle Aktionen werden durchgeführt, indem Sie zunächst den entsprechenden Knopf auswählen und dann auf den gewünschten Rechner oder die gewünschte Verbindung klicken. Verbindungen zwischen Angreifer und einem Router werden durch ’Verbinden’ und Anklicken des Routers hergestellt. Wenn einer der beiden Knöpfe zum Authentifizieren gedrückt wird, startet das Protokoll und zwischen den Rechnern werden Datenpakete verschickt. Angegriffene Rechner schicken eine Kopie aller durchgehenden Pakete sowie alle ihre geheimen Daten an den Angreifer. Mit 'Maskieren' können Sie einen Man-in-the-middle-Angriff durchführen.\nDurch ’Szenario zurücksetzen’ können Sie ein Szenario in den ursprünglichen Zustand versetzen.\n\nBevor Sie das erste Szenario auswählen, können Sie hier alle Funktionen ausprobieren. Viel Spaß!"
        case .passwort:
            return "Passwort: In diesem Szenario authentifiziert sich der Client durch ein Passwort, das er und Server 1 kennen.\n\nIhre Aufgabe als Angreifer ist es, sich bei Server 1 als Client auszugeben und als solcher auch zu authentifizieren."
        case .einmalpasswoerter:
            return "Einmalpasswörter: Um dem Angriff des Passwort-Szenarios zu entgehen, haben Client und Server 1 vereinbart, nach jeder erfolgten Authentifikation das Passwort zu wechseln. Dafür haben sie eine Liste mit Einmalpasswörtern angelegt und ausgetauscht. Wurde ein Einmalpasswort für die Authentifizierung verwendet, wird es als benutzt gekennzeichnet und kann nicht noch einmal verwendet werden. Für die nächste Authentifizierung muss ein anderes Einmalpasswort der Liste verwendet werden.\n\nIhre Aufgabe ist es wieder, sich als Angreifer so bei Server 1 zu authentifizieren, dass er Sie für den Client hält."
        case .crSymmetrisch:
            return "Challenge-Response (mit symmetrischer Verschlüsselung): Nach dem Angriff auf Einmalpasswörter setzen der Client und die Server nun ein Verschlüsselungsverfahren mit einem geheimen Schlüssel ein. Um den organisatorischen Aufwand gering zu halten, wird nicht für jedes Paar aus einem Client und einem Server ein neuer Schlüssel erzeugt und verteilt, sondern alle vertrauenswürdigen Parteien erhalten einen gemeinsamen Schlüssel. Zur Authentifizierung schickt der Server eine Zufallszahl, genannt Challenge (Herausforderung) an den Client. Durch Verschlüsselung mit dem geheimen Schlüssel generiert der Client daraus die Response (Antwort) und schickt diese zurück an den Server. Der Server entschlüsselt die Response und überprüft, ob die entschlüsselte Challenge mit der von ihm geschickten übereinstimmt. Ist dies der Fall, ist die Authentifikation erfolgreich; wenn nicht, wird der Client abgewiesen. Der Server kann dem Client vertrauen, weil kein Außenstehender den geheimen Schlüssel kennt und deshalb die Response nicht korrekt erzeugen kann.\n\nAber vielleicht haben die beiden etwas übersehen...weitere Tipps in der Hilfe."
        case .crAsymmetrisch:
            return "Challenge-Response (mit asymmetrischer Verschlüsselung): Dieses Mal wird das Challenge-Response-Verfahren mit asymmetrischer (public key) Verschlüsselung durchgeführt. Jeder Teilnehmer besitzt ein eigenes Schlüsselpaar: den privaten kennt nur der Teilnehmer, den öffentlichen Schlüssel kennt jeder. Zur Authentifizierung wird wieder eine Challenge vom Server an den Client geschickt, der diese dann mit seinem geheimen Schlüssel signiert und das Ergebnis als Response zurückschickt. Jetzt kann jeder, der im Besitz des öffentlichen Schlüssels des Clients ist, also auch der Server, die Response prüfen: Das bedeutet das die Challenge mit dem privaten Schlüssel des Clients signiert wurde.\n\nTrotzdem, mit einem kleinen Trick kann sich der Angreifer vielleicht doch noch bei Server 1 als Client authentifizieren."
        case .wechselseitig:
            return "Wechselseitige Authentifikation: Dieses Szenario basiert auch auf dem Challenge-Response-Verfahren mit asymmetrischer Verschlüsselung. Diesmal wird es allerdings gleichzeitig in beide Richtungen angewendet. D.h. der Server schickt eine Challenge an den Client, die dieser signiert und mitsamt einer eigenen Challenge an den Server zurückschickt. Nun kann der Server durch den öffentlichen Schlüssel des Clients prüfen, dass die Response nur vom Client stammen kann, da nur dieser den zur Signatur nötigen privaten Schlüssel besitzt. Um auch seine eigene Identität zu beweisen, signiert der Server die Challenge des Clients mit seinem eigenen privaten Schlüssel und schickt dies als seine Response zurück. Jetzt kann im Gegenzug auch der Client mit Hilfe des öffentlichen Schlüssels des Servers prüfen, dass diese Response nur vom Server stammen kann. Somit können sich beide sicher sein, mit wem sie kommunizieren und darauf aufbauend z.B. einen sicheren (verschlüsselten) Kanal etablieren, indem sie einen Session-Key asymmetrisch verschlüsselt austauschen. Dadurch wird ein Angriff auf Protokollebene unmöglich. Sie können alle vorangegangenen Lösungen ausprobieren, dieses Protokoll ist damit nicht zu knacken. Beachten Sie aber, dass es andere Angriffe geben kann - gegen die verwendeten kryptografischen Verfahren oder gegen die physikalischen und logischen Verbindungen. Angriffe auf kryptografische Verfahren können mit CrypTool ausprobiert werden, zu Angriffen gegen die physikalischen und logischen Verfahren sei auf die Hilfe verwiesen."
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
                if action == .attack { alert = "Dieser Rechner ist zu stark gesichert!" }
                return
            }
            if !reachable(comp) { alert = "Sie haben keine Verbindung zu diesem Rechner!"; return }
            underAttack[comp] = action == .attack
            if action == .attack && comp == Self.server2 && mode == .crSymmetrisch {
                change(Self.attacker, Self.cKey, vKey)      // the poorly protected Server 2 reveals the shared key
            }
        }
        if masked && !attackerCanMask {
            alert = "Maskierung des Angreifers bei dieser Verbindungskonfiguration nicht möglich."
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
            if !masked { alert = "Maskierung nur vor Beginn des Protokolls möglich." }
            masked = false
            return
        }
        if masked { masked = false; return }
        if attackerCanMask { masked = true } else {
            alert = "Maskierung des Angreifers bei dieser Verbindungskonfiguration nicht möglich."
        }
    }

    // MARK: protocol (CScenario::initiateProtocol / protocolStep)

    func startProtocol(attacker: Bool) {
        guard mode != .start else { alert = "Sie haben kein Szenario ausgewählt."; return }
        guard !protocolRunning else { alert = "Protokoll läuft bereits!"; return }
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
            alert = "Das Protokoll wurde gestört."
        } else if authenticationFailed {
            alert = "Authentifikation fehlgeschlagen."
        } else if authenticateAttacker {
            alert = "Authentifikation des Angreifers erfolgreich."
        } else if masked && mode != .wechselseitig {
            alert = "Authentifikation des Angreifers als 'Man In The Middle' durch Maskierung erfolgreich."
        } else {
            alert = "Authentifikation des Clients erfolgreich."
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
            return ("Das Modul zeigt in mehreren Szenarien, wie sich ein Client gegenüber einem Server authentifiziert und wie ein Angreifer versucht, sich als Client auszugeben.\n\nBedienung: Wählen Sie rechts eine Aktion (Verbinden, Trennen, Rechner angreifen, Angriff auf Rechner beenden) und klicken Sie dann auf eine Verbindung oder einen Rechner. Verbindungen zwischen Angreifer und Router entstehen durch ‚Verbinden‘ und Anklicken des Routers. Die beiden Knöpfe ‚Authentifizieren des Clients‘ und ‚Authentifizieren des Angreifers‘ starten das jeweilige Protokoll. Angegriffene Rechner (rot) schicken dem Angreifer eine Kopie aller durchgehenden Pakete. ‚Maskieren‘ ermöglicht einen Man-in-the-middle-Angriff.", nil)
        case .passwort:
            return ("Wenn Sie auf ‚Authentifizieren des Clients‘ klicken, wird ein geheimes Passwort vom Client zum Server 1 geschickt. Diesem ist es bereits bekannt und er vergleicht das geschickte Passwort mit seinem eigenen. Stimmen die Passworte überein, akzeptiert er die Identität des Clients.\n\nIhre Aufgabe als Angreifer ist es, das Passwort auszuspähen und es zu verwenden, um ebenfalls von Server 1 als Client anerkannt zu werden.",
                    "1. Erstellen Sie eine Verbindung zwischen dem Angreifer und Router 1 oder Router 2.\n2. Greifen Sie Router 1 oder Router 2 an (er muss jetzt rot erscheinen).\n3. Starten Sie das Protokoll vom Client aus (‚Authentifizieren des Clients‘). Sobald das Datenpaket beim angegriffenen Router weitergeleitet wird, schickt er Ihnen eine Kopie davon. Dadurch erhalten Sie das Passwort.\n4. Starten Sie das Protokoll vom Angreifer aus (‚Authentifizieren des Angreifers‘) – Sie werden authentifiziert, da Sie das Passwort kennen.")
        case .einmalpasswoerter:
            return ("Client und Server 1 haben eine geheime Liste mit Passwörtern vereinbart, die schrittweise abgearbeitet wird. Nach jeder Authentifikation streichen beide das benutzte Passwort von ihrer Liste. Einfaches Abhören bringt Sie dieses Mal nicht weiter. Hinweis: Sie können auch während des Protokollablaufs noch eingreifen.",
                    "1. Erstellen Sie eine Verbindung zwischen dem Angreifer und Router 1.\n2. Greifen Sie Router 1 an.\n3. Trennen Sie die Verbindung zwischen Router 1 und Router 2.\n4. Starten Sie das Protokoll vom Client aus. Router 1 schickt Ihnen eine Kopie des Pakets mit dem Passwort; das Protokoll wird durch die Trennung gestört („Das Protokoll wurde gestört.“).\n5. Stellen Sie die Verbindung zwischen Router 1 und Router 2 wieder her und authentifizieren Sie sich als Angreifer mit dem aus Serversicht noch aktuellen Passwort.")
        case .crSymmetrisch:
            return ("Server 1 schickt eine Zufallszahl (Challenge) an den Client. Der Client verschlüsselt sie mit dem geheimen Schlüssel und schickt das Ergebnis als Response zurück. Server 1 kennt denselben Schlüssel und prüft die Antwort.\n\nDa alle nur symmetrische Verfahren einsetzen, verwenden Server 1, Server 2 und Client aus Effizienzgründen denselben symmetrischen Schlüssel. (Bei n Parteien wären sonst ½·n·(n−1) verschiedene Schlüssel nötig.)",
                    "Alle Kommunikationspartner verwenden denselben Schlüssel – ist einer von ihnen angreifbar, ist die gesamte Kommunikation kompromittiert.\n1. Verbinden Sie sich mit Router 1 oder Router 2.\n2. Greifen Sie Server 2 an (er steht für einen schlecht geschützten Server). Dadurch erhalten Sie den geheimen Schlüssel.\n3. Starten Sie das Protokoll vom Angreifer aus.")
        case .crAsymmetrisch:
            return ("Die Challenge wird vom Server an den Client geschickt, der sie mit seinem geheimen Schlüssel signiert und das Ergebnis als Response zurückschickt. Jeder, der den öffentlichen Schlüssel des Clients besitzt, kann die Response prüfen.",
                    "Man-in-the-middle-Angriff: Der Angreifer sorgt dafür, dass alle Datenpakete über ihn laufen, und gibt sich gegenüber dem Client als Server 1 und gegenüber Server 1 als Client aus.\n1. Stellen Sie zwei Verbindungen vom Angreifer zu den beiden Routern her.\n2. Trennen Sie die Verbindung zwischen den beiden Routern.\n3. Schalten Sie die Maskierung ein.\n4. Starten Sie das Protokoll vom Client aus. Am Schluss werden Sie (der Angreifer) an Stelle des Clients authentifiziert. Diese Lösung funktioniert übrigens auch für alle bisherigen Szenarien.")
        case .wechselseitig:
            return ("Der Server schickt eine Challenge an den Client, die dieser signiert und mitsamt einer eigenen Challenge zurückschickt. Der Server prüft die Response und signiert seinerseits die Challenge des Clients. So können sich beide sicher sein, mit wem sie kommunizieren, und z. B. einen Session-Key asymmetrisch verschlüsselt austauschen.",
                    "Dieses Protokoll ist auf Protokollebene nicht zu knacken: Ein Angreifer kann den Ablauf zwar belauschen, kommt aber nicht in den Besitz eines der beiden privaten Schlüssel. Beide Parteien können daher einen sicheren Kanal aufbauen, den der Angreifer nicht belauschen kann.")
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
                    Button("Szenario zurücksetzen") { sc.resetScenario() }.disabled(!sc.networkVisible || sc.protocolRunning)
                    Spacer()
                    Image(systemName: "tortoise").foregroundStyle(.secondary)
                    Slider(value: Binding(get: { log2(sc.speed) }, set: { sc.speed = pow(2, $0) }), in: -2...2).frame(width: 90)
                    Image(systemName: "hare").foregroundStyle(.secondary)
                    Button("Hilfe zum Szenario") { showSolution = false; showHelp = true }
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
            GroupBox("Szenarienauswahl") {
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
        GroupBox("Aktionen") {
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $sc.action) {
                    Text("Keine").tag(CRScenario.Action.nothing)
                    Text("Verbinden").tag(CRScenario.Action.connect)
                    Text("Trennen").tag(CRScenario.Action.disconnect)
                    Text("Rechner angreifen").tag(CRScenario.Action.attack)
                    Text("Angriff auf Rechner beenden").tag(CRScenario.Action.removeAttack)
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
                        Text("Authentifizieren\ndes Clients").multilineTextAlignment(.center).font(.caption).fixedSize()
                    }
                    .position(x: ox + 200 * s, y: 96 * s)
                    VStack(spacing: 4) {
                        Button { sc.startProtocol(attacker: true) } label: {
                            Text("Authentifizieren\ndes Angreifers").multilineTextAlignment(.center).font(.caption).fixedSize()
                        }
                        Toggle("Maskieren", isOn: Binding(get: { sc.masked }, set: { _ in sc.toggleMask() }))
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
            Text("Hilfe zum Szenario: \(sc.mode.title)").font(.title3.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(h.scenario).fixedSize(horizontal: false, vertical: true)
                    if let sol = h.solution {
                        if showSolution {
                            Text("Lösung").font(.headline)
                            Text(sol).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Button("Lösung anzeigen") { showSolution = true }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("Schließen") { showHelp = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(18)
        .frame(width: 560, height: 420)
    }
}
