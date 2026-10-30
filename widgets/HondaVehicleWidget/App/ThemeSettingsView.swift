import SwiftUI
import PhotosUI
import WidgetKit
import UIKit

// MARK: - 外观设置

struct ThemeSettingsView: View {

    enum BgKind: String, CaseIterable, Identifiable {
        case solid = "纯色"
        case gradient = "渐变"
        case image = "图片"
        var id: String { rawValue }
    }

    @State private var theme: WidgetTheme = SharedStore.theme()
    @State private var bgKind: BgKind = .gradient
    @State private var pickerItem: PhotosPickerItem?
    @State private var hasImage: Bool = SharedStore.hasThemeImage()

    // 裁剪
    @State private var cropSource: UIImage?
    @State private var showCrop = false
    @State private var cropAspect: CGFloat = 1.0

    var body: some View {
        Form {
            previewSection
            presetSection
            backgroundSection
            iconSection
            textSection
            fontSection
            imageSection
        }
        .navigationTitle("小组件外观")
        .onAppear { bgKind = kind(of: theme.background) }
        .onChange(of: theme) { newValue in
            SharedStore.saveTheme(newValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .task(id: pickerItem) { await importImage() }
        .sheet(isPresented: $showCrop) {
            if let source = cropSource {
                ImageCropView(image: source,
                              aspect: cropAspect,
                              onCancel: { showCrop = false },
                              onDone: { cropped in
                                  showCrop = false
                                  applyCropped(cropped)
                              })
            }
        }
    }

    // MARK: 预览

    private var previewSection: some View {
        Section {
            ZStack {
                ThemeBackground(theme: theme)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        if theme.showIcon { ThemeIcon(theme: theme, size: 17) }
                        Text("我的英仕派")
                            .font(theme.font(10.5, .semibold))
                            .foregroundStyle(theme.primary(.light))
                        Spacer(minLength: 0)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary(.light))
                    }

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            EnergyNumber(snapshot: .placeholder, theme: theme, size: 40)
                            Text("油电混合")
                                .font(theme.font(8.5, .medium))
                                .foregroundStyle(theme.secondary(.light))
                            ThinBar(percent: 0.62, theme: theme, height: 4)
                                .padding(.top, 1)
                        }
                        .frame(width: 92, alignment: .leading)

                        ThemeDivider(theme: theme, vertical: true)

                        VStack(alignment: .leading, spacing: 6) {
                            MetricCell(icon: "lock.fill", label: "车门", value: "已锁", theme: theme)
                            MetricCell(icon: "snowflake", label: "空调", value: "关", theme: theme)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(14)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .listRowInsets(EdgeInsets())
        } header: {
            Text("预览")
        } footer: {
            Text("这里按浅色渲染；桌面会跟随系统深浅色自动切换。")
        }
    }

    // MARK: 预设

    private var presetSection: some View {
        Section("预设配色") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(WidgetTheme.presets.enumerated()), id: \.offset) { _, item in
                        Button {
                            theme = item.1
                            bgKind = kind(of: item.1.background)
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    ThemeBackground(theme: item.1)
                                    Image(systemName: item.1.iconSymbol)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(item.1.iconTint.color(for: .light))
                                }
                                .frame(width: 62, height: 62)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                Text(item.0)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: 背景

    private var backgroundSection: some View {
        Section("背景") {
            Picker("类型", selection: $bgKind) {
                ForEach(BgKind.allCases) { k in
                    Text(k.rawValue).tag(k)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: bgKind) { newKind in
                switch newKind {
                case .solid:
                    theme.background = .solid(colorPair(theme.accent))
                case .gradient:
                    theme.background = .gradient(DualColor(0x0B1E3A), DualColor(0x16324F))
                case .image:
                    theme.background = .image(blur: 6, dim: 0.35)
                }
            }

            switch bgKind {
            case .solid:
                ColorPicker("填充色", selection: solidBinding)
            case .gradient:
                ColorPicker("起始色", selection: gradientStartBinding)
                ColorPicker("结束色", selection: gradientEndBinding)
            case .image:
                if hasImage {
                    LabeledContent("当前背景", value: "自定义图片")
                    Button(role: .destructive) {
                        SharedStore.removeThemeImage()
                        hasImage = false
                        theme.background = .gradient(DualColor(0x0B1E3A), DualColor(0x16324F))
                        bgKind = .gradient
                    } label: {
                        Text("移除图片")
                    }
                } else {
                    Text("还没有背景图，往下滑选一张")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Slider(value: $theme.backgroundOpacity, in: 0.4...1.0) {
                Text("背景不透明度")
            } minimumValueLabel: {
                Image(systemName: "circle.lefthalf.filled")
            } maximumValueLabel: {
                Image(systemName: "circle.fill")
            }
        }
    }

    // MARK: 图标

    private var iconSection: some View {
        Section("图标") {
            Toggle("显示图标", isOn: $theme.showIcon)

            Picker("图标样式", selection: $theme.iconSymbol) {
                ForEach(WidgetTheme.symbols, id: \.self) { s in
                    Label(title(forSymbol: s), systemImage: s).tag(s)
                }
            }

            ColorPicker("图标颜色", selection: iconTintBinding)

            Toggle("图标底座", isOn: Binding(
                get: { theme.iconBadge != nil },
                set: { on in
                    theme.iconBadge = on ? DualColor(light: RGB.hex(0xFFFFFF), dark: RGB.hex(0x3A3A3C)) : nil
                }
            ))

            if theme.iconBadge != nil {
                ColorPicker("底座颜色", selection: iconBadgeBinding)
            }
        }
    }

    // MARK: 文字

    private var textSection: some View {
        Section("文字") {
            Toggle("按深浅色自动黑白", isOn: $theme.autoTextColor)

            if !theme.autoTextColor {
                ColorPicker("主文字", selection: primaryBinding)
                ColorPicker("次要文字", selection: secondaryBinding)
            }

            ColorPicker("强调色（环形）", selection: accentBinding)
        }
    }

    // MARK: 字体

    private var fontSection: some View {
        Section("字体") {
            Picker("字形", selection: Binding(
                get: { theme.fontDesign },
                set: { theme.fontDesign = $0 }
            )) {
                ForEach(FontDesignOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("字号")
                    Spacer()
                    Text(String(format: "%.0f%%", theme.fontScale * 100))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $theme.fontScale, in: 0.85...1.4, step: 0.05)
            }
        }
    }

    // MARK: 图片

    private var imageSection: some View {
        Section {
            Picker("裁剪比例", selection: $cropAspect) {
                Text("通用 1:1").tag(CGFloat(1.0))
                Text("横版 2.14:1（中号）").tag(CGFloat(2.14))
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label(hasImage ? "更换背景图（可再裁剪）" : "从相册选择背景图",
                      systemImage: "photo.on.rectangle.angled")
            }

            if hasImage {
                Label("已保存，可直接在小工具里看到", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                Button(role: .destructive) {
                    SharedStore.removeThemeImage()
                    hasImage = false
                    theme.background = .gradient(DualColor(0x0A1628), DualColor(0x1B3A5C))
                    bgKind = .gradient
                } label: {
                    Text("移除背景图")
                }
            }
        } header: {
            Text("自定义背景图")
        } footer: {
            Text("选图后可以拖动、双指缩放来裁剪，输出 1200px 宽，够所有尺寸使用。")
        }
    }

    // MARK: 导入图片

    private func importImage() async {
        guard let item = pickerItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        // 先下采样，避免超大图拖慢裁剪手势
        let prepared = img.downscaled(maxSide: 2400)
        await MainActor.run {
            cropSource = prepared
            showCrop = true
        }
    }

    private func applyCropped(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        let ok = SharedStore.saveThemeImage(jpeg)
        hasImage = ok
        guard ok else { return }
        theme.background = .image(blur: 4, dim: 0.32)
        bgKind = .image
        SharedStore.saveTheme(theme)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: 工具

    private func kind(of style: BackgroundStyle) -> BgKind {
        switch style {
        case .solid: return .solid
        case .gradient: return .gradient
        case .image: return .image
        case .preset: return .solid
        }
    }

    private func colorPair(_ c: DualColor) -> DualColor { c }

    private func title(forSymbol s: String) -> String {
        switch s {
        case "car.fill": return "整车"
        case "car.side.fill": return "侧面"
        case "car.rear.fill": return "尾部"
        case "car.2.fill": return "多车"
        case "bolt.car.fill": return "电车"
        case "fuelpump.fill": return "油站"
        case "key.fill": return "钥匙"
        case "steeringwheel": return "方向盘"
        case "gauge.medium": return "仪表"
        default: return "定位"
        }
    }

    // MARK: Color 绑定

    private var solidBinding: Binding<Color> {
        Binding(get: {
            if case let .solid(c) = theme.background { return c.light.color }
            return Color.gray
        }, set: { newColor in
            let c = DualColor(light: newColor.rgbValue, dark: newColor.rgbValue)
            theme.background = .solid(c)
        })
    }

    private var gradientStartBinding: Binding<Color> {
        Binding(get: {
            if case let .gradient(a, _) = theme.background { return a.light.color }
            return Color.black
        }, set: { newColor in
            var b = DualColor(0x16324F)
            if case let .gradient(_, oldB) = theme.background { b = oldB }
            let a = DualColor(light: newColor.rgbValue, dark: newColor.rgbValue)
            theme.background = .gradient(a, b)
        })
    }

    private var gradientEndBinding: Binding<Color> {
        Binding(get: {
            if case let .gradient(_, b) = theme.background { return b.light.color }
            return Color.black
        }, set: { newColor in
            var a = DualColor(0x0B1E3A)
            if case let .gradient(oldA, _) = theme.background { a = oldA }
            let b = DualColor(light: newColor.rgbValue, dark: newColor.rgbValue)
            theme.background = .gradient(a, b)
        })
    }

    private var iconTintBinding: Binding<Color> {
        Binding(get: { theme.iconTint.light.color },
                set: { theme.iconTint = DualColor(light: $0.rgbValue, dark: $0.rgbValue) })
    }

    private var iconBadgeBinding: Binding<Color> {
        Binding(get: { (theme.iconBadge ?? DualColor(0x3A3A3C)).light.color },
                set: { theme.iconBadge = DualColor(light: $0.rgbValue, dark: $0.rgbValue) })
    }

    private var primaryBinding: Binding<Color> {
        Binding(get: { theme.textPrimary.light.color },
                set: { theme.textPrimary = DualColor(light: $0.rgbValue, dark: $0.rgbValue) })
    }

    private var secondaryBinding: Binding<Color> {
        Binding(get: { theme.textSecondary.light.color },
                set: { theme.textSecondary = DualColor(light: $0.rgbValue, dark: $0.rgbValue) })
    }

    private var accentBinding: Binding<Color> {
        Binding(get: { theme.accent.light.color },
                set: { theme.accent = DualColor(light: $0.rgbValue, dark: $0.rgbValue) })
    }
}

// MARK: - 颜色 / 图片工具

extension Color {
    var rgbValue: RGB {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(Double(r), Double(g), Double(b))
    }
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
