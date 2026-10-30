import WidgetKit
import SwiftUI

// MARK: - Entry

struct VehicleEntry: TimelineEntry {
    let date: Date
    let snapshot: VehicleSnapshot
    let theme: WidgetTheme
}

// MARK: - Provider

struct VehicleProvider: TimelineProvider {

    func placeholder(in context: Context) -> VehicleEntry {
        VehicleEntry(date: Date(), snapshot: .placeholder, theme: SharedStore.theme())
    }

    func getSnapshot(in context: Context, completion: @escaping (VehicleEntry) -> Void) {
        completion(VehicleEntry(date: Date(),
                                snapshot: SharedStore.load() ?? .placeholder,
                                theme: SharedStore.theme()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VehicleEntry>) -> Void) {
        Task {
            var snap = SharedStore.load()

            let token = SharedStore.token()
            let vin = SharedStore.vin()
            let needFetch = snap == nil || (snap?.stale ?? true)

            if needFetch, let token, let vin, !token.isEmpty, !vin.isEmpty {
                if let fresh = try? await VehicleAPI(token: token, vin: vin).fetchStatus() {
                    SharedStore.save(fresh)
                    snap = fresh
                }
            }

            let entry = VehicleEntry(date: Date(),
                                     snapshot: snap ?? .placeholder,
                                     theme: SharedStore.theme())
            completion(Timeline(entries: [entry],
                                policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }
}

// MARK: - Widget

struct VehicleWidget: Widget {
    let kind = "VehicleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VehicleProvider()) { entry in
            VehicleWidgetView(entry: entry)
        }
        .configurationDisplayName("车况")
        .description("油量、续航、车门与空调状态")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - View

struct VehicleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: VehicleEntry

    private var s: VehicleSnapshot { entry.snapshot }
    private var t: WidgetTheme { entry.theme }

    var body: some View {
        ZStack {
            ThemeBackground(theme: t)
            content.padding(.horizontal, 14).padding(.vertical, 12)
        }
        .widgetURL(URL(string: "hondawidget://vehicle"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    // MARK: 小

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()

            Spacer(minLength: 4)

            EnergyNumber(snapshot: s, theme: t, size: 48)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("续航").font(t.font(9, .medium))
                Text("\(s.rangeKm)").font(t.font(13, .bold)).monospacedDigit()
                Text("km").font(t.font(9, .medium))
            }
            .foregroundStyle(t.secondary(scheme))
            .padding(.top, 1)

            Spacer(minLength: 6)

            ThinBar(percent: s.energyPercent, theme: t, height: 4)

            Spacer(minLength: 5)

            HStack(spacing: 0) {
                Text(timeText(s.updatedAt) + " 更新")
                    .font(t.font(8.5, .medium))
                    .foregroundStyle(t.secondary(scheme))
                Spacer(minLength: 4)
                Text(kindLabel)
                    .font(t.font(8.5, .medium))
                    .foregroundStyle(t.secondary(scheme))
            }
            .lineLimit(1)
        }
    }

    // MARK: 中

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(showTime: true)
                .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    EnergyNumber(snapshot: s, theme: t, size: 44)
                    Text(kindLabel)
                        .font(t.font(8.5, .medium))
                        .foregroundStyle(t.secondary(scheme))
                    ThinBar(percent: s.energyPercent, theme: t, height: 4)
                        .padding(.top, 1)
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(s.rangeKm)")
                            .font(t.font(17, .bold))
                            .monospacedDigit()
                        Text("km 续航")
                            .font(t.font(9, .medium))
                    }
                    .foregroundStyle(t.secondary(scheme))
                }
                .frame(width: 100, alignment: .leading)

                ThemeDivider(theme: t, vertical: true)

                Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        MetricCell(icon: s.doorsLocked ? "lock.fill" : "lock.open.fill",
                                   label: "车门",
                                   value: s.doorsLocked ? "已锁" : "未锁",
                                   theme: t,
                                   warn: !s.doorsLocked)
                        MetricCell(icon: s.windowsClosed ? "window.vertical.closed" : "window.vertical.open",
                                   label: "车窗",
                                   value: s.windowsClosed ? "已关" : "未关",
                                   theme: t,
                                   warn: !s.windowsClosed)
                    }
                    GridRow {
                        MetricCell(icon: "snowflake",
                                   label: "空调",
                                   value: s.acOn ? "开" : "关",
                                   theme: t,
                                   warn: s.acOn)
                        MetricCell(icon: "thermometer.medium",
                                   label: "车内",
                                   value: s.cabinTempC.map { String(format: "%.1f°", $0) } ?? "—",
                                   theme: t)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: 大

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(showTime: true)
                .padding(.bottom, 10)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                EnergyNumber(snapshot: s, theme: t, size: 62)

                VStack(alignment: .leading, spacing: 1) {
                    Text(kindLabel)
                        .font(t.font(9.5, .medium))
                        .foregroundStyle(t.secondary(scheme))
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(s.rangeKm)")
                            .font(t.font(19, .bold))
                            .monospacedDigit()
                        Text("km")
                            .font(t.font(9.5, .medium))
                    }
                    .foregroundStyle(t.secondary(scheme))
                }
                .padding(.bottom, 4)

                Spacer(minLength: 0)
            }

            ThinBar(percent: s.energyPercent, theme: t, height: 5)
                .padding(.top, 8)

            Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    MetricCell(icon: s.doorsLocked ? "lock.fill" : "lock.open.fill",
                               label: "车门",
                               value: s.doorsLocked ? "已锁" : "未锁",
                               theme: t,
                               warn: !s.doorsLocked)
                    MetricCell(icon: s.windowsClosed ? "window.vertical.closed" : "window.vertical.open",
                               label: "车窗",
                               value: s.windowsClosed ? "已关" : "未关",
                               theme: t,
                               warn: !s.windowsClosed)
                }
                GridRow {
                    MetricCell(icon: "snowflake",
                               label: "空调",
                               value: s.acOn ? "开" : "关",
                               theme: t,
                               warn: s.acOn)
                    MetricCell(icon: "thermometer.medium",
                               label: "车内",
                               value: s.cabinTempC.map { String(format: "%.1f°", $0) } ?? "—",
                               theme: t)
                }
            }
            .padding(.top, 12)

            ThemeDivider(theme: t)
                .padding(.vertical, 12)

            HStack(alignment: .top, spacing: 0) {
                stat("总里程", "\(s.odometerKm) km")
                stat("VIN 后六位", String(s.vin.suffix(6)))
                stat("数据来源", s.source.rawValue)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Text(timeText(s.updatedAt) + " 更新")
                    .font(t.font(9, .medium))
                    .monospacedDigit()
                    .foregroundStyle(t.secondary(scheme))
                Text("·")
                    .font(t.font(9, .medium))
                    .foregroundStyle(t.secondary(scheme).opacity(0.6))
                StatusBadge(text: s.stale ? "超过 30 分钟" : "数据新鲜",
                            theme: t,
                            warn: s.stale,
                            icon: s.stale ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                Spacer(minLength: 0)
                Text("点按打开")
                    .font(t.font(8.5, .medium))
                    .foregroundStyle(t.secondary(scheme).opacity(0.7))
            }
        }
    }

    // MARK: 公共

    private func header(showTime: Bool = false) -> some View {
        HStack(spacing: 5) {
            if t.showIcon { ThemeIcon(theme: t, size: 17) }

            Text(s.nickname)
                .font(t.font(10.5, .semibold))
                .foregroundStyle(t.primary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 2)

            if showTime {
                Text(timeText(s.updatedAt))
                    .font(t.font(9, .medium))
                    .monospacedDigit()
                    .foregroundStyle(t.secondary(scheme))
                    .lineLimit(1)
            }

            Image(systemName: s.doorsLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(s.doorsLocked ? t.secondary(scheme) : Color.orange)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(t.font(8.5, .medium))
                .foregroundStyle(t.secondary(scheme))
            Text(value)
                .font(t.font(14, .semibold))
                .foregroundStyle(t.primary(scheme))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kindLabel: String {
        switch s.energyKind {
        case .battery: return "电量"
        case .hybrid: return "油电混合"
        case .fuel: return "油量"
        }
    }

    /// "16:05"
    private func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private func relativeText(_ d: Date) -> String {
        let sec = Int(max(0, Date().timeIntervalSince(d)))
        if sec < 60 { return "刚刚" }
        if sec < 3600 { return "\(sec / 60) 分钟前" }
        if sec < 86400 { return "\(sec / 3600) 小时前" }
        return "\(sec / 86400) 天前"
    }
}

// MARK: - Preview（iOS 16 兼容写法）

struct VehicleWidget_Previews: PreviewProvider {
    static var previews: some View {
        VehicleWidgetView(entry: VehicleEntry(date: Date(), snapshot: .placeholder, theme: .midnight))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
