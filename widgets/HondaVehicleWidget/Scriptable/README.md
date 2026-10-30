# Scriptable 零编译版（最快看到效果）

不需要 Mac、不需要 Xcode、不需要签名、不需要越狱。10 分钟出效果。

## 装

1. App Store 搜「**Scriptable**」→ 安装（免费）
2. 打开 Scriptable → 右上 **+** → 新建脚本
3. 把 `HondaVehicleWidget.js` 全文粘进去
4. 命名成「本田车况」→ 点 **▶︎** 先跑一次，看效果图

## 加到桌面

1. 长按桌面空白 → 左上 **+** → 搜 **Scriptable**
2. 选尺寸（小 / 中 / 大）→ 添加
3. 长按刚加的组件 → **Edit Widget**
4. Script 选「本田车况」→ 空格
5. 完成，出图

锁屏同理（圆形/矩形），但锁屏是单色渲染，颜色会被系统压成灰。

## 改配置

打开脚本，最上面的 `CONFIG`：

```js
const CONFIG = {
  host: "https://[API_HOST]",   // 抓包域名
  path: "/[ENDPOINT]",          // 车况接口
  token: "",                     // 抓到的 token
  vin: "",                       // 你的 VIN
  demo: true,                    // 填好上面两项后改成 false

  theme: "midnight",             // midnight/carbon/hondaRed/lime/paper/black
  icon: "car.fill",              // 图标随便换
  bgImage: "",                   // 图片 URL 或 iCloud 文件名
  bgDim: 0.35
}
```

`demo: true` 时固定显示示例数据（62% / 486 km），先把排版调满意再填真数据。

## 自定义背景

三种：

| 方式 | 做法 |
|---|---|
| 渐变 | 改 `theme`，或用脚本里 `THEMES` 自己加一套 `{bg0, bg1, accent, text, sub}` |
| 纯色 | 把 `g.colors` 里两个颜色改成一个 |
| 图片 | `bgImage: "https://..."` 或把图存进 Scriptable 的 iCloud 目录，写 `bgImage: "honda.jpg"`，配合 `bgDim` 压暗 |

图片会铺满并被压暗，保证文字可读。

## 换图标

`icon` 里填任意 SF Symbol 名，常用的：

```
car.fill  car.side.fill  car.rear.fill  car.2.fill
bolt.car.fill  fuelpump.fill  key.fill  steeringwheel
gauge.medium  location.fill
```

## 刷新

Scriptable 组件由系统调度，`refreshAfterDate` 已设为 15 分钟。想手动刷新：打开 Scriptable 点脚本跑一次，或长按组件 → Refresh。

## 与 ipa 版的区别

| | Scriptable 版 | ipa 版 |
|---|---|---|
| 安装 | App Store 装个 App 就完事 | 需编译 + 签名 |
| 主屏/锁屏小组件 | ✅ | ✅ |
| 自定义背景/图标 | ✅ | ✅ |
| 点击跳转 | `w.url` 只能开 URL，跳不到原 App 内部页 | 可 `hondawidget://` 深链到自己 App |
| 后台刷新频率 | 系统调度，不稳定 | 与 ipa 版相同限制 |
| 大尺寸四宫格 | ✅ | ✅ |
