import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Backend for the PS5 Controller panel. There is no native Quickshell
// service for game controllers, so this polls dualsensectl(1) the same way
// the Tailscale and Dropbox plugins poll their own CLIs: `which` once to
// detect installation, then `-l` on a timer, then one `battery` call per
// discovered serial run through a small queue so two dualsensectl processes
// never touch hidraw at the same time.
Item {
  id: root

  property var settings: ({})

  property bool installed: false
  property bool refreshing: false
  // [{ serial, connection, battery (-1 = unknown), batteryStatus }]
  property var devices: []
  property string lastError: ""
  property string actionStatus: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 60)
  readonly property bool busy: whichProcess.running || listProcess.running || batteryProcess.running || actionProcess.running

  property string _listOutput: ""
  property string _batteryOutput: ""
  property string _batteryTarget: ""
  property var _batteryQueue: []
  property string _actionOutput: ""
  property string _actionError: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function refresh() {
    if (installed) { startList(); return }
    if (!whichProcess.running) {
      refreshing = true
      whichProcess.command = ["which", "dualsensectl"]
      whichProcess.running = true
    }
  }

  function startList() {
    if (listProcess.running) return
    refreshing = true
    _listOutput = ""
    pollWatchdog.restart()
    listProcess.command = ["dualsensectl", "-l"]
    listProcess.running = true
  }

  function applyDeviceList(text) {
    var discovered = Model.parseDeviceList(text)
    devices = Model.mergeDeviceLists(devices, discovered)
    _batteryQueue = discovered.map(function(d) { return d.serial })
    pumpBatteryQueue()
  }

  function pumpBatteryQueue() {
    if (batteryProcess.running || _batteryQueue.length === 0) return
    _batteryTarget = _batteryQueue.shift()
    _batteryOutput = ""
    pollWatchdog.restart()
    batteryProcess.command = ["dualsensectl", "-d", _batteryTarget, "battery"]
    batteryProcess.running = true
  }

  function deviceBySerial(serial) {
    for (var i = 0; i < devices.length; i++) if (devices[i].serial === serial) return devices[i]
    return null
  }

  // One in-flight action at a time — a rapid double-click just drops the
  // second command rather than queuing behind the first.
  function runAction(serial, args) {
    if (!serial || actionProcess.running) return
    _actionOutput = ""
    _actionError = ""
    actionProcess.command = ["dualsensectl", "-d", serial].concat(args)
    actionProcess.running = true
  }

  function setLightbarColor(serial, r, g, b) {
    runAction(serial, ["lightbar", String(Model.clampByte(r)), String(Model.clampByte(g)), String(Model.clampByte(b))])
  }

  function setLightbarOff(serial) { runAction(serial, ["lightbar", "off"]) }
  function setLightbarOn(serial) { runAction(serial, ["lightbar", "on"]) }
  function setPlayerLeds(serial, n) { runAction(serial, ["player-leds", String(n)]) }
  function setVolume(serial, byteValue) { runAction(serial, ["volume", String(Model.clampByte(byteValue))]) }
  function setMicrophoneMuted(serial, muted) { runAction(serial, ["microphone", muted ? "off" : "on"]) }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // A hung dualsensectl call (controller yanked mid-read) would otherwise
  // stall every poll after it forever, since both list and battery checks
  // skip themselves while their process is still marked running.
  Timer {
    id: pollWatchdog
    interval: 4000
    repeat: false
    onTriggered: {
      if (listProcess.running) listProcess.running = false
      if (batteryProcess.running) batteryProcess.running = false
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 2500
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) root.startList()
      else { root.refreshing = false; root.devices = [] }
    }
  }

  Process {
    id: listProcess
    running: false
    command: []
    stdout: StdioCollector { id: listStdout; waitForEnd: true; onStreamFinished: root._listOutput = text }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode === 0) root.applyDeviceList(String(listStdout.text || root._listOutput || ""))
      else root.devices = []
    }
  }

  Process {
    id: batteryProcess
    running: false
    command: []
    stdout: StdioCollector { id: batteryStdout; waitForEnd: true; onStreamFinished: root._batteryOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var battery = Model.parseBattery(String(batteryStdout.text || root._batteryOutput || ""))
        if (battery) root.devices = Model.withBattery(root.devices, root._batteryTarget, battery)
      }
      root.pumpBatteryQueue()
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionError = text }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(actionStderr.text || root._actionError || actionStdout.text || root._actionOutput || "dualsensectl command failed").trim().slice(0, 200)
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
      }
    }
  }
}
