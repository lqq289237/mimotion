import Foundation

/// 车况接口客户端
/// 真实字段名靠抓包确认后，只改 KeyMap，不动解析逻辑
public struct VehicleAPI {

    /// 抓包把 HOST 填进来，例如 https://[API_HOST]
    public static var host = "https://[API_HOST]"
    /// 车况查询路径，例如 "/iov/vehicle/status"
    public static var statusPath = "/[ENDPOINT]"

    public enum APIError: Error {
        case badResponse(Int)
        case decode
        case unauthorized
    }

    public var token: String
    public var vin: String
    private let session: URLSession

    public init(token: String, vin: String) {
        self.token = token
        self.vin = vin
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - 请求

    public func fetchStatus() async throws -> VehicleSnapshot {
        guard let base = URL(string: Self.host) else { throw APIError.decode }
        var req = URLRequest(url: base.appendingPathComponent(Self.statusPath))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "token")
        req.setValue(SharedStore.deviceID, forHTTPHeaderField: "deviceId")
        req.setValue("IOS", forHTTPHeaderField: "platform")

        let body: [String: Any] = [
            "vin": vin,
            "ts": Int(Date().timeIntervalSince1970 * 1000)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if code == 401 || code == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(code) else { throw APIError.badResponse(code) }

        return try Self.parse(data, vin: vin)
    }

    // MARK: - 字段映射（抓包后改这里）

    public enum KeyMap {
        public static let energy    = ["oilPercent", "fuelPercent", "soc", "batteryLevel", "oil"]
        public static let range     = ["range", "endurance", "remainRange", "evRange", "fuelRange"]
        public static let odometer  = ["odometer", "mileage", "totalMileage", "odo"]
        public static let doors     = ["doorLock", "lockStatus", "doorsLocked", "lockState"]
        public static let windows   = ["windowStatus", "windowsClosed", "windowState"]
        public static let trunk     = ["trunkStatus", "trunkClosed", "tailBox"]
        public static let ac        = ["acStatus", "acOn", "climateOn", "airCondition"]
        public static let cabinTemp = ["inTemp", "cabinTemp", "insideTemp", "innerTemp"]
        public static let nickname  = ["nickName", "vehicleName", "carName", "alias"]
        public static let model     = ["modelName", "seriesName", "vehicleModel"]
        public static let energyKind = ["energyType", "powerType", "fuelType"]
    }

    public static func parse(_ data: Data, vin: String) throws -> VehicleSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { throw APIError.decode }

        func dig(_ keys: [String]) -> Any? {
            func walk(_ any: Any) -> Any? {
                if let d = any as? [String: Any] {
                    for k in keys where d[k] != nil { return d[k] }
                    for (_, v) in d { if let r = walk(v) { return r } }
                } else if let a = any as? [Any] {
                    for v in a { if let r = walk(v) { return r } }
                }
                return nil
            }
            return walk(root)
        }

        func num(_ keys: [String]) -> Double? {
            guard let v = dig(keys) else { return nil }
            if let n = v as? NSNumber { return n.doubleValue }
            if let s = v as? String { return Double(s) }
            return nil
        }

        func bool(_ keys: [String]) -> Bool? {
            guard let v = dig(keys) else { return nil }
            if let n = v as? NSNumber { return n.boolValue }
            if let s = v as? String {
                return ["1", "true", "locked", "closed", "on"].contains(s.lowercased())
            }
            return nil
        }

        func str(_ keys: [String]) -> String? {
            guard let v = dig(keys) else { return nil }
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return nil
        }

        var energy = num(KeyMap.energy).map { $0 > 1 ? $0 / 100.0 : $0 } ?? 0
        energy = min(max(energy, 0), 1)

        let kindRaw = (str(KeyMap.energyKind) ?? "").lowercased()
        let kind: VehicleSnapshot.EnergyKind =
            kindRaw.contains("电") || kindRaw.contains("ev") || kindRaw.contains("batt") ? .battery :
            kindRaw.contains("混") || kindRaw.contains("hybrid")                   ? .hybrid  : .fuel

        return VehicleSnapshot(
            vin: vin,
            nickname: str(KeyMap.nickname) ?? "我的车",
            modelName: str(KeyMap.model) ?? "",
            energyPercent: energy,
            energyKind: kind,
            rangeKm: Int(num(KeyMap.range) ?? 0),
            odometerKm: Int(num(KeyMap.odometer) ?? 0),
            doorsLocked: bool(KeyMap.doors) ?? true,
            windowsClosed: bool(KeyMap.windows) ?? true,
            trunkClosed: bool(KeyMap.trunk) ?? true,
            acOn: bool(KeyMap.ac) ?? false,
            cabinTempC: num(KeyMap.cabinTemp),
            updatedAt: Date(),
            source: .widget
        )
    }
}
