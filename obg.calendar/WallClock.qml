import QtQuick
import "Model.js" as Model

// Epoch-based minute timer that never goes negative during DST transitions.
Timer {
  id: root
  property date date: new Date()

  function arm() {
    interval = Model.msUntilNextTick(Date.now(), 60000)
    restart()
  }

  onTriggered: {
    date = new Date()
    arm()
  }
  Component.onCompleted: arm()
}
