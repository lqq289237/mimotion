import Foundation

/// 车辆状态快照 —— App 与 Widget 共享的唯一数据模型
/// 字段名与车厂接口不一致时，只在 VehicleAPI.KeyMap 里改，不动这里
public struct VehicleSnapshot: Codable, Equatable, Identifiable {
    public var id: String { vin }

    public var vin: String
    public var nickname: String          // "我的雅阁"
    public var modelName: String         // "英仕派 e:HEV"

    public var energyPercent: Double     // 0...1 油量或电量
    public var energyKind: EnergyKind    // 油 / 电 / 混动
    public var rangeKm: Int              // 剩余续航
    public var odometerKm: Int           // 总里程

    public var doorsLocked: Bool         // true = 已锁
    public var windowsClosed: Bool
    public var trunkClosed: Bool
    public var acOn: Bool
    public var cabinTempC: Double?       // 车内温度，未上报为 nil

    public var updatedAt: Date
    public var source: Source            // 数据来源，用于 UI 角标

    public enum EnergyKind: String, Codable { case fuel, battery, hybrid }
    public enum Source: String, Codable { case app, widget, bridge }

    public init(vin: String,
                nickname: String = "我的车",
                modelName: String = "",
                energyPercent: Double = 0,
                energyKind: EnergyKind = .fuel,
                rangeKm: Int = 0,
                odometerKm: Int = 0,
                doorsLocked: Bool = true,
                windowsClosed: Bool = true,
                trunkClosed: Bool = true,
                acOn: Bool = false,
                cabinTempC: Double? = nil,
                updatedAt: Date = Date(),
                source: Source = .app) {
        self.vin = vin
        self.nickname = nickname
        self.modelName = modelName
        self.energyPercent = energyPercent
        self.energyKind = energyKind
        self.rangeKm = rangeKm
        self.odometerKm = odometerKm
        self.doorsLocked = doorsLocked
        self.windowsClosed = windowsClosed
        self.trunkClosed = trunkClosed
        self.acOn = acOn
        self.cabinTempC = cabinTempC
        self.updatedAt = updatedAt
        self.source = source
    }

    /// 演示数据：没有 token 时也能在预览/真机上看排版
    public static var placeholder: VehicleSnapshot {
        VehicleSnapshot(vin: "LHGCM82633A000000",
                        nickname: "我的 CR-V",
                        modelName: "CR-V 2026",
                        energyPercent: 0.62,
                        energyKind: .fuel,
                        rangeKm: 486,
                        odometerKm: 21340,
                        doorsLocked: true,
                        windowsClosed: true,
                        trunkClosed: true,
                        acOn: false,
                        cabinTempC: 26.5,
                        source: .app)
    }

    public var energyText: String {
        String(format: "%.0f%%", energyPercent * 100)
    }

    public var stale: Bool {
        Date().timeIntervalSince(updatedAt) > 30 * 60
    }
}
