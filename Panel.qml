import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Mini calendar popup: a compact 3-week grid that appears beside the clock.
// Shows the current month with leading/trailing days faded out.
// Today is highlighted; previous/next chevrons step the view.
Panel {
  id: root
  moduleName: "obg.calendar"
  ipcTarget: "obg.calendar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. Updated by the wall clock.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // Month being viewed.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1, 12)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  // Week start follows the locale default.
  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), labelLocale.firstDayOfWeek)
  readonly property var labelLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property string monthYearLabel: labelLocale.standaloneMonthName(viewMonth, Locale.LongFormat) + " " + viewDate.toLocaleDateString(labelLocale, "yyyy")
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.miniCalendarGrid(viewYear, viewMonth, weekStart, todayKey)

  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(36)
  readonly property int cellHeight: Style.space(28)
  readonly property int cellSpacing: Style.space(2)
  readonly property int headerHeight: Style.space(16)

  function open() {
    root.today = new Date()
    root.goToToday()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var target = new Date(Date.UTC(viewYear, Number(viewMonth) + Number(delta), 1))
    root.viewYear = target.getUTCFullYear()
    root.viewMonth = target.getUTCMonth()
  }

  function refresh() {
    root.today = new Date()
  }

  // ---- Calendar popup content.
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: calendarColumn.implicitHeight
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "t" || t === "T") root.goToToday()
      }

      // Helper for year stepping
      function moveYear(delta) { root.moveMonth(delta * 12) }

      Column {
        id: calendarColumn
        anchors.centerIn: parent
        spacing: Style.space(6)

        // ---- Header: month/year label with navigation chevrons.
        Item {
          width: parent.width
          height: navRow.height

          Row {
            id: navRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(12)

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"
              tooltipText: "Previous month"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.moveMonth(-1)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.monthYearLabel
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
              tooltipText: "Next month"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.moveMonth(1)
            }
          }
        }

        // ---- Weekday headers row.
        Row {
          id: headerRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: root.cellSpacing

          Repeater {
            model: root.weekdays

            Text {
              textFormat: Text.PlainText
              required property var modelData
              width: root.cellWidth
              height: root.headerHeight
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: root.labelLocale.dayName(modelData, Locale.ShortFormat).toUpperCase()
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }
          }
        }

        // ---- Day grid: 3 weeks × 7 days.
        Column {
          id: gridColumn
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: root.cellSpacing

          Repeater {
            model: root.weeks

            Row {
              required property var modelData
              spacing: root.cellSpacing

              Repeater {
                model: modelData.days

                Rectangle {
                  required property var modelData
                  width: root.cellWidth
                  height: root.cellHeight
                  radius: Style.cornerRadius
                  color: modelData.today
                    ? Style.selectedStateColor(root.contentForeground, Commons.Color.accent)
                    : "transparent"
                  border.width: modelData.today ? 0 : Style.spacing.hairline
                  border.color: modelData.today ? "transparent" : Style.normalBorderFor(root.contentForeground, Commons.Color.accent)

                  Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: Commons.I18n.formatNumber(modelData.day)
                    color: modelData.today
                      ? Style.selectedTextColor(root.contentForeground, Commons.Color.accent)
                      : modelData.inMonth
                        ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.5) : root.contentForeground)
                        : Qt.darker(root.contentForeground, 2.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.today
                  }
                }
              }
            }
          }
        }

        // ---- Today quick-jump (only shown when not viewing current month).
        Item {
          width: parent.width
          height: todayRow.height
          visible: !root.viewingCurrentMonth

          Row {
            id: todayRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰃭"
              tooltipText: "Back to today"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.goToToday()
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.today.toLocaleDateString(root.labelLocale, Commons.I18n.t("clock.dayMonthFormat"))
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
