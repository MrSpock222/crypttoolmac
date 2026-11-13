import AppKit
import CTBigNum
import CTCommon
import SwiftUI

/// CT1's front end t-adicNAF.hta ("t-adic NAF GUI v1.3.3b", original English captions) for the generator
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
                Text("Transform a binary key into the t-adic NAF representation").font(.headline)
                Text("This tool requires two input parameters:")

                Text("1) The first parameter is the value 'a' of the Koblitz curve: y² + xy = x³ + a·x² + 1")
                Toggle(isOn: $aIsOne) { Text("(checked a=1; otherwise a=0)").italic() }
                    .padding(.leading, 16)

                Text("2) The second parameter is the binary form of the key as text (only the digits 0 and 1).")
                HStack {
                    TextField("", text: $keyText)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: keyText) { _, new in if new != loadedText { source = "input field" } }
                    Button("Load file...") { loadFile() }
                }
                .padding(.leading, 16)

                Button { generate() } label: {
                    Text("Click to generate t-adic NAF key").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Divider()
                Text("Input:").bold()
                lengthRow("Length of input key:", result?.key.count)
                field("Binary key from the most significant (MSB) to the least significant bit (LSB):", result?.key)

                Text("Output:").bold().padding(.top, 4)
                Text("Result of algorithm A:")
                lengthRow("Length of the generated key:", result?.generated.count)
                field("Generated 't-adic NAF' key (from MSB to LSB):", result.map { TauAdicNAF.digitString($0.generated) })

                Text("Result of algorithm B:").padding(.top, 4)
                lengthRow("Length of the reduced key:", result?.reduced.count)
                field("Reduced key (from MSB to LSB):", result.map { TauAdicNAF.digitString($0.reduced) })

                Text("Result of algorithm C:").padding(.top, 4)
                lengthRow("Length of the regenerated key:", result?.regenerated.count)
                field("The regenerated 't-adic NAF' key (from MSB to LSB):", result.map { TauAdicNAF.digitString($0.regenerated) })

                HStack {
                    Text("Total time for calculations:")
                    Text(result == nil ? "" : "\(milliseconds)").monospacedDigit().frame(minWidth: 60, alignment: .trailing)
                    Text("msec")
                }

                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("(c) 2009 - 2015 by PhD Anastasios Kanakis")
                    Text("Acknowledgement: PhD M. H. Nabil, Dr M. Benaissa, and Prof. B. Esslinger")
                    Text("Department of EEE, University of Sheffield. Part of CrypTool from 2012.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                HStack {
                    Button("Open output (key-out.txt) as document") {
                        DocumentFactory.openResult(text: keyOut, title: "key-out.txt")
                    }
                    .disabled(keyOut.isEmpty)
                    Spacer()
                    Button("Author's documentation (PDF)") {
                        if let u = Resources.url("Help/en/files/tadicnafkeys/t-adicNAF.pdf") { NSWorkspace.shared.open(u) }
                    }
                    Button("Help") { HelpCenter.show(topic: "hid_generation_tadic_naf_keys.html") }
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
            Text("bit")
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
            Alerts.error("The file \"\(url.lastPathComponent)\" could not be opened.")
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
            Alerts.error(error.localizedDescription, title: "t-adic NAF Key Generator")
        }
    }
}
