import WidgetKit
import SwiftUI

@main
struct VehicleWidgetBundle: WidgetBundle {
    var body: some Widget {
        VehicleWidget()
        LockScreenWidget()
    }
}

// MARK: - 锁屏（iOS 16+）

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let snapshot: VehicleSnapshot
    let theme: WidgetTheme
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), snapshot: .placeholder, theme: SharedStore.theme())
    }
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(LockScreenEntry(date: Date(),
                                   snapshot: SharedStore.load() ?? .placeholder,
                                   theme: SharedStore.theme()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let entry = LockScreenEntry(date: Date(),
                                    snapshot: SharedStore.load() ?? .placeholder,
                                    theme: SharedStore.theme())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct LockScreenWidget: Widget {
    let kind = "LockScreenVehicleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenView(entry: entry)
        }
        .configurationDisplayName("车况（锁屏）")
        .description("锁屏上一眼看到油量与锁车状态")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: LockScreenEntry

    // 锁屏走系统 vibrancy：fullColor 用主题色，accented 退回单色
    private var tint: Color {
        switch renderingMode {
        case .fullColor: return entry.theme.accentColor(.dark)
        case .accented:  return .white
        default:         return .primary
        }
    }

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            Gauge(value: s.energyPercent) {
                Image(systemName: s.energyKind == .battery ? "bolt.fill" : "fuelpump.fill")
            } currentValueLabel: {
                Text(s.energyText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)

        case .accessoryInline:
            Label("\(s.energyText) · \(s.rangeKm) km · \(s.doorsLocked ? "已锁" : "未锁")",
                  systemImage: s.doorsLocked ? "lock.fill" : "lock.open.fill")

        default:
            HStack(spacing: 8) {
                Image(systemName: s.doorsLocked ? "car.fill" : "car.side.fill")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(s.energyText)  续航 \(s.rangeKm) km")
                        .font(.system(size: 12, weight: .semibold))
                    Text(s.updatedAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview（iOS 16 兼容写法）

struct LockScreenWidget_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenView(entry: LockScreenEntry(date: Date(), snapshot: .placeholder, theme: .midnight))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
