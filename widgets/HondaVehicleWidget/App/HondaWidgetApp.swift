import SwiftUI
import WidgetKit

@main
struct HondaWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var token: String = SharedStore.token() ?? ""
    @State private var vin: String = SharedStore.vin() ?? ""
    @State private var snapshot: VehicleSnapshot? = SharedStore.load()
    @State private var status: String = ""
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        Label("小组件外观（配色 / 图标 / 背景图）", systemImage: "paintpalette.fill")
                    }
                }

                Section("凭据（从抓包结果粘贴）") {
                    TextField("token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("保存并刷新") { saveAndFetch() }
                        .disabled(token.isEmpty || vin.isEmpty || loading)
                }

                Section("当前状态") {
                    if let s = snapshot {
                        LabeledContent("车型", value: s.modelName.isEmpty ? "—" : s.modelName)
                        LabeledContent("能源", value: s.energyText)
                        LabeledContent("续航", value: "\(s.rangeKm) km")
                        LabeledContent("里程", value: "\(s.odometerKm) km")
                        LabeledContent("车门", value: s.doorsLocked ? "已锁" : "未锁")
                        LabeledContent("车窗", value: s.windowsClosed ? "已关" : "未关")
                        LabeledContent("空调", value: s.acOn ? "开" : "关")
                        LabeledContent("更新于", value: s.updatedAt.formatted(date: .omitted, time: .shortened))
                        LabeledContent("来源", value: s.source.rawValue)
                    } else {
                        Text("还没有数据，先填 token 拉一次")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("存储状态") {
                    LabeledContent("共享目录", value: SharedStore.sharedDirURL?.path ?? "不可写（需重签）")
                    LabeledContent("背景图", value: SharedStore.hasThemeImage() ? "已保存" : "无")
                    LabeledContent("车况数据", value: SharedStore.load() == nil ? "无（显示示例）" : "已加载")
                        .foregroundStyle(SharedStore.load() == nil ? .secondary : .primary)
                }

                Section {
                    Button("立即刷新小组件") {
                        WidgetCenter.shared.reloadAllTimelines()
                        status = "已请求刷新"
                    }
                    if !status.isEmpty {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("本田车况")
            .overlay { if loading { ProgressView() } }
        }
    }

    private func saveAndFetch() {
        SharedStore.setToken(token)
        SharedStore.setVin(vin)
        loading = true
        status = ""
        Task {
            do {
                let fresh = try await VehicleAPI(token: token, vin: vin).fetchStatus()
                await MainActor.run {
                    SharedStore.save(fresh)
                    snapshot = fresh
                    loading = false
                    status = "拉取成功"
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                await MainActor.run {
                    loading = false
                    status = "失败：\(error)"
                }
            }
        }
    }
}
