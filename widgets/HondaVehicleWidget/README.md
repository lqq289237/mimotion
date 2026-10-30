# 本田车况小组件（HondaVehicleWidget）

为东风本田超级APP（`com.szlanyou.HondaOneIOV`）做独立 Widget：主屏小/中/大 + 锁屏三种，**背景与图标全可自定义**。

目标设备：iPhone 14 Pro Max / iOS 16.6.1（代码同时兼容 iOS 17，17 上的 `containerBackground` 会自动走另一条分支）。

## 自定义能力一览

| 项 | 可调 | 存在哪 |
|---|---|---|
| 背景类型 | 纯色 / 渐变 / 相册图片 | `WidgetTheme.background` |
| 背景不透明度 | 0.4–1.0 | `backgroundOpacity` |
| 图片模糊 / 压暗 | 滑杆外的预设（`blur: 6, dim: 0.35`） | `BackgroundStyle.image` |
| 图标 | 10 个 SF Symbol 可选（整车/侧面/尾部/多车/电车/油站/钥匙/方向盘/仪表/定位） | `iconSymbol` |
| 图标颜色 / 底座 | 任意色 + 可关闭底座 | `iconTint` / `iconBadge` |
| 文字 | 自动黑白 或 自定义主/次文字色 | `autoTextColor` / `textPrimary` |
| 强调色 | 环形进度条颜色 | `accent` |
| 预设主题 | 午夜蓝、碳灰、本田红、青柠、纸白、纯黑 | `WidgetTheme.presets` |

所有设置在主 App 的「小组件外观」里改，改完自动 `reloadAllTimelines()`，不用重装。

## 尺寸（iPhone 14 Pro Max）

| 家族 | 点 | 像素 @3x |
|---|---|---|
| 小 | 170×170 | 510×510 |
| 中 | 364×170 | 1092×510 |
| 大 | 364×382 | 1092×1146 |
| 锁屏圆/行内/矩形 | 系统定 | — |

自定义背景图建议 ≥ 1092×1146；`importImage()` 会自动缩到最长边 1400 再压 JPEG(0.82)，避免撞上扩展的内存上限。

## 目录

```
HondaVehicleWidget/
├── project.yml                    # XcodeGen
├── Shared/                        # App 与 Widget 共用（两边 target 都编译）
│   ├── VehicleSnapshot.swift      # 数据模型
│   ├── WidgetTheme.swift          # 主题模型 + 预设 + 图标集
│   ├── ThemeViews.swift           # 背景/图标/环形表/文字 渲染组件
│   ├── SharedStore.swift          # App Group 读写 + 桥接 plist + 背景图路径
│   └── VehicleAPI.swift           # 接口客户端 + KeyMap
├── App/
│   ├── HondaWidgetApp.swift       # 容器 App
│   ├── ThemeSettingsView.swift    # 外观设置页（含 PhotosPicker）
│   └── App.entitlements
├── Widget/
│   ├── VehicleWidget.swift        # 主屏小/中/大
│   ├── VehicleWidgetBundle.swift  # @main + 锁屏
│   └── Widget.entitlements
└── Tweaks/TokenBridge/            # 越狱桥接（可选）
```

## 1. 生成工程

```bash
brew install xcodegen
cd widgets/HondaVehicleWidget
xcodegen generate
open HondaVehicleWidget.xcodeproj
```

`project.yml` 里 `DEVELOPMENT_TEAM` 换成你的 Team ID。免费账号也能装（7 天重签）。

## 2. 改三个值

`Shared/VehicleAPI.swift`：

```swift
public static var host = "https://[API_HOST]"
public static var statusPath = "/[ENDPOINT]"
```

App 界面里填 `token` 和 `VIN`。抓包方法沿用前面那套 mitmproxy + Frida 绕 pinning；字段名对不上就改 `VehicleAPI.KeyMap`，解析器会自动在整棵 JSON 里找。

## 3. 换外观（重点）

App →「小组件外观」：

1. **预设配色** 横滑点选，立刻预览
2. **背景** 选「纯色 / 渐变 / 图片」
   - 纯色 → 一个 ColorPicker
   - 渐变 → 起始色 + 结束色
   - 图片 → 下滑到「自定义背景图」→ 从相册选 → 自动存进 App Group 容器 `theme-background.jpg`
3. **图标** 选样式、改颜色、开/关底座
4. **文字** 默认自动黑白；关掉后可自定义主/次文字色
5. 改完直接回桌面看，widget 已经刷新

> iOS 16 没有 `AppIntentConfiguration`，所以主题只能放在 App 内改，这是该版本的正常路径（iOS 17 才能长按 widget 直接配置）。

## 4. 签名安装

| 方式 | 步骤 |
|---|---|
| TrollStore | 直接装 ipa，App Group + 任意 entitlement 都可用 |
| AltStore / SideStore | 拖 ipa，7 天续签 |
| 越狱机 | `ldid -S App.entitlements` 后丢 `/Applications/`，`uicache -a` |

装好后长按桌面 → 左上「+」→ 搜「本田车况」→ 选尺寸。

## 5. 越狱桥接（可选，免 token）

```bash
cd Tweaks/TokenBridge
make package FINALPACKAGE=1
ssh -p 2222 mobile@[HOST_IP] "sudo dpkg -i /var/mobile/*.deb; sudo killall -9 SpringBoard"
ssh -p 2222 mobile@[HOST_IP] "plutil -p /var/mobile/Library/Preferences/com.yg.hondawidget.status.plist"
```

有值就说明桥接通了，widget 不填 token 也能显示。

## 6. iOS 16.6.1 上的注意事项

1. **锁屏 widget 不吃自定义背景**：锁屏走系统 vibrancy，只有 `fullColor` 模式会用你的强调色，`accented` 会被系统改成单色——`LockScreenView` 里已用 `widgetRenderingMode` 分支处理。
2. **不能放按钮**：交互式 widget（AppIntent 按钮）是 iOS 17 的，16.6.1 只能点整块跳转 App。
3. **15 分钟刷新是硬上限**，想更勤只能靠 App 内 `reloadAllTimelines()`。
4. **深色模式**：`ThemeBackground` 按 `\.colorScheme` 取 `DualColor` 的浅/深两支，所以同一套主题在两种模式下都好看；「纸白」预设就是为此设计的。
5. **内存**：扩展预算约 30 MB，背景图已限制尺寸；不要在 widget 里加载 GIF 或多张大图。

## 7. 已知限制

1. token 过期需重新粘贴；若接口带 `sign`/`nonce`，要把前面逆向出的签名算法补进 `VehicleAPI`。
2. 车况不会主动推送，锁车/开空调后要点开 App 或等下一轮 timeline。
3. 多车场景把 `SharedStore` 的 key 改成 `vehicle.snapshot.<vin>`，并在 `load()` 加 vin 参数。
