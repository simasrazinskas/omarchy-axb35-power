import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "axb35.power"
  ipcTarget: "axb35.power"

  readonly property var modes: ["quiet", "balanced", "performance"]
  readonly property string helper: "/usr/local/bin/axb35-power"

  property string power: ""
  property int temp: -1
  property var rpm: ({})
  property bool available: true
  property string error: ""
  property int modeIndex: 0
  property bool cursorActive: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function icon(mode) {
    if (mode === "quiet") return String.fromCodePoint(0xF0F86)
    if (mode === "balanced") return String.fromCodePoint(0xF0F85)
    if (mode === "performance") return String.fromCodePoint(0xF04C5)
    return String.fromCodePoint(0xF0210)
  }

  function label(mode) {
    return modes.indexOf(mode) >= 0 ? strings.t(mode) : strings.t("unknown")
  }

  function parseStatus(raw) {
    var next = {}
    String(raw || "").split("\n").forEach(function(line) {
      var match = /^([a-z0-9]{1,16})=([a-z0-9]{0,16})$/.exec(line.trim())
      if (match) next[match[1]] = match[2]
    })
    if (!("power" in next)) return
    available = true
    power = modes.indexOf(next.power) >= 0 ? next.power : ""
    var t = parseInt(next.temp, 10)
    temp = isFinite(t) && t >= 0 && t <= 120 ? t : -1
    var speeds = {}
    ;["fan1", "fan2", "fan3"].forEach(function(fan) {
      var v = parseInt(next[fan], 10)
      speeds[fan] = isFinite(v) && v >= 0 && v <= 20000 ? v : -1
    })
    rpm = speeds
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function setMode(mode) {
    if (modes.indexOf(mode) < 0 || actionProc.running) return
    error = ""
    actionProc.target = mode
    actionProc.command = ["sudo", "-n", helper, mode]
    actionProc.running = true
  }

  function cycle() {
    var i = modes.indexOf(power)
    setMode(modes[(i + 1) % modes.length])
  }

  function selectByDelta(delta) {
    modeIndex = Math.max(0, Math.min(modes.length - 1, modeIndex + delta))
  }

  function rpmText(fan) {
    var v = rpm[fan]
    return v === undefined || v < 0 ? "—" : strings.t("rpm").arg(Commons.I18n.formatNumber(v))
  }

  readonly property string tempText: temp < 0 ? "—" : strings.t("celsius").arg(Commons.I18n.formatNumber(temp))

  onOpenedChanged: {
    if (!opened) return
    refresh()
    var i = modes.indexOf(power)
    modeIndex = i >= 0 ? i : 0
    cursorActive = false
  }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseStatus(text) }
    onExited: function(exitCode) { if (exitCode !== 0) root.available = false }
  }

  Process {
    id: actionProc
    property string target: ""
    onExited: function(exitCode) {
      if (exitCode !== 0) root.error = strings.t("switchFailed").arg(root.label(target))
      root.refresh()
    }
  }

  Timer {
    interval: root.opened ? 3000 : 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon(root.power)
    slotSize: Style.bar.iconSlot
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycle()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.selectByDelta(dx !== 0 ? dx : dy)
      }
      onActivateRequested: if (root.cursorActive) root.setMode(root.modes[root.modeIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: strings.t("title")
          meta: root.available ? strings.t("status").arg(root.label(root.power)).arg(root.tempText) : strings.t("unavailable")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.icon(root.power)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: strings.t("mode")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: modeRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * (root.modes.length - 1)) / root.modes.length

            Repeater {
              model: root.modes
              Button {
                required property var modelData
                required property int index
                width: modeRow.cellWidth
                iconText: root.icon(String(modelData))
                iconSize: Style.font.title
                text: root.label(String(modelData))
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.power === modelData
                hasCursor: root.cursorActive && root.modeIndex === index
                onClicked: root.setMode(String(modelData))
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.modeIndex = index
                  }
                }
              }
            }
          }

          InfoValue {
            visible: root.error !== ""
            text: root.error
            opacity: 0.8
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(6)

          InfoPair { label: strings.t("temperature"); value: root.tempText }
          InfoPair { label: strings.t("cpuFans"); value: root.rpmText("fan1") + " · " + root.rpmText("fan2") }
          InfoPair { label: strings.t("systemFan"); value: root.rpmText("fan3") }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
