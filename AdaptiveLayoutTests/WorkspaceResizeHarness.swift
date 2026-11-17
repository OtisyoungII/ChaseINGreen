// Run with swiftc alongside WorkspaceLayoutPolicy.swift and WorkspaceCardLayout.swift.
// Synthetic data only; no app startup, authentication, provider, or order requests.
import AppKit
import SwiftUI

@MainActor private final class Probe {
    var appearances: [String: Set<UUID>] = [:]
    var values: [String: String] = [:]
}

private struct StatefulPanel: View {
    let name: String
    let probe: Probe
    @State private var identity = UUID()
    @State private var draft = ""
    @State private var broker = ""
    @State private var account = ""
    @State private var symbol = ""
    @State private var timeframe = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name).font(.headline)
            Text("\(broker) • \(account) • \(symbol) • \(timeframe)")
            Text("LONG 2 • Entry 100 • Mark 101 • P/L +2")
            TextField("Unfinished order", text: $draft)
            Button("Review — no order action") {}
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.15))
        .onAppear {
            broker = "Fixture provider"; account = "Account B"; symbol = "TEST"; timeframe = "M15"
            draft = "Draft quantity 7 / stop 95 / target 110"
            probe.appearances[name, default: []].insert(identity)
        }
        .onChange(of: [broker, account, symbol, timeframe, draft]) { _, value in probe.values[name] = value.joined(separator: "|") }
    }
}

private struct Harness: View {
    let probe: Probe
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Adaptive foundation — synthetic fixture").font(.title2)
                WorkspaceCardLayout {
                    ForEach(["Decision", "Active position", "Unfinished draft"], id: \.self) { name in
                        StatefulPanel(name: name, probe: probe)
                    }
                }
            }.padding()
        }.background(Color.white).foregroundStyle(.black)
    }
}

@main struct WorkspaceResizeHarness {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let probe = Probe()
        let host = NSHostingView(rootView: Harness(probe: probe).frame(width: 390, height: 844))
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 844),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, width, height) in [("compact", 390.0, 844.0), ("expanded", 1100, 800),
                                      ("narrow", 320, 650), ("split", 540, 700),
                                      ("short", 900, 400), ("compact-again", 390, 844)] {
            host.rootView = Harness(probe: probe).frame(width: width, height: height)
            window.setContentSize(NSSize(width: width, height: height))
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            precondition(host.bounds.width == width, "Host did not resize")
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            host.layoutSubtreeIfNeeded()
            precondition(host.bounds.width == width, "Layout changed requested container width")
            print("Verified container \(name): \(host.bounds.width) x \(host.bounds.height)")
            if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                if let png = bitmap.representation(using: .png, properties: [:]) {
                    try png.write(to: output.appendingPathComponent(name + ".png"))
                }
            }
            precondition(probe.appearances.count == 3, "Missing panels")
            precondition(probe.appearances.values.allSatisfy { $0.count == 1 }, "Resize reset child identity")
            precondition(probe.values.count == 3 && probe.values.values.allSatisfy { $0 == "Fixture provider|Account B|TEST|M15|Draft quantity 7 / stop 95 / target 110" }, "Draft changed")
        }
        print("PASS: six resize transitions; three child identities and unfinished drafts preserved. Synthetic screenshots saved.")
    }
}
