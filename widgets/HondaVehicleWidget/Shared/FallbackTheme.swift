import SwiftUI

/// 没有 App Group（未签名 ipa / 免费签名）时，主题与字体从这里读。
/// 改完重新编译一次即可生效 —— 这条路径不依赖主 App。
public enum FallbackTheme {

    // MARK: 配色

    /// "midnight" / "carbon" / "hondaRed" / "lime" / "paper" / "black"
    public static let preset = "midnight"

    /// 任意 SF Symbol，例如 car.fill / car.side.fill / bolt.car.fill / key.fill
    public static let iconSymbol = "car.fill"
    public static let showIcon = true
    public static let backgroundOpacity = 1.0

    // MARK: 字体

    /// "rounded"（圆体，默认）/ "system"（标准）/ "serif"（衬线）/ "monospaced"（等宽）
    public static let fontDesign = "rounded"

    /// 全局字号缩放：0.85 ~ 1.5，想要字更大就加到 1.2 / 1.3
    public static let fontScale = 1.15

    /// 打包进 App 的背景图名（放在 Shared/ 下的图片，不带扩展名）
    /// 例如把 Shared/bg.jpg 放进去，这里填 "bg"
    public static let bgImageName = "bg"

    /// 打包图的模糊与压暗
    public static let bgBlur = 2.0
    public static let bgDim = 0.45

    // MARK: 生成

    public static var theme: WidgetTheme {
        var t: WidgetTheme
        switch preset {
        case "carbon":   t = .carbon
        case "hondaRed": t = .hondaRed
        case "lime":     t = .lime
        case "paper":    t = .paper
        case "black":    t = .pureBlack
        default:         t = .midnight
        }
        t.iconSymbol = iconSymbol
        t.showIcon = showIcon
        t.backgroundOpacity = backgroundOpacity
        t.fontDesignRaw = fontDesign
        t.fontScale = fontScale
        if !bgImageName.isEmpty {
            t.background = .image(blur: bgBlur, dim: bgDim)
        }
        return t
    }
}
