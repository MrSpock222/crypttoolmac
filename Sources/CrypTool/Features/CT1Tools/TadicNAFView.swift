import AppKit
import CTBigNum
import CTCommon
import SwiftUI

/// German version of CT1's front end t-adicNAF.hta ("t-adic NAF GUI v1.3.3b") for the generator
/// t-adicNAF.exe by Anastasios Kanakis; the computation is TauAdicNAF (CTBigNum).
struct TadicNAFView: View {
    @CTState private var aIsOne = false
    @CTState private var keyText = "1001"            // content of the sample file k1.txt
    @CTState private var source = "k1.txt"           // name shown in key-out.txt
    @CTState private var loadedText = "1001"
    @CTState private var result: TauAdicNAF.Result?
    @CTState private var milliseconds = 0
    @CTState private var keyOut = ""                 // accumulated "key-out.txt"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Binären Schlüssel in die t-adic-NAF-Darstellung umwandeln").font(.headline)
                Text("Dieses Werkzeug benötigt zwei Eingabeparameter:")

                Text("1) Der erste Parameter ist der Wert „a“ der Koblitz-Kurve: y² + xy = x³ + a·x² + 1")
                Toggle(isOn: $aIsOne) { Text("(angehakt: a = 1, sonst a = 0)").italic() }
                    .padding(.leading, 16)

                Text("2) Der zweite Parameter ist der binäre Schlüssel als Text (nur die Ziffern 0 und 1).")
                HStack {
                    TextField("", text: $keyText)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: keyText) { _, new in if new != loadedText { source = "Eingabefeld" } }
                    Button("Datei laden…") { loadFile() }
                }
                .padding(.leading, 16)

                Button { generate() } label: {
                    Text("t-adic-NAF-Schlüssel erzeugen").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Divider()
                Text("Eingabe:").bold()
                lengthRow("Länge des Eingabeschlüssels:", result?.key.count)
                field("Binärer Schlüssel vom höchstwertigen (MSB) zum niederwertigsten Bit (LSB):", result?.key)

                Text("Ausgabe:").bold().padding(.top, 4)
                Text("Ergebnis von Algorithmus A:")
                lengthRow("Länge des erzeugten Schlüssels:", result?.generated.count)
                field("Erzeugter t-adic-NAF-Schlüssel (von MSB zu LSB):", result.map { TauAdicNAF.digitString($0.generated) })

                Text("Ergebnis von Algorithmus B:").padding(.top, 4)
                lengthRow("Länge des reduzierten Schlüssels:", result?.reduced.count)
                field("Reduzierter Schlüssel (von MSB zu LSB):", result.map { TauAdicNAF.digitString($0.reduced) })

                Text("Ergebnis von Algorithmus C:").padding(.top, 4)
                lengthRow("Länge des regenerierten Schlüssels:", result?.regenerated.count)
                field("Der regenerierte t-adic-NAF-Schlüssel (von MSB zu LSB):", result.map { TauAdicNAF.digitString($0.regenerated) })

                HStack {
                    Text("Gesamte Rechenzeit:")
                    Text(result == nil ? "" : "\(milliseconds)").monospacedDigit().frame(minWidth: 60, alignment: .trailing)
                    Text("ms")
                }

                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("© 2009 – 2015 PhD Anastasios Kanakis")
                    Text("Danksagung: PhD M. H. Nabil, Dr. M. Benaissa und Prof. B. Esslinger")
                    Text("Department of EEE, University of Sheffield. Seit 2012 Teil von CrypTool.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                HStack {
                    Button("Ausgabe (key-out.txt) als Dokument öffnen") {
                        DocumentFactory.openResult(text: keyOut, title: "key-out.txt")
                    }
                    .disabled(keyOut.isEmpty)
                    Spacer()
                    Button("Dokumentation des Autors (PDF)") {
                        if let u = Resources.url("Help/de/files/tadicnafkeys/t-adicNAF.pdf") { NSWorkspace.shared.open(u) }
                    }
                    Button("Hilfe") { HelpCenter.show(topic: "hid_generation_tadic_naf_keys.html") }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 640, minHeight: 600)
    }

    private func lengthRow(_ label: String, _ value: Int?) -> some View {
        HStack {
            Text(label)
            Text(value.map(String.init) ?? "").monospacedDigit().frame(minWidth: 60, alignment: .trailing)
            Text("Bit")
        }
    }

    private func field(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            ResultBox(text: value ?? "", minHeight: 28)
        }
    }

    private func loadFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            Alerts.error("Die Datei „\(url.lastPathComponent)“ kann nicht geöffnet werden.")
            return
        }
        // The HTA uses the first line of the file.
        let text = TextCoding.string(from: [UInt8](data))
        let first = String(text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).first ?? "")
        loadedText = first
        keyText = first
        source = url.lastPathComponent
    }

    private func generate() {
        let a = aIsOne ? 1 : 0
        let start = Date()
        do {
            let r = try TauAdicNAF.generate(key: keyText, a: a)
            milliseconds = Int(Date().timeIntervalSince(start) * 1000)
            result = r
            keyOut += TauAdicNAF.keyOutText(r, source: source, milliseconds: milliseconds)
        } catch {
            result = nil
            Alerts.error(error.localizedDescription, title: "t-adic-NAF-Schlüsselgenerator")
        }
    }
}
