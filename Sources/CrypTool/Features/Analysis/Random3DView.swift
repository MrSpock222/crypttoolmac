import AppKit
import SwiftUI
import SceneKit
import CTAnalysis

/// CT1 "3D-Visualisierung" (OpenGLDoc/StreamToVolume): the differences of consecutive words
/// (1, 2 or 4 bytes) form points in a cube; every hit makes the voxel brighter ("Dichte").
/// Good random data fills the cube uniformly; weak generators show planes or patterns.
/// The parameters are set in CT1's dialog "3D-Visualisierung - Optionen".
struct Random3DView: View {
    let document: CTDocument
    @AppStorage("ct1.3d.resolution") private var resolution = CT1Volume.defaultResolution
    @AppStorage("ct1.3d.density") private var density = CT1Volume.defaultDensity
    @AppStorage("ct1.3d.shift") private var shift = CT1Volume.defaultShift
    @AppStorage("ct1.3d.wordLength") private var wordLength = CT1Volume.defaultWordLength
    @CTState private var showBox = true
    @CTState private var showOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Auflösung \(resolution), Dichte \(density), Verschiebung \(shift) %, Wortlänge \(wordLength) Byte – <\(document.shortName)>")
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Würfel anzeigen", isOn: $showBox)
                Button("Optionen …") { showOptions = true }
            }
            PointCloudView(bytes: document.bytes, resolution: resolution, density: density, shift: shift,
                           wordLength: wordLength, showBox: showBox)
            Text("Mit der Maus drehen, mit Scrollen/Pinch zoomen. Je drei aufeinanderfolgende Differenzen benachbarter Wörter ergeben einen Punkt; häufig getroffene Punkte erscheinen heller.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .sheet(isPresented: $showOptions) {
            Visualization3DOptionsView(resolution: $resolution, density: $density, shift: $shift,
                                       wordLength: $wordLength, close: { showOptions = false })
        }
    }
}

/// CT1 IDD_SET_VISOPT "3D-Visualisierung - Optionen".
struct Visualization3DOptionsView: View {
    @Binding var resolution: Int
    @Binding var density: Int
    @Binding var shift: Int
    @Binding var wordLength: Int
    let close: () -> Void
    @CTState private var res = 128.0
    @CTState private var dens = 127.0
    @CTState private var sh = 50.0
    @CTState private var word = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D-Visualisierung - Optionen").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Auflösung:")
                    Slider(value: $res, in: 64...255, step: 1).frame(width: 200)
                    Text("\(Int(res))").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                GridRow {
                    Text("Dichte:")
                    Slider(value: $dens, in: 1...255, step: 1).frame(width: 200)
                    Text("\(Int(dens))").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                GridRow {
                    Text("Verschiebung:")
                    Slider(value: $sh, in: 0...50, step: 1).frame(width: 200)
                    Text("\(Int(sh))").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }
            GroupBox("Analyseparameter") {
                HStack {
                    Text("Wortlänge (in Bytes):")
                    Picker("", selection: $word) {
                        Text("1").tag(1); Text("2").tag(2); Text("4").tag(4)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Reset") {
                    res = Double(CT1Volume.defaultResolution); dens = Double(CT1Volume.defaultDensity)
                    sh = Double(CT1Volume.defaultShift); word = CT1Volume.defaultWordLength
                }
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
                Button("OK") {
                    resolution = Int(res); density = Int(dens); shift = Int(sh); wordLength = word
                    close()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear {
            res = Double(resolution); dens = Double(density); sh = Double(shift); word = wordLength
        }
    }
}

private struct PointCloudView: NSViewRepresentable {
    let bytes: [UInt8]
    let resolution: Int
    let density: Int
    let shift: Int
    let wordLength: Int
    let showBox: Bool

    final class Coordinator { var key = "" }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .black
        return v
    }

    func updateNSView(_ v: SCNView, context: Context) {
        let key = "\(bytes.count)-\(resolution)-\(density)-\(shift)-\(wordLength)-\(showBox)"
        guard key != context.coordinator.key else { return }
        context.coordinator.key = key
        v.scene = makeScene()
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        let res = max(1, min(resolution, 255))
        let volume = CT1Volume.volume(bytes, resolution: res, density: density, shiftPercent: shift, wordLength: wordLength)
        var vertices: [SCNVector3] = []
        var colors: [SCNVector3] = []
        let r = CGFloat(res)
        for addr in 0..<volume.count where volume[addr] != 0 {
            let x = addr % res, y = (addr / res) % res, z = addr / (res * res)
            vertices.append(SCNVector3(CGFloat(x) / r - 0.5, CGFloat(y) / r - 0.5, CGFloat(z) / r - 0.5))
            let b = 0.25 + 0.75 * CGFloat(volume[addr]) / 255
            colors.append(SCNVector3(b, b, b))
        }
        let count = vertices.count
        if count > 0 {
            let src = SCNGeometrySource(vertices: vertices)
            let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
            let colorSrc = SCNGeometrySource(data: colorData, semantic: .color, vectorCount: colors.count, usesFloatComponents: true,
                                             componentsPerVector: 3, bytesPerComponent: MemoryLayout<CGFloat>.size, dataOffset: 0,
                                             dataStride: MemoryLayout<SCNVector3>.stride)
            let indices = (0..<Int32(count)).map { $0 }
            let element = SCNGeometryElement(indices: indices, primitiveType: .point)
            element.pointSize = 2
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = 3
            let geo = SCNGeometry(sources: [src, colorSrc], elements: [element])
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            geo.materials = [mat]
            scene.rootNode.addChildNode(SCNNode(geometry: geo))
        }
        if showBox {
            let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = NSColor.gray
            m.lightingModel = .constant
            box.materials = [m]
            scene.rootNode.addChildNode(SCNNode(geometry: box))
        }
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(1.4, 1.1, 1.8)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)
        return scene
    }
}
