import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// DEBUG-only, non-sensitive process diagnostics for physical-device profiling.
@MainActor
final class ReleaseHealthDiagnostics {
    static let shared = ReleaseHealthDiagnostics()
    private var memoryWarningCount = 0
    private var observers: [NSObjectProtocol] = []

    private init() {
        #if canImport(UIKit)
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.memoryWarningCount += 1
                self?.sample(reason: "memory-warning", scene: nil)
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sample(reason: "thermal-change", scene: nil) }
        })
        #endif
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func sample(reason: String, scene: String?) {
        #if DEBUG
        let resident = residentMemoryBytes().map { String($0 / 1_048_576) } ?? "unknown"
        print("[ReleaseHealth] reason=\(reason) scene=\(scene ?? "unchanged") "
            + "residentMB=\(resident) thermal=\(thermalLabel) memoryWarnings=\(memoryWarningCount) "
            + "activeRefreshOwners=\(AppRefreshCoordinator.shared.diagnosticActiveWorkSummary())")
        #endif
    }

    func chartState(surface: String, timeframe: String, candles: Int, annotations: Int) {
        #if DEBUG
        print("[ReleaseHealth] chartSurface=\(surface) timeframe=\(timeframe) "
            + "candles=\(candles) annotations=\(annotations)")
        #endif
    }

    private var thermalLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func residentMemoryBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : nil
    }
}
