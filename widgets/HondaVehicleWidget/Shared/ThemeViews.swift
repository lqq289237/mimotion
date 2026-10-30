import SwiftUI
import UIKit

// MARK: - 背景

struct ThemeBackground: View {
    let theme: WidgetTheme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            base

            if case let .image(blur, dim) = theme.background, let ui = backgroundImage() {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: blur)
                Color.black.opacity(dim)
            }
        }
        .opacity(theme.backgroundOpacity)
    }

    /// 读取背景图：共享目录文件 → App Group 文件 → 打包进 bundle 的资源
    private func backgroundImage() -> UIImage? {
        if let path = SharedStore.themeImagePath,
           FileManager.default.fileExists(atPath: path),
           let ui = UIImage(contentsOfFile: path) {
            return ui
        }
        if !FallbackTheme.bgImageName.isEmpty,
           let ui = UIImage(named: FallbackTheme.bgImageName) {
            return ui
        }
        return nil
    }

    @ViewBuilder
    private var base: some View {
        switch theme.background {
        case .solid(let c):
            c.color(for: scheme)
        case .gradient(let a, let b):
            LinearGradient(colors: [a.color(for: scheme), b.color(for: scheme)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        case .image:
            LinearGradient(colors: [Color(white: 0.10), Color(white: 0.26)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        case .preset(let name):
            Color(white: name.isEmpty ? 0.12 : 0.18)
        }
    }
}

// MARK: - 图标

struct ThemeIcon: View {
    let theme: WidgetTheme
    let size: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if let badge = theme.iconBadge {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(badge.color(for: scheme))
            }
            Image(systemName: theme.iconSymbol)
                .font(.system(size: size * 0.54, weight: .semibold))
                .foregroundStyle(theme.iconTint.color(for: scheme))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 大数字能源

struct EnergyNumber: View {
    let snapshot: VehicleSnapshot
    let theme: WidgetTheme
    var size: CGFloat = 46
    var showUnit = true
    @Environment(\.colorScheme) private var scheme

    private var color: Color {
        snapshot.energyPercent < 0.15 ? .red : theme.primary(scheme)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(Int((snapshot.energyPercent * 100).rounded()))")
                .font(theme.font(size, .heavy))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if showUnit {
                Text("%")
                    .font(theme.font(size * 0.42, .semibold))
                    .foregroundStyle(theme.secondary(scheme))
            }
        }
    }
}

// MARK: - 细进度条

struct ThinBar: View {
    let percent: Double
    let theme: WidgetTheme
    var height: CGFloat = 4
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.secondary(scheme).opacity(0.20))
                Capsule()
                    .fill(percent < 0.15 ? Color.red : theme.accentColor(scheme))
                    .frame(width: max(height, geo.size.width * min(max(percent, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - 指标格（两行：小标签 + 大值）

struct MetricCell: View {
    let icon: String
    let label: String
    let value: String
    let theme: WidgetTheme
    var warn: Bool = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(label)
                    .font(theme.font(8.5, .medium))
            }
            .foregroundStyle(warn ? Color.orange : theme.secondary(scheme))

            Text(value)
                .font(theme.font(14.5, .semibold))
                .foregroundStyle(theme.primary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - 分隔线

struct ThemeDivider: View {
    let theme: WidgetTheme
    @Environment(\.colorScheme) private var scheme
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(theme.secondary(scheme).opacity(0.18))
            .frame(width: vertical ? 0.5 : nil, height: vertical ? 28 : 0.5)
    }
}

// MARK: - 状态徽标

struct StatusBadge: View {
    let text: String
    let theme: WidgetTheme
    var warn: Bool = false
    var icon: String = "checkmark.circle.fill"
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(theme.font(8.5, .medium))
        }
        .foregroundStyle(warn ? Color.orange : theme.secondary(scheme))
        .lineLimit(1)
    }
}
