import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, with a mini calendar popup on left-click.
// Shows "Mon 26 Jan 14:30" style label. Right-click cycles display format.
BarWidget {
  id: root
  moduleName: "obg.calendar"

  property date displayDate: clock.date

  // Format ring for cycling display format with right-click.
  readonly property var formatRing: clockFormats
  readonly property string activeFormat: configuredFormat
  readonly property bool showsSeconds: clockNeedsSeconds(activeFormat)
  readonly property string displayText: formatted(displayDate)

  // Format options for the bar label.
  readonly property var clockFormats: [
    "ddd d MMM HH:mm",
    "dddd, d MMMM HH:mm",
    "ddd d MMM h:mm AP",
    "dddd, d MMMM h:mm AP",
    "d MMM HH:mm",
    "ddd HH:mm"
  ]

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var idx = root.clockFormats.indexOf(current)
    var next = root.clockFormats[(idx + 1) % root.clockFormats.length]
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.format = next

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function clockNeedsSeconds(format) {
    var text = String(format === undefined || format === null ? "" : format)
    return /s/.test(text.replace(/'[^']*'?'/g, ""))
  }

  // The locale for month/day names follows the Omarchy language.
  readonly property var formatLocale: Qt.locale(I18n.formatLocale)

  function formatted(date) {
    return date.toLocaleString(root.formatLocale, activeFormat)
  }

  // ---- Popup lifecycle for the bar's popout coordinator.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Style.space(24)

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  WallClock {
    id: clock
    step: 60000
    onDateChanged: root.displayDate = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  ShellIpc {
    target: "obg.calendar"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    labelVisible: true
    hasVisualContent: text !== ""
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: "Calendar — left click to open"
    pressFeedbackButtons: Qt.NoButton

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else root.togglePanel()
    }
  }
}
