import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "androkami.ps5-controller"
  ipcTarget: "androkami.ps5-controller"

  Service {
    id: controllers
    settings: root.settings
  }

  readonly property var devices: controllers.devices || []
  readonly property int deviceCount: devices.length

  // "list" shows every connected controller; "detail" is the per-controller
  // control page. Both live in this one popup instead of a second panel —
  // simplest way to get a "tap a row to drill in" flow out of KeyboardPanel,
  // which only ever hosts one surface per bar widget.
  property string view: "list"
  property string activeSerial: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  // dualsensectl has no "get volume" / "get mic state" — only setters — so
  // the panel can only remember what it last *asked for*, not read the
  // controller's actual state. That's why these reset per controller instead
  // of coming from Service.devices.
  property real pendingVolume: 0.5
  property bool micMuted: false

  readonly property var activeDevice: {
    for (var i = 0; i < devices.length; i++)
      if (devices[i].serial === activeSerial) return devices[i]
    return null
  }

  readonly property var lightbarPresets: Model.lightbarPresets
  readonly property var playerSlots: Model.playerSlots

  function controllerLabel(dev) { return Model.controllerLabel(dev, devices.length) }
  function batteryLabel(dev) { return Model.batteryLabel(dev) }

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Color.accent)
    : "transparent"

  function openDetail(dev) {
    if (!dev) return
    activeSerial = dev.serial
    pendingVolume = 0.5
    micMuted = false
    view = "detail"
  }

  function backToList() {
    view = "list"
  }

  function moveCursor(delta) {
    if (view !== "list" || devices.length === 0) return
    if (!cursorActive) { cursorActive = true; return }
    selectedIndex = Math.max(0, Math.min(devices.length - 1, selectedIndex + delta))
  }

  function activateCursor() {
    if (view !== "list") return
    if (!cursorActive) { cursorActive = true; return }
    openDetail(devices[selectedIndex])
  }

  onOpenedChanged: {
    if (opened) {
      view = "list"
      selectedIndex = 0
      cursorActive = false
      controllers.refresh()
    }
  }

  onDevicesChanged: {
    if (selectedIndex >= devices.length) selectedIndex = Math.max(0, devices.length - 1)
    // Controller unplugged mid-detail-view — nothing left to control there.
    if (view === "detail" && activeSerial !== "" && !activeDevice) view = "list"
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        ControllerImage {
          anchors.centerIn: parent
          size: Style.space(13)
          color: root.bar ? root.bar.foreground : Color.foreground
          connected: root.deviceCount > 0
        }
      }
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) controllers.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.view !== "list") return
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: {
        if (root.view === "detail") root.backToList()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") controllers.refresh()
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        // ---------- List view ----------
        Item {
          id: listView
          visible: root.view === "list"
          width: parent.width
          height: visible ? listColumn.implicitHeight : 0

          Column {
            id: listColumn
            width: parent.width
            spacing: Style.space(14)

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

              ControllerImage {
                id: heroIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Style.space(26)
                color: root.bar.foreground
                connected: root.deviceCount > 0
              }

              Column {
                id: heroLabels
                anchors.left: heroIcon.right
                anchors.leftMargin: Style.space(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: "PS5 Controllers"
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: !controllers.installed ? "dualsensectl not found"
                      : root.deviceCount === 0 ? "No controller connected"
                      : root.deviceCount + " connected"
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.2
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

            Column {
              width: parent.width
              spacing: Style.space(10)
              visible: root.devices.length > 0

              Repeater {
                model: root.devices
                ControllerRow {
                  required property var modelData
                  required property int index
                  width: listColumn.width
                  dev: modelData
                  rowIndex: index
                }
              }
            }

            Text {
              visible: root.devices.length === 0
              text: !controllers.installed
                  ? "Install dualsensectl to manage DualSense controllers."
                  : "Connect a DualSense over USB or Bluetooth."
              color: Qt.darker(root.bar.foreground, 1.5)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              width: parent.width
            }
          }
        }

        // ---------- Detail view ----------
        Item {
          id: detailView
          visible: root.view === "detail"
          width: parent.width
          height: visible ? detailColumn.implicitHeight : 0

          Column {
            id: detailColumn
            width: parent.width
            spacing: Style.space(16)

            Item {
              width: parent.width
              implicitHeight: backBtn.implicitHeight

              PanelActionButton {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconText: "←"
                tooltipText: "Back"
                foreground: root.bar.foreground
                hoverColor: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.backToList()
              }

              Text {
                anchors.centerIn: parent
                text: root.controllerLabel(root.activeDevice)
                textFormat: Text.PlainText
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              ControllerImage {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Style.space(72)
                color: root.bar.foreground
                source: Qt.resolvedUrl("assets/ps5-controller-gamepad.svg")
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.batteryLabel(root.activeDevice)
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            PanelSeparator { foreground: root.bar.foreground }

            // ---- Lightbar ----
            Column {
              width: parent.width
              spacing: Style.space(10)

              PanelSectionHeader {
                text: "LIGHTBAR"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              Row {
                spacing: Style.space(10)

                Repeater {
                  model: root.lightbarPresets
                  Rectangle {
                    id: swatch
                    required property var modelData
                    width: Style.space(26)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(modelData.r / 255, modelData.g / 255, modelData.b / 255, 1)
                    border.width: Style.space(2)
                    border.color: swatchMouse.containsMouse ? root.bar.foreground : root.bar.background

                    MouseArea {
                      id: swatchMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: controllers.setLightbarColor(root.activeSerial, swatch.modelData.r, swatch.modelData.g, swatch.modelData.b)
                    }

                    PanelToolTip {
                      visible: swatchMouse.containsMouse
                      text: swatch.modelData.name
                      fontFamily: root.bar.fontFamily
                    }
                  }
                }

                PanelActionButton {
                  iconText: "󰅙"
                  tooltipText: "Lightbar off"
                  foreground: root.bar.foreground
                  hoverColor: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: controllers.setLightbarOff(root.activeSerial)
                }
              }
            }

            // ---- Player LED ----
            Column {
              width: parent.width
              spacing: Style.space(10)

              PanelSectionHeader {
                text: "PLAYER LED"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              Row {
                spacing: Style.space(10)

                Repeater {
                  model: root.playerSlots
                  Rectangle {
                    id: chip
                    required property int modelData
                    width: Style.space(26)
                    height: width
                    radius: Style.cornerRadius
                    color: "transparent"
                    border.width: Style.space(1)
                    border.color: chipMouse.containsMouse ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)

                    Text {
                      anchors.centerIn: parent
                      text: chip.modelData
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: chipMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: controllers.setPlayerLeds(root.activeSerial, chip.modelData)
                    }
                  }
                }

                PanelActionButton {
                  iconText: "󰅙"
                  tooltipText: "LEDs off"
                  foreground: root.bar.foreground
                  hoverColor: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: controllers.setPlayerLeds(root.activeSerial, 0)
                }
              }
            }

            // ---- Volume ----
            Column {
              width: parent.width
              spacing: Style.space(10)

              PanelSectionHeader {
                text: "VOLUME"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              PanelSlider {
                bar: root.bar
                width: parent.width
                minimum: 0
                maximum: 1
                step: 0.05
                value: root.pendingVolume
                onReleased: function(v) {
                  root.pendingVolume = v
                  controllers.setVolume(root.activeSerial, Math.round(v * 255))
                }
              }
            }

            // ---- Microphone ----
            Item {
              width: parent.width
              implicitHeight: Math.max(micLabel.implicitHeight, micSwitch.implicitHeight)

              Text {
                id: micLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Microphone"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }

              ToggleSwitch {
                id: micSwitch
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: !root.micMuted
                foreground: root.bar.foreground
                onToggled: {
                  root.micMuted = !root.micMuted
                  controllers.setMicrophoneMuted(root.activeSerial, root.micMuted)
                }
              }
            }

            Text {
              visible: controllers.actionStatus !== ""
              width: parent.width
              text: controllers.actionStatus
              textFormat: Text.PlainText
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  // One row per connected controller. No sections, no forget/pair actions —
  // dualsensectl only ever shows controllers that are already connected.
  // Recolors whatever `source` SVG it's given to match the bar's foreground,
  // the same way Tray.qml recolors symbolic tray icons: render the source
  // into a hidden layer, then have MultiEffect sample it and flood-fill with
  // `color`. `source` defaults to the simple Lucide d-pad glyph, which is
  // designed to read at icon size — that's what the bar icon, list header,
  // and per-row icons use. The detail-page hero overrides it with the
  // detailed hand-drawn controller art, which only holds up once it has
  // real room.
  component ControllerImage: Item {
    id: imageRoot
    property real size: Style.space(64)
    property color color: Color.foreground
    property bool connected: true
    property url source: Qt.resolvedUrl("assets/arrow-pad.svg")

    width: size
    height: size
    implicitWidth: size
    implicitHeight: size
    opacity: connected ? 1.0 : 0.45

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Image {
      id: rawImage
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      source: imageRoot.source
      sourceSize.width: Math.round(imageRoot.size * Screen.devicePixelRatio)
      sourceSize.height: Math.round(imageRoot.size * Screen.devicePixelRatio)
      visible: false
      layer.enabled: true
    }

    MultiEffect {
      anchors.fill: rawImage
      source: rawImage
      colorization: 1.0
      colorizationColor: imageRoot.color
    }
  }

  component ControllerRow: CursorSurface {
    id: row
    required property var dev
    required property int rowIndex

    readonly property bool rowSelected: root.cursorActive && root.selectedIndex === rowIndex

    hasCursor: rowSelected
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.selectedIndex = row.rowIndex
      }
      onClicked: root.openDetail(row.dev)
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(icon.implicitHeight, info.implicitHeight)

      ControllerImage {
        id: icon
        size: Style.font.heading
        color: root.bar.foreground
        connected: true
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: info
        spacing: Style.space(1)
        anchors.left: icon.right
        anchors.leftMargin: Style.space(12)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: root.controllerLabel(row.dev)
          textFormat: Text.PlainText
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          width: parent.width
        }
        Text {
          text: root.batteryLabel(row.dev) + " · " + row.dev.connection
          textFormat: Text.PlainText
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }
  }
}
