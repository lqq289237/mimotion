# 怎么用（iPhone 14 Pro Max · iOS 16.6.1 · Windows 电脑）

三条路线，按「省事程度」排序。**先看第 0 步**——不填数据也能看到效果。

---

## 第 0 步：先确认你要的是哪种

| 路线 | 需要 | App Group（主题设置生效？） | 越狱 |
|---|---|---|---|
| **A. TrollStore**（推荐） | 装 TrollStore 2 | ✅ 生效 | 不需要 |
| **B. 越狱 + Dopamine** | 越狱 | ✅ 生效，还能免 token 桥接 | 需要 |
| **C. AltStore / Sideloadly** | 签名工具 + 电脑 | ❌ 失效，走硬编码兜底 | 不需要 |

> **App Group 说明**：主 App 和小组件是两个进程，共享数据靠 App Group entitlement。
> - TrollStore / 越狱：entitlement 保留 → 主题设置、token 都能互通
> - 免费账号签名：entitlement 被剥掉 → 主题设置无效（永远显示午夜蓝），token 必须在源码里硬编码

---

## 第 1 步：拿到 ipa（三选一）

### 1A. 没 Mac —— GitHub Actions 云端编译（最省事）

```powershell
# 在 Windows 上
cd C:\Users\Administrator\Documents\deepseek-harness\default-workspace
git init; git add widgets .github
git commit -m "honda widget"
git remote add origin https://github.com/[你的用户名]/[仓库名].git
git push -u origin main
```

> `samples/` 目录很大（几百 MB 的 Crane 解包），别 add 进去。

然后：

1. 打开 GitHub 仓库 → **Actions** → 左侧 `build-honda-widget-ipa` → **Run workflow**
2. 等 5–10 分钟（macos-14 runner 免费额度够）
3. 构建完成 → 页面底部 **Artifacts** → 下载 `HondaWidgetApp-ipa.zip`
4. 解压得到 `HondaWidgetApp.ipa`

### 1B. 有 Mac —— 本地编译

```bash
brew install xcodegen
cd widgets/HondaVehicleWidget
chmod +x scripts/build-ipa.sh
./scripts/build-ipa.sh
# → out/HondaWidgetApp.ipa
```

Xcode 直连手机也行：`open HondaVehicleWidget.xcodeproj` → 选你的 Apple ID Team → Run。

### 1C. 想改代码再编

改 `Shared/FallbackCredentials.swift` 里的 token/vin（路线 C 必做），再走 1A 或 1B。

---

## 第 2 步：装到手机

### A. TrollStore（推荐，iOS 16.6.1 支持）

1. 浏览器打开 `https://github.com/opa334/TrollStore` → Releases 看当前版本
2. 16.6.1 用 **TrollInstallerX**（配合 AltStore/Sideloadly 装一次安装器即可）
3. 运行 TrollInstallerX → **Install TrollStore** → 选 `Tips` 作为 persistence helper
4. 桌面出现 TrollStore 图标 → 把 `HondaWidgetApp.ipa` 传到手机（AirDrop / 文件 / 微信文件）→ **用 TrollStore 打开 ipa** → Install
5. 装完桌面出现「本田车况」

> TrollStore 装的 App 永久签名，不会 7 天掉签，entitlement 完整。

### B. 越狱（Dopamine，A12–A16 / iOS 15.0–16.6.1 支持，14PM 正好在内）

1. `https://github.com/opa334/Dopamine` 下载 → 用 TrollStore 装 → 打开 → **Jailbreak**
2. 越狱后装 Sileo → 装 `ellekit`
3. 把 ipa 拷进手机 → Sileo 里或用 `ldid -S App/App.entitlements` 签名后丢 `/Applications/` → `uicache -a`
4. 顺手把 TokenBridge 也装上（免 token 那套）：
   ```bash
   cd widgets/HondaVehicleWidget/Tweaks/TokenBridge && make package FINALPACKAGE=1
   scp -P 2222 packages/*.deb mobile@[IP]:/var/mobile/
   ssh -p 2222 mobile@[IP] "sudo dpkg -i /var/mobile/*.deb; sudo killall -9 SpringBoard"
   ```

### C. AltStore / Sideloadly（不越狱、不 TrollStore）

1. 电脑装 **Sideloadly**（Windows 可用）或 AltStore
2. 数据线连手机 → 拖入 `HondaWidgetApp.ipa` → 填 Apple ID → Start
3. 手机会出现 App；**7 天后掉签**，重连再装一次
4. ⚠️ 免费账号会剥掉 App Group → 先在 `FallbackCredentials.swift` 里把 token/vin 写死再编译，否则小组件只有演示数据

---

## 第 3 步：加小组件

1. 长按桌面空白处 → 左上角 **+**
2. 搜索「**本田车况**」
3. 选尺寸：
   - **小**（170×170）：环形油量 + 续航 + 锁车
   - **中**（364×170）：环形 + 门锁/车窗/空调/温度四宫格
   - **大**（364×382）：中号全部 + 里程 + VIN 后六位 + 数据新鲜度
4. 选中拖到桌面

**锁屏**也一样：长按锁屏 → 自定义 → 加小组件 → 选「车况（锁屏）」，圆形/行内/矩形三种。

此时如果没填 token，会显示**示例数据**（我的英仕派 / 62% / 486 km），用来确认排版正确——不是故障。

---

## 第 4 步：填真实车况

### 方式 1：App 里填（需要 App Group，即路线 A/B）

1. 打开「本田车况」App
2. 填 `token` 和 `VIN`：
   - `VIN`：App 内「我的车」页面能看到，或抓包里 `vin` 字段
   - `token`：抓包得到（见下）
3. 点「**保存并刷新**」→ 成功后会显示真实油量/续航
4. 回桌面看，小组件已更新

### 方式 2：源码硬编码（路线 C 必须）

编辑 `Shared/FallbackCredentials.swift`：

```swift
public static let token: String? = "eyJhbGciOi..."     // 抓到的 token
public static let vin: String?  = "LHGCM82633A000000"  // 你的 VIN
```

重新编译、重装。

### 怎么抓 token

```bash
# 电脑上（需要 Python）
pip install mitmproxy
mitmproxy -p 8080 --set confdir=~/.mitmproxy
```

1. 手机 WiFi 代理指到电脑 IP:8080
2. Safari 打开 `http://mitm.it` → 装 iOS 证书 → 设置 → 通用 → 关于本机 → 证书信任设置 → 打开
3. 打开东风本田 App → 进「我的车 → 车况」
4. mitmproxy 里找 `/status`、`/vehicle`、`/condition` 这类请求，看 `token` 头，复制值
5. 同时看响应 JSON 的字段名，和 `Shared/VehicleAPI.swift` 里的 `KeyMap` 对一下，不一致就改 KeyMap

> 如果 App 有证书 pinning，抓不到包 → 走越狱路线，用 Frida 挂
> `SSL_get_verify_result` 返回 0，或者干脆用 TokenBridge 桥接（不用 token）。

---

## 第 5 步：调外观

App →「**小组件外观**」：

- **预设配色**：横滑点六个色卡（午夜蓝 / 碳灰 / 本田红 / 青柠 / 纸白 / 纯黑）
- **背景**：纯色 / 渐变 / **相册图片**
  - 选图片：滑到底「从相册选择背景图」→ 选图 → 自动保存并刷新
  - 建议横图，≥ 1092×1146
- **图标**：10 种样式 + 颜色 + 底座开关
- **文字**：默认自动黑白，可改成自定义色
- 改完**回桌面立刻生效**，不用重新添加小组件

---

## 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 小组件显示「我的英仕派 62%」 | 没填 token，这是演示数据。按第 4 步填 |
| 小组件全白 / 全灰 | 主题背景图没加载到 → 重新选一次图片；或 App Group 失效（路线 C） |
| 主题改了没反应 | 路线 C（免费签名）App Group 被剥，主题只能默认。换 TrollStore 或越狱 |
| 数据一直不更新 | WidgetKit 15 分钟一次是硬限制。打开 App 点「立即刷新小组件」可强制 |
| App 里填了 token 但拉取失败 | 接口要 `sign`/`nonce` 签名，得补签名算法；看抓包有没有 401 |
| 装到手机后找不到小组件 | 先打开一次 App（让系统注册 widget），再长按桌面 + |
| 7 天后打不开 | 免费签名过期，重装 |
| 锁屏小组件没颜色 | iOS 16 锁屏走系统 vibrancy，只有 `fullColor` 模式才显示自定义色 |

---

## 一句话流程

**Windows → 推 GitHub → Actions 编译 → 下载 ipa → TrollStore 装 → 桌面 + 号加「本田车况」→ App 里填 token → 改配色。**
