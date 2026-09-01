// Pure parsing/formatting for dualsensectl's plain-text output. No QML here
// so this can be unit tested under node, same as the bluetooth plugin this
// was scaffolded from.
//
// dualsensectl has no JSON output. Source formats (nowrep/dualsensectl main.c):
//   list:    " %ls (%s)\n"      -> " <serial> (Bluetooth|USB)"
//   battery: "%d %s\n"          -> "<0-100> <discharging|charging|full|not-charging|unknown>"
// Battery capacity is reported in 10% steps (0, 10, 20, ... 100), not whole percent.

function parseDeviceList(text) {
  var lines = String(text || "").split("\n")
  var devices = []
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*(\S{1,64})\s+\(([^)]{1,32})\)\s*$/)
    if (!match) continue
    var serial = match[1]
    if (serial === "" || serial === "???") continue
    devices.push({ serial: serial, connection: match[2] })
  }
  return devices
}

function parseBattery(text) {
  var line = String(text || "").split("\n")[0] || ""
  var match = line.trim().match(/^(\d+)\s+(\S+)$/)
  if (!match) return null
  var level = parseInt(match[1], 10)
  if (!isFinite(level)) return null
  return { level: Math.max(0, Math.min(100, level)), status: match[2] }
}

// Carries battery/status forward across a fresh `-l` poll so numbers don't
// blank out every refresh tick while the battery queue catches up, and
// assigns -1/"unknown" to a controller seen for the first time.
function mergeDeviceLists(previous, discovered) {
  var prevBySerial = {}
  for (var i = 0; i < (previous || []).length; i++) prevBySerial[previous[i].serial] = previous[i]

  var merged = []
  for (var j = 0; j < discovered.length; j++) {
    var d = discovered[j]
    var prior = prevBySerial[d.serial]
    merged.push({
      serial: d.serial,
      connection: d.connection,
      battery: prior ? prior.battery : -1,
      batteryStatus: prior ? prior.batteryStatus : "unknown"
    })
  }
  merged.sort(function(a, b) { return a.serial.localeCompare(b.serial) })
  return merged
}

function withBattery(devices, serial, battery) {
  var next = []
  for (var i = 0; i < (devices || []).length; i++) {
    var d = devices[i]
    next.push(d.serial === serial && battery
      ? { serial: d.serial, connection: d.connection, battery: battery.level, batteryStatus: battery.status }
      : d)
  }
  return next
}

function shortSerial(serial) {
  var text = String(serial || "").toUpperCase()
  var parts = text.split(":")
  return parts.length >= 2 ? parts.slice(-2).join(":") : text.slice(-8)
}

// Only disambiguates with the serial suffix once a second controller shows
// up — a single controller just reads "DualSense".
function controllerLabel(dev, total) {
  if (!dev) return "DualSense"
  return total > 1 ? "DualSense · " + shortSerial(dev.serial) : "DualSense"
}

function batteryLabel(dev) {
  if (!dev || dev.battery < 0) return "—"
  var pct = dev.battery + "%"
  if (dev.batteryStatus === "charging") return pct + " · Charging"
  if (dev.batteryStatus === "full") return pct + " · Full"
  return pct
}

function clampByte(value) {
  var n = Math.round(Number(value) || 0)
  return Math.max(0, Math.min(255, n))
}

function byteToFraction(byteValue) {
  return Math.max(0, Math.min(1, (Number(byteValue) || 0) / 255))
}

// Hand-picked, not derived from any official palette — DualSense lightbar
// presets are just an RGB write, so any values work here.
var lightbarPresets = [
  { name: "White", r: 255, g: 255, b: 255 },
  { name: "Blue", r: 0, g: 112, b: 255 },
  { name: "Red", r: 255, g: 24, b: 24 },
  { name: "Green", r: 30, g: 200, b: 80 },
  { name: "Purple", r: 160, g: 40, b: 220 },
  { name: "Orange", r: 255, g: 130, b: 0 }
]

var playerSlots = [1, 2, 3, 4]

if (typeof module !== "undefined") {
  module.exports = {
    parseDeviceList: parseDeviceList,
    parseBattery: parseBattery,
    mergeDeviceLists: mergeDeviceLists,
    withBattery: withBattery,
    shortSerial: shortSerial,
    controllerLabel: controllerLabel,
    batteryLabel: batteryLabel,
    clampByte: clampByte,
    byteToFraction: byteToFraction,
    lightbarPresets: lightbarPresets,
    playerSlots: playerSlots
  }
}
