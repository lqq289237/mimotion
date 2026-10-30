import SwiftUI

// MARK: - 颜色

public struct RGB: Codable, Equatable, Hashable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    public static func hex(_ v: UInt32) -> RGB {
        RGB(Double((v >> 16) & 0xFF) / 255.0,
            Double((v >> 8) & 0xFF) / 255.0,
            Double(v & 0xFF) / 255.0)
    }

    public var color: Color { Color(red: r, green: g, blue: b) }
    public var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

/// 一套主题要同时兼容深浅色，所以每个颜色都是 dual
public struct DualColor: Codable, Equatable, Hashable {
    public var light: RGB
    public var dark: RGB

    public init(light: RGB, dark: RGB) {
        self.light = light; self.dark = dark
    }

    public init(_ hex: UInt32) {
        self.init(light: .hex(hex), dark: .hex(hex))
    }

    public func color(for scheme: ColorScheme) -> Color {
        (scheme == .dark ? dark : light).color
    }
}

// MARK: - 背景

public enum BackgroundStyle: Codable, Equatable {
    case solid(DualColor)
    case gradient(DualColor, DualColor)
    case image(blur: Double, dim: Double)
    case preset(String)
}

// MARK: - 字体

public enum FontDesignOption: String, CaseIterable, Codable, Identifiable {
    case rounded = "圆体"
    case system = "标准"
    case serif = "衬线"
    case monospaced = "等宽"

    public var id: String { rawValue }

    public var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .system: return .default
        }
    }
}

// MARK: - 主题

public struct WidgetTheme: Codable, Equatable {

    public var background: BackgroundStyle
    public var backgroundOpacity: Double        // 0.4...1

    public var iconSymbol: String
    public var iconTint: DualColor
    public var iconBadge: DualColor?
    public var showIcon: Bool

    public var autoTextColor: Bool
    public var textPrimary: DualColor
    public var textSecondary: DualColor

    public var accent: DualColor

    public var fontDesignRaw: String            // FontDesignOption.rawValue
    public var fontScale: Double                // 0.85...1.4

    public var fontDesign: FontDesignOption {
        get { FontDesignOption(rawValue: fontDesignRaw) ?? .rounded }
        set { fontDesignRaw = newValue.rawValue }
    }

    public init(background: BackgroundStyle = .gradient(DualColor(0x0B1E3A), DualColor(0x16324F)),
                backgroundOpacity: Double = 1.0,
                iconSymbol: String = "car.fill",
                iconTint: DualColor = DualColor(0xFFFFFF),
                iconBadge: DualColor? = nil,
                showIcon: Bool = true,
                autoTextColor: Bool = true,
                textPrimary: DualColor = DualColor(0xFFFFFF),
                textSecondary: DualColor = DualColor(0xFFFFFF),
                accent: DualColor = DualColor(0x4FC3F7),
                fontDesignRaw: String = FontDesignOption.rounded.rawValue,
                fontScale: Double = 1.0) {
        self.background = background
        self.backgroundOpacity = backgroundOpacity
        self.iconSymbol = iconSymbol
        self.iconTint = iconTint
        self.iconBadge = iconBadge
        self.showIcon = showIcon
        self.autoTextColor = autoTextColor
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.fontDesignRaw = fontDesignRaw
        self.fontScale = fontScale
    }

    // MARK: 字体

    /// 统一入口：所有文字都走这里，保证字号缩放生效
    public func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let clamped = min(max(fontScale, 0.8), 1.5)
        return .system(size: size * clamped, weight: weight, design: fontDesign.design)
    }

    // MARK: 取值

    public func primary(_ scheme: ColorScheme) -> Color {
        autoTextColor ? (scheme == .dark ? .white : .black) : textPrimary.color(for: scheme)
    }

    public func secondary(_ scheme: ColorScheme) -> Color {
        autoTextColor ? (scheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.52))
                      : textSecondary.color(for: scheme)
    }

    public func accentColor(_ scheme: ColorScheme) -> Color {
        accent.color(for: scheme)
    }
}

// MARK: - 向后兼容解码

extension WidgetTheme {
    private enum CodingKeys: String, CodingKey {
        case background, backgroundOpacity, iconSymbol, iconTint, iconBadge, showIcon
        case autoTextColor, textPrimary, textSecondary, accent
        case fontDesignRaw = "fontDesign"
        case fontScale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = try c.decode(BackgroundStyle.self, forKey: .background)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 1
        iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "car.fill"
        iconTint = try c.decodeIfPresent(DualColor.self, forKey: .iconTint) ?? DualColor(0xFFFFFF)
        iconBadge = try c.decodeIfPresent(DualColor.self, forKey: .iconBadge)
        showIcon = try c.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true
        autoTextColor = try c.decodeIfPresent(Bool.self, forKey: .autoTextColor) ?? true
        textPrimary = try c.decodeIfPresent(DualColor.self, forKey: .textPrimary) ?? DualColor(0xFFFFFF)
        textSecondary = try c.decodeIfPresent(DualColor.self, forKey: .textSecondary) ?? DualColor(0xFFFFFF)
        accent = try c.decodeIfPresent(DualColor.self, forKey: .accent) ?? DualColor(0x4FC3F7)
        fontDesignRaw = try c.decodeIfPresent(String.self, forKey: .fontDesignRaw) ?? FontDesignOption.rounded.rawValue
        fontScale = try c.decodeIfPresent(Double.self, forKey: .fontScale) ?? 1.0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(background, forKey: .background)
        try c.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try c.encode(iconSymbol, forKey: .iconSymbol)
        try c.encode(iconTint, forKey: .iconTint)
        try c.encodeIfPresent(iconBadge, forKey: .iconBadge)
        try c.encode(showIcon, forKey: .showIcon)
        try c.encode(autoTextColor, forKey: .autoTextColor)
        try c.encode(textPrimary, forKey: .textPrimary)
        try c.encode(textSecondary, forKey: .textSecondary)
        try c.encode(accent, forKey: .accent)
        try c.encode(fontDesignRaw, forKey: .fontDesignRaw)
        try c.encode(fontScale, forKey: .fontScale)
    }
}

// MARK: - 预设

extension WidgetTheme {

    public static let midnight = WidgetTheme(
        background: .gradient(DualColor(0x0A1628), DualColor(0x1B3A5C)),
        iconTint: DualColor(0x9BD8FF),
        accent: DualColor(0x4FC3F7))

    public static let carbon = WidgetTheme(
        background: .gradient(DualColor(0x1A1A1C), DualColor(0x35353A)),
        iconTint: DualColor(0xFFFFFF),
        accent: DualColor(0x30D158))

    public static let hondaRed = WidgetTheme(
        background: .gradient(DualColor(0x6E0F1C), DualColor(0xC0202F)),
        iconTint: DualColor(0xFFFFFF),
        accent: DualColor(0xFFD166))

    public static let lime = WidgetTheme(
        background: .solid(DualColor(0x0F2A1D)),
        iconTint: DualColor(0xB9F272),
        accent: DualColor(0xB9F272))

    public static let paper = WidgetTheme(
        background: .solid(DualColor(light: RGB.hex(0xFAFAFC), dark: RGB.hex(0x1C1C1E))),
        iconTint: DualColor(light: RGB.hex(0x1C1C1E), dark: RGB.hex(0xFFFFFF)),
        iconBadge: DualColor(light: RGB.hex(0xEDEDF0), dark: RGB.hex(0x2C2C2E)),
        accent: DualColor(light: RGB.hex(0xD6001C), dark: RGB.hex(0xFF453A)))

    public static let pureBlack = WidgetTheme(
        background: .solid(DualColor(0x000000)),
        iconTint: DualColor(0xFFFFFF),
        accent: DualColor(0xFFFFFF))

    public static var presets: [(String, WidgetTheme)] {
        [("午夜蓝", .midnight),
         ("碳灰", .carbon),
         ("本田红", .hondaRed),
         ("青柠", .lime),
         ("纸白", .paper),
         ("纯黑", .pureBlack)]
    }

    public static let symbols: [String] = [
        "car.fill", "car.side.fill", "car.rear.fill", "car.2.fill",
        "bolt.car.fill", "fuelpump.fill", "key.fill", "steeringwheel",
        "gauge.medium", "location.fill"
    ]

    public static func from(_ data: Data?) -> WidgetTheme {
        guard let data, let t = try? JSONDecoder().decode(WidgetTheme.self, from: data) else { return .midnight }
        return t
    }
}
