import Foundation

/// 没有 App Group（免费签名 / 未签名 ipa）时的兜底凭据。
/// 把抓包拿到的值填进来，重新编译一次，widget 就能自己拉数据。
///
/// 免费账号签名会剥掉 App Group entitlement，导致 App 与 Widget 无法共享
/// UserDefaults；这种情况下只有硬编码才能让 widget 拿到 token。
public enum FallbackCredentials {
    /// 例如 "eyJhbGciOiJIUzI1NiIs..."
    public static let token: String? = nil
    /// 例如 "LHGCM82633A000000"
    public static let vin: String? = nil

    /// 演示模式：没有 token 时 widget 显示占位数据，方便先看排版
    public static var isDemo: Bool { token == nil || token?.isEmpty == true }
}
