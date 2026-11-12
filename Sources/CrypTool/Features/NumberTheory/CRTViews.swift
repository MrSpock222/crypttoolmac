import SwiftUI

// CT1-aligned CRT dialogs; implementations in Features/CT1NumberTheory/CRT*.swift.

/// Einzelverfahren ▸ Chinesischer Restsatz ▸ Astronomie und Planetenbewegung (CT1 IDD_CRT_ASTRONOMY).
struct CRTAstronomyView: View {
    var body: some View { CT1CRTAstronomyDialog() }
}

/// Einzelverfahren ▸ Chinesischer Restsatz ▸ Modulare Hin- und Rücktransformation (CT1 IDD_CRT_TRANSFORMATION).
struct CRTTransformationView: View {
    var body: some View { CT1CRTTransformationDialog() }
}

/// Einzelverfahren ▸ Chinesischer Restsatz ▸ Secret-Sharing mittels CRT (CT1 IDD_CRT_SECRETSHARING).
struct CRTSecretSharingView: View {
    var body: some View { CT1CRTSecretSharingDialog() }
}
