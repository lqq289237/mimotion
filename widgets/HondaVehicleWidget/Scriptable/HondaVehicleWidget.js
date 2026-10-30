// 本田车况 · Scriptable 小组件
// 零编译版：App Store 装 Scriptable → 新建脚本 → 粘贴 → 桌面加 Scriptable 组件 → 长按选本脚本
// 支持：小/中/大三尺寸、渐变或图片背景、图标可换、深浅色

// ============ 配置区（只改这里） ============
const CONFIG = {
  host: "https://[API_HOST]",      // 抓包得到的域名
  path: "/[ENDPOINT]",             // 车况接口路径
  token: "",                        // 抓包得到的 token
  vin: "",                          // 你的 VIN
  demo: true,                       // true = 先用示例数据看效果；填好 token/vin 后改 false

  theme: "midnight",                // midnight | carbon | hondaRed | lime | paper | black
  icon: "car.fill",                 // car.fill / car.side.fill / bolt.car.fill / fuelpump.fill / key.fill
  bgImage: "",                      // 可选：图片 URL 或 iCloud 路径（如 "iCloud Drive/honda.jpg"）
  bgDim: 0.35                       // 背景图压暗程度 0~1
}

// ============ 主题 ============
const THEMES = {
  midnight: { bg0: "#0B1E3A", bg1: "#16324F", accent: "#4FC3F7", text: "#FFFFFF", sub: "#A8C0D8" },
  carbon:   { bg0: "#1C1C1E", bg1: "#3A3A3C", accent: "#30D158", text: "#FFFFFF", sub: "#9A9AA0" },
  hondaRed: { bg0: "#7A1220", bg1: "#B31E32", accent: "#FFD166", text: "#FFFFFF", sub: "#F0B9C0" },
  lime:     { bg0: "#0F2A1D", bg1: "#123A28", accent: "#B9F272", text: "#EAFFF2", sub: "#8FBFA3" },
  paper:    { bg0: "#F7F7F9", bg1: "#E8E8ED", accent: "#D6001C", text: "#111114", sub: "#6B6B72" },
  black:    { bg0: "#000000", bg1: "#111111", accent: "#FFFFFF", text: "#FFFFFF", sub: "#8A8A8E" }
}

// ============ 字段映射（抓包后按需改） ============
const KEYMAP = {
  energy:   ["oilPercent", "fuelPercent", "soc", "batteryLevel", "oil"],
  range:    ["range", "endurance", "remainRange", "evRange", "fuelRange"],
  odometer: ["odometer", "mileage", "totalMileage", "odo"],
  doors:    ["doorLock", "lockStatus", "doorsLocked", "lockState"],
  windows:  ["windowStatus", "windowsClosed", "windowState"],
  ac:       ["acStatus", "acOn", "climateOn", "airCondition"],
  cabin:    ["inTemp", "cabinTemp", "insideTemp", "innerTemp"],
  nickname: ["nickName", "vehicleName", "carName", "alias"],
  model:    ["modelName", "seriesName", "vehicleModel"],
  kind:     ["energyType", "powerType", "fuelType"]
}

// ============ 请求 ============
async function fetchStatus() {
  const url = CONFIG.host.replace(/\/$/, "") + CONFIG.path
  const req = new Request(url)
  req.method = "POST"
  req.headers = {
    "Content-Type": "application/json",
    "token": CONFIG.token,
    "platform": "IOS"
  }
  req.body = JSON.stringify({ vin: CONFIG.vin, ts: Date.now() })
  const json = await req.loadJSON()
  return parse(json)
}

function dig(node, keys) {
  if (node === null || node === undefined) return undefined
  if (typeof node === "object") {
    for (const k of keys) if (node[k] !== undefined && node[k] !== null) return node[k]
    for (const k of Object.keys(node)) {
      const r = dig(node[k], keys)
      if (r !== undefined) return r
    }
  }
  return undefined
}

function toNum(v, def) {
  if (v === undefined || v === null) return def
  const n = Number(v)
  return isNaN(n) ? def : n
}

function toBool(v, def) {
  if (v === undefined || v === null) return def
  if (typeof v === "boolean") return v
  const s = String(v).toLowerCase()
  return ["1", "true", "locked", "closed", "on"].includes(s)
}

function parse(root) {
  let energy = toNum(dig(root, KEYMAP.energy), 0)
  if (energy > 1) energy /= 100
  energy = Math.min(Math.max(energy, 0), 1)

  const kindRaw = String(dig(root, KEYMAP.kind) || "").toLowerCase()
  const kind = (kindRaw.includes("电") || kindRaw.includes("ev") || kindRaw.includes("batt")) ? "battery"
             : (kindRaw.includes("混") || kindRaw.includes("hybrid")) ? "hybrid" : "fuel"

  return {
    nickname: dig(root, KEYMAP.nickname) || "我的车",
    model: dig(root, KEYMAP.model) || "",
    vin: CONFIG.vin,
    energy,
    kind,
    rangeKm: Math.round(toNum(dig(root, KEYMAP.range), 0)),
    odometerKm: Math.round(toNum(dig(root, KEYMAP.odometer), 0)),
    doorsLocked: toBool(dig(root, KEYMAP.doors), true),
    windowsClosed: toBool(dig(root, KEYMAP.windows), true),
    acOn: toBool(dig(root, KEYMAP.ac), false),
    cabinTemp: dig(root, KEYMAP.cabin) !== undefined ? toNum(dig(root, KEYMAP.cabin), null) : null,
    updatedAt: new Date()
  }
}

function demoSnapshot() {
  return {
    nickname: "我的英仕派", model: "INSPIRE e:HEV", vin: "LHGCM82633A000000",
    energy: 0.62, kind: "hybrid", rangeKm: 486, odometerKm: 21340,
    doorsLocked: true, windowsClosed: true, acOn: false, cabinTemp: 26.5,
    updatedAt: new Date()
  }
}

// ============ 组件 ============
function energyText(s) { return Math.round(s.energy * 100) + "%" }
function kindText(s) { return s.kind === "battery" ? "电量" : s.kind === "hybrid" ? "油电" : "油量" }

function relTime(d) {
  const m = Math.round((Date.now() - d.getTime()) / 60000)
  if (m < 1) return "刚刚"
  if (m < 60) return m + " 分钟前"
  return Math.round(m / 60) + " 小时前"
}

function addIcon(stack, name, size, color) {
  const sym = SFSymbol.named(name)
  if (!sym) return
  const img = stack.addImage(sym.image)
  img.imageSize = new Size(size, size)
  img.tintColor = color
}

function progressBar(w, percent, t, width) {
  const track = w.addStack()
  track.layoutHorizontally()
  track.size = new Size(width, 6)
  track.cornerRadius = 3
  track.backgroundColor = new Color(t.accent, 0.22)

  const fill = track.addStack()
  fill.size = new Size(Math.max(4, width * Math.min(percent, 1)), 6)
  fill.cornerRadius = 3
  fill.backgroundColor = percent < 0.2 ? new Color("#FF453A") : new Color(t.accent)
  return track
}

function createWidget(s, t, family) {
  const w = new ListWidget()
  w.setPadding(12, 13, 12, 13)

  // 背景：渐变
  const g = new LinearGradient()
  g.colors = [new Color(t.bg0), new Color(t.bg1)]
  g.locations = [0, 1]
  g.startPoint = new Point(0, 0)
  g.endPoint = new Point(1, 1)
  w.backgroundGradient = g

  const textColor = new Color(t.text)
  const subColor = new Color(t.sub)

  // 头部
  const header = w.addStack()
  header.centerAlignContent()
  addIcon(header, CONFIG.icon, 13, new Color(t.accent))
  header.addSpacer(4)
  const name = header.addText(s.nickname)
  name.font = Font.semiboldSystemFont(11)
  name.textColor = textColor
  name.lineLimit = 1
  header.addSpacer()
  addIcon(header, s.doorsLocked ? "lock.fill" : "lock.open.fill", 10,
          s.doorsLocked ? subColor : new Color("#FF9F0A"))

  w.addSpacer(7)

  if (family === "small") {
    const pct = w.addText(energyText(s))
    pct.font = Font.boldRoundedSystemFont(30)
    pct.textColor = textColor

    w.addSpacer(4)
    progressBar(w, s.energy, t, 132)

    w.addSpacer(8)
    const row = w.addStack()
    row.centerAlignContent()
    const r = row.addText(s.rangeKm + " km")
    r.font = Font.boldSystemFont(12)
    r.textColor = textColor
    row.addSpacer()
    const u = row.addText(relTime(s.updatedAt))
    u.font = Font.systemFont(9)
    u.textColor = subColor
  } else {
    // 中 / 大
    const mid = w.addStack()
    mid.centerAlignContent()

    const left = mid.addStack()
    left.layoutVertically()
    const pct = left.addText(energyText(s))
    pct.font = Font.boldRoundedSystemFont(28)
    pct.textColor = textColor
    const kt = left.addText(kindText(s))
    kt.font = Font.systemFont(9)
    kt.textColor = subColor
    left.addSpacer(4)
    progressBar(left, s.energy, t, 96)

    mid.addSpacer(14)

    const right = mid.addStack()
    right.layoutVertically()
    right.spacing = 6
    const r1 = right.addText(s.doorsLocked ? "车门 已锁" : "车门 未锁")
    r1.font = Font.systemFont(11)
    r1.textColor = textColor
    const r2 = right.addText(s.windowsClosed ? "车窗 已关" : "车窗 未开")
    r2.font = Font.systemFont(11)
    r2.textColor = textColor
    const r3 = right.addText("空调 " + (s.acOn ? "开" : "关") +
                             (s.cabinTemp !== null ? "  " + Math.round(s.cabinTemp) + "°C" : ""))
    r3.font = Font.systemFont(11)
    r3.textColor = textColor
    const r4 = right.addText("续航 " + s.rangeKm + " km")
    r4.font = Font.boldSystemFont(11)
    r4.textColor = textColor

    mid.addSpacer()

    if (family === "large") {
      w.addSpacer(12)
      const line = w.addStack()
      line.size = new Size(0, 0.5)
      line.backgroundColor = new Color(t.sub, 0.3)
      w.addSpacer(10)

      const stats = w.addStack()
      const a = stats.addText("总里程\n" + s.odometerKm + " km")
      a.font = Font.systemFont(10)
      a.textColor = textColor
      stats.addSpacer()
      const b = stats.addText("VIN 后六位\n" + String(s.vin).slice(-6))
      b.font = Font.systemFont(10)
      b.textColor = textColor
      stats.addSpacer()

      w.addSpacer()
      const foot = w.addStack()
      const f = foot.addText(relTime(s.updatedAt))
      f.font = Font.systemFont(9)
      f.textColor = subColor
      foot.addSpacer()
      const hint = foot.addText("点按打开 App")
      hint.font = Font.systemFont(9)
      hint.textColor = subColor
    }
  }

  return w
}

async function loadBgImage() {
  if (!CONFIG.bgImage) return null
  try {
    if (CONFIG.bgImage.startsWith("http")) return await Request.loadImage(CONFIG.bgImage)
    const fm = FileManager.iCloud()
    const path = fm.documentsDirectory() + "/" + CONFIG.bgImage.replace(/^.*\//, "")
    if (fm.fileExists(path)) return fm.readImage(path)
  } catch (e) {}
  return null
}

// ============ 入口 ============
async function main() {
  const t = THEMES[CONFIG.theme] || THEMES.midnight
  const family = config.widgetFamily || "small"

  let snap = null
  if (!CONFIG.demo && CONFIG.token && CONFIG.vin) {
    try { snap = await fetchStatus() } catch (e) { console.log("fetch failed: " + e) }
  }
  if (!snap) snap = demoSnapshot()

  const w = createWidget(snap, t, family)

  const bg = await loadBgImage()
  if (bg) {
    w.backgroundImage = bg
    w.backgroundColor = new Color("#000000", 0.55)
  }

  w.url = "hondaapp://"
  w.refreshAfterDate = new Date(Date.now() + 15 * 60 * 1000)
  return w
}

if (config.runsInWidget) {
  const widget = await main()
  Script.setWidget(widget)
} else {
  const widget = await main()
  await widget.presentMedium()
}
Script.complete()
