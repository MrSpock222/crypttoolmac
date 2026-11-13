import SwiftUI
import CTClassic

/// CT1's permanently visible read-in / permute / read-out radios of one permutation stage
/// (IDD_KEY_PERMUTATION): rows "Zeilenweise" / "Spaltenweise" × columns "einlesen" / "permutieren" / "auslesen".
struct PermutationStageGrid: View {
    @Binding var stage: PermutationOptions.Stage

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            row("line by line:", .rowWise)
            row("column by column:", .columnWise)
        }
    }

    private func row(_ title: String, _ d: PermutationOptions.Direction) -> some View {
        GridRow {
            Text(title).frame(width: 90, alignment: .trailing)
            CT1Radio(title: "Input", selected: stage.readIn == d) { stage.readIn = d }
            CT1Radio(title: "Permute", selected: stage.permute == d) { stage.permute = d }
            CT1Radio(title: "Output", selected: stage.readOut == d) { stage.readOut = d }
        }
    }
}

/// Both stages plus the "inverse" option (kept for callers that want a compact editor).
struct PermutationOptionsEditor: View {
    @Binding var options: PermutationOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1st Permutation").font(.caption)
            PermutationStageGrid(stage: $options.first)
            Text("2nd Permutation").font(.caption)
            PermutationStageGrid(stage: $options.second)
            Toggle("Apply the respective inverse permutation", isOn: $options.applyInverse)
        }
    }
}
