import Cocoa
import IOKit.ps
import SwiftUI

// MARK: - Timer Tiers

private enum TimerTier: Equatable {
    case slow    // > 30% or charging → 3600 s
    case medium  // 10–30%            → 1800 s
    case fast    // ≤ 10%             →  300 s

    var interval: TimeInterval {
        switch self {
        case .slow:   return 3600
        case .medium: return 1800
        case .fast:   return 300
        }
    }
}

// MARK: - Alert Overlay

final class AlertOverlayController {
    private var panel:       NSPanel?
    private var dismissWork: DispatchWorkItem?

    func show(level: Int) {
        guard panel == nil else { return }

        let view = AlertView(level: level) { [weak self] in self?.dismiss() }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 300)

        let p = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .screenSaver
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = hosting
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            p.setFrameOrigin(NSPoint(
                x: screen.frame.minX + (screen.frame.width  - hosting.frame.width)  / 2,
                y: screen.frame.minY + (screen.frame.height - hosting.frame.height) / 2
            ))
        }

        panel = p
        p.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - Battery Monitor

final class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int  = 100
    @Published var isCharging:   Bool = false
    @Published var isOnBattery:  Bool = false

    var threshold: Int = 5

    private var hasAlerted:  Bool      = false
    private var currentTier: TimerTier = .slow
    private var timer:       Timer?
    private let overlay = AlertOverlayController()

    init() {
        readBattery()
        scheduleTier(tierFor())
    }

    // MARK: Read

    func readBattery() {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
            let src  = list.first,
            let desc = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue()
                           as? [String: Any]
        else { return }

        batteryLevel = (desc[kIOPSCurrentCapacityKey as String] as? Int)  ?? batteryLevel
        isCharging   = (desc[kIOPSIsChargingKey       as String] as? Bool) ?? false
        let state    =  desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
        isOnBattery  = (state == (kIOPSBatteryPowerValue as String))

        checkAlertCondition()
        let newTier = tierFor()
        if newTier != currentTier { scheduleTier(newTier) }
    }

    // MARK: Alert logic

    private func checkAlertCondition() {
        if batteryLevel > threshold + 5 { hasAlerted = false }
        if batteryLevel <= threshold && !hasAlerted && isOnBattery {
            hasAlerted = true
            let level = batteryLevel
            DispatchQueue.main.async { [weak self] in self?.overlay.show(level: level) }
        }
    }

    // MARK: Timer

    private func tierFor() -> TimerTier {
        if isCharging || batteryLevel > 30 { return .slow   }
        if batteryLevel >= 10              { return .medium  }
        return .fast
    }

    private func scheduleTier(_ tier: TimerTier) {
        timer?.invalidate()
        currentTier = tier
        timer = Timer.scheduledTimer(withTimeInterval: tier.interval, repeats: true) { [weak self] _ in
            self?.readBattery()
        }
    }

    // MARK: Icon

    var iconName: String {
        batteryLevel <= 10 ? "drop.halffull" : "drop.fill"
    }
}

// MARK: - Alert View

struct AlertView: View {
    let level:     Int
    let onDismiss: () -> Void

    @State private var scale:   CGFloat = 0.88
    @State private var opacity: Double  = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 20)

            VStack(spacing: 14) {
                Image(systemName: "drop")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.orange)

                Text("\(level)%")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Battery Low")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button("Dismiss") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding(32)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                scale   = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var monitor: BatteryMonitor
    @AppStorage("threshold") private var threshold: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: monitor.iconName)
                Text("Battery: \(monitor.batteryLevel)%")
                    .fontWeight(.semibold)
            }
            Text(monitor.isOnBattery ? "On Battery" : "Charging")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Alert at: \(Int(threshold))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $threshold, in: 1...10, step: 1)
                    .onChange(of: threshold) { _, newValue in
                        monitor.threshold = Int(newValue)
                    }
            }

            Divider()

            Button("Quit Juice") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .padding(14)
        .frame(minWidth: 240)
        .onAppear {
            monitor.threshold = Int(threshold)
        }
    }
}

// MARK: - App Entry Point

@main
struct JuiceApp: App {
    @StateObject private var monitor = BatteryMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
        } label: {
            Image(systemName: monitor.iconName)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}
