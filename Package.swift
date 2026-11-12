// swift-tools-version:5.9
//
// CrypTool for macOS – native Apple-Silicon port of CrypTool 1 (CT1).
//
// Module layout:
//   CTCommon    – shared types (text options, hex helpers, cancellation)
//   CTBigNum    – arbitrary precision integers, number theory, RSA, ECC, PRNGs
//   CTCipherC   – original ANSI-C reference code of the AES candidates (MARS, RC6, Serpent, Twofish)
//   CTModern    – modern symmetric ciphers, hashes, MACs, encodings, ASN.1, ZIP
//   CTClassic   – classical ciphers (Caesar … Enigma) and known-plaintext analyses
//   CTAnalysis  – statistical analysis, ciphertext-only attacks, randomness tests, password tools
//   CrypTool    – the AppKit/SwiftUI application
//
// Tests are plain executables (`swift run -c release CTBigNumTests` …) because the
// Command Line Tools ship neither XCTest nor the swift-testing macro plugin.

import PackageDescription

let package = Package(
    name: "CrypTool",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CrypTool", targets: ["CrypTool"]),
    ],
    targets: [
        .target(name: "CTCommon"),
        .target(name: "CTBigNum", dependencies: ["CTCommon"]),
        .target(
            name: "CTCipherC",
            cSettings: [
                .unsafeFlags(["-Wno-everything"]),
            ]
        ),
        .target(name: "CTModern", dependencies: ["CTCommon", "CTCipherC"]),
        .target(name: "CTClassic", dependencies: ["CTCommon"]),
        .target(name: "CTAnalysis", dependencies: ["CTCommon"]),
        .executableTarget(
            name: "CrypTool",
            dependencies: ["CTCommon", "CTBigNum", "CTModern", "CTClassic", "CTAnalysis"]
        ),

        // Test runners (executables, see header comment)
        .executableTarget(name: "CTBigNumTests", dependencies: ["CTCommon", "CTBigNum"], path: "Tests/CTBigNumTests"),
        .executableTarget(name: "CTLatticeTests", dependencies: ["CTCommon", "CTBigNum"], path: "Tests/CTLatticeTests"),
        .executableTarget(name: "CTModernTests", dependencies: ["CTCommon", "CTModern"], path: "Tests/CTModernTests"),
        .executableTarget(name: "CTClassicTests", dependencies: ["CTCommon", "CTClassic"], path: "Tests/CTClassicTests"),
        .executableTarget(name: "CTAnalysisTests", dependencies: ["CTCommon", "CTAnalysis"], path: "Tests/CTAnalysisTests"),
    ]
)
