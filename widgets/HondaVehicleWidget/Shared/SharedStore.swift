import Foundation

/// App 与 Widget 共享状态。
///
/// 读写优先级（自动探测，越狱机可写共享目录时最优）：
///   1. /var/mobile/Library/com.yg.hondawidget/state.json    ← 越狱 / TrollStore 环境
///   2. App Group UserDefaults                              ← 正式签名
///   3. 各自沙盒 UserDefaults                                ← 兜底
public struct SharedState: Codable {
    public var snapshot: VehicleSnapshot?
    public var token: String?
    public var vin: String?
    public var theme: WidgetTheme?
}

public enum SharedStore {

    public static let appGroup = "group.com.yg.hondawidget"
    public static let bridgePlist = "/var/mobile/Library/Preferences/com.yg.hondawidget.status.plist"

    /// 越狱设备上的共享目录（App 与 Widget 都能读写）
    public static let sharedDirPath = "/var/mobile/Library/com.yg.hondawidget"

    private static let stateFileName = "state.json"
    private static let imageFileName = "bg.jpg"
    private static let themeImageName = "theme-background.jpg"

    private static let statusKey = "vehicle.snapshot"
    private static let tokenKey  = "vehicle.token"
    private static let vinKey    = "vehicle.vin"
    private static let themeKey  = "widget.theme"

    // MARK: - 目录探测

    /// 首次访问时探测共享目录是否可写（越狱机通常可以）
    private static let resolvedDir: URL? = {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: sharedDirPath, isDirectory: true)
        if !fm.fileExists(atPath: sharedDirPath) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let probe = url.appendingPathComponent(".probe")
        do {
            try Data("1".utf8).write(to: probe, options: .atomic)
            try? fm.removeItem(at: probe)
            return url
        } catch {
            return nil
        }
    }()

    public static var sharedDirURL: URL? { resolvedDir }

    private static var stateURL: URL? { resolvedDir?.appendingPathComponent(stateFileName) }
    private static var imageURL: URL? { resolvedDir?.appendingPathComponent(imageFileName) }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    // MARK: - 状态读写

    private static func readState() -> SharedState {
        if let url = stateURL,
           let data = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode(SharedState.self, from: data) {
            return s
        }
        var s = SharedState()
        s.token = defaults.string(forKey: tokenKey)
        s.vin = defaults.string(forKey: vinKey)
        if let d = defaults.data(forKey: statusKey) {
            s.snapshot = try? JSONDecoder().decode(VehicleSnapshot.self, from: d)
        }
        if let d = defaults.data(forKey: themeKey) {
            s.theme = try? JSONDecoder().decode(WidgetTheme.self, from: d)
        }
        return s
    }

    private static func write(_ s: SharedState) {
        if let url = stateURL, let data = try? JSONEncoder().encode(s) {
            try? data.write(to: url, options: .atomic)
        }
        if let snap = s.snapshot, let d = try? JSONEncoder().encode(snap) {
            defaults.set(d, forKey: statusKey)
        }
        if let t = s.token { defaults.set(t, forKey: tokenKey) }
        if let v = s.vin { defaults.set(v, forKey: vinKey) }
        if let th = s.theme, let d = try? JSONEncoder().encode(th) {
            defaults.set(d, forKey: themeKey)
        }
        defaults.synchronize()
    }

    // MARK: - 快照

    public static func save(_ snapshot: VehicleSnapshot) {
        var s = readState()
        s.snapshot = snapshot
        write(s)
    }

    public static func load() -> VehicleSnapshot? {
        if let snap = readState().snapshot { return snap }
        if let dict = NSDictionary(contentsOfFile: bridgePlist) as? [String: Any],
           let s = VehicleSnapshot.bridgeDictionary(dict) {
            return s
        }
        return nil
    }

    // MARK: - 主题

    public static func theme() -> WidgetTheme {
        readState().theme ?? FallbackTheme.theme
    }

    public static func saveTheme(_ theme: WidgetTheme) {
        var s = readState()
        s.theme = theme
        write(s)
    }

    // MARK: - 背景图

    public static var themeImagePath: String? {
        if let p = imageURL?.path, FileManager.default.fileExists(atPath: p) {
            return p
        }
        if let p = containerURL?.appendingPathComponent(themeImageName).path,
           FileManager.default.fileExists(atPath: p) {
            return p
        }
        return nil
    }

    @discardableResult
    public static func saveThemeImage(_ jpeg: Data) -> Bool {
        if let url = imageURL {
            do { try jpeg.write(to: url, options: .atomic); return true } catch {}
        }
        if let url = containerURL?.appendingPathComponent(themeImageName) {
            do { try jpeg.write(to: url, options: .atomic); return true } catch {}
        }
        return false
    }

    public static func removeThemeImage() {
        if let url = imageURL { try? FileManager.default.removeItem(at: url) }
        if let url = containerURL?.appendingPathComponent(themeImageName) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func hasThemeImage() -> Bool {
        themeImagePath != nil
    }

    // MARK: - 凭据

    public static func token() -> String? {
        if let t = readState().token, !t.isEmpty { return t }
        return FallbackCredentials.token
    }

    public static func setToken(_ t: String?) {
        var s = readState()
        s.token = t
        write(s)
    }

    public static func vin() -> String? {
        if let v = readState().vin, !v.isEmpty { return v }
        return FallbackCredentials.vin
    }

    public static func setVin(_ v: String?) {
        var s = readState()
        s.vin = v
        write(s)
    }

    public static var deviceID: String {
        if let id = defaults.string(forKey: "device.id") { return id }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        defaults.set(id, forKey: "device.id")
        defaults.synchronize()
        return id
    }
}

extension VehicleSnapshot {
    /// 把 tweak 写出的 [String: Any] 转成模型，字段名与 TokenBridge/Tweak.x 保持一致
    public static func bridgeDictionary(_ d: [String: Any]) -> VehicleSnapshot? {
        guard let vin = d["vin"] as? String else { return nil }
        let ts = (d["ts"] as? Double) ?? Date().timeIntervalSince1970
        return VehicleSnapshot(
            vin: vin,
            nickname: (d["nickname"] as? String) ?? "我的车",
            modelName: (d["modelName"] as? String) ?? "",
            energyPercent: (d["energy"] as? Double) ?? 0,
            energyKind: EnergyKind(rawValue: (d["energyKind"] as? String) ?? "fuel") ?? .fuel,
            rangeKm: (d["range"] as? Int) ?? 0,
            odometerKm: (d["odometer"] as? Int) ?? 0,
            doorsLocked: (d["doorsLocked"] as? Bool) ?? true,
            windowsClosed: (d["windowsClosed"] as? Bool) ?? true,
            trunkClosed: (d["trunkClosed"] as? Bool) ?? true,
            acOn: (d["acOn"] as? Bool) ?? false,
            cabinTempC: d["cabinTemp"] as? Double,
            updatedAt: Date(timeIntervalSince1970: ts),
            source: .bridge)
    }
}
