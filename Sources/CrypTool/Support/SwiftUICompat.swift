import SwiftUI

/// The Command Line Tools SDK declares `@State` as a macro but does not ship the
/// SwiftUIMacros compiler plugin. Using the property wrapper through a typealias avoids
/// macro expansion, so the app builds without a full Xcode installation.
typealias CTState = SwiftUI.State
