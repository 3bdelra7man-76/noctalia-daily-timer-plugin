import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root

  property var pluginApi: null
  property bool expanded: false
  property bool showCompleted: true
  property var rawTasks: []
  property ListModel filteredTasksModel: ListModel {}

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property bool backgroundEnabled: pluginApi?.pluginSettings?.showBackground !== undefined ? pluginApi.pluginSettings.showBackground : pluginApi?.manifest?.metadata?.defaultSettings?.showBackground
  readonly property int scaledMarginM: Math.round(Style.marginM * widgetScale)
  readonly property int scaledMarginS: Math.round(Style.marginS * widgetScale)
  readonly property int scaledMarginL: Math.round(Style.marginL * widgetScale)
  readonly property int scaledBaseWidgetSize: Math.round(Style.baseWidgetSize * widgetScale)
  readonly property int scaledFontSizeL: Math.round(Style.fontSizeL * widgetScale)
  readonly property int scaledFontSizeM: Math.round(Style.fontSizeM * widgetScale)
  readonly property int scaledFontSizeS: Math.round(Style.fontSizeS * widgetScale)
  readonly property int scaledRadiusM: Math.round(Style.radiusM * widgetScale)
  readonly property int scaledRadiusS: Math.round(Style.radiusS * widgetScale)

  showBackground: root.backgroundEnabled
  implicitWidth: Math.round(330 * widgetScale)
  implicitHeight: {
    var headerHeight = scaledBaseWidgetSize + scaledMarginL * 2;
    if (!expanded)
      return headerHeight;

    var visibleCount = Math.min(filteredTasksModel.count, 5);
    var listHeight = visibleCount === 0 ? scaledBaseWidgetSize : visibleCount * Math.round(70 * widgetScale) + Math.max(0, visibleCount - 1) * scaledMarginS;
    return Math.min(headerHeight + listHeight + scaledMarginM * 3, Math.round(480 * widgetScale));
  }

  Binding {
    target: root
    property: "rawTasks"
    value: pluginApi?.pluginSettings?.tasks || []
  }

  Binding {
    target: root
    property: "showCompleted"
    value: pluginApi?.pluginSettings?.showCompleted !== undefined ? pluginApi.pluginSettings.showCompleted : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted || true
  }

  Binding {
    target: root
    property: "expanded"
    value: pluginApi?.pluginSettings?.isExpanded !== undefined ? pluginApi.pluginSettings.isExpanded : pluginApi?.manifest?.metadata?.defaultSettings?.isExpanded || false
  }

  Component.onCompleted: {
    if (pluginApi)
      Logger.i("DailyTaskTimer", "Desktop widget initialized");
  }

  onPluginApiChanged: scheduleReload()
  onRawTasksChanged: scheduleReload()
  onShowCompletedChanged: scheduleReload()

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: scaledMarginM
    spacing: scaledMarginS

    Item {
      Layout.fillWidth: true
      height: scaledBaseWidgetSize

      MouseArea {
        anchors.fill: parent
        onClicked: {
          root.expanded = !root.expanded;
          if (pluginApi) {
            pluginApi.pluginSettings.isExpanded = root.expanded;
            pluginApi.saveSettings();
          }
        }
      }

      RowLayout {
        anchors.fill: parent
        spacing: scaledMarginS

        NIcon {
          icon: "timer"
          pointSize: scaledFontSizeL
        }

        NText {
          text: pluginApi?.tr("desktop_widget.header_title")
          font.pointSize: scaledFontSizeL
          font.weight: Font.Medium
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: desktopProgressText()
          color: Color.mOnSurfaceVariant
          font.pointSize: scaledFontSizeS
        }

        NIcon {
          icon: root.expanded ? "chevron-up" : "chevron-down"
          pointSize: scaledFontSizeM
          color: Color.mOnSurfaceVariant
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: expanded

      Rectangle {
        anchors.fill: parent
        color: root.backgroundEnabled ? Qt.rgba(0, 0, 0, 0.16) : "transparent"
        radius: scaledRadiusM
      }

      Flickable {
        id: taskFlickable
        anchors.fill: parent
        anchors.margins: scaledMarginM
        contentWidth: width
        contentHeight: taskColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        Column {
          id: taskColumn
          width: taskFlickable.width
          spacing: scaledMarginS

          Repeater {
            model: root.filteredTasksModel

            delegate: Rectangle {
              width: parent.width
              height: Math.round(70 * widgetScale)
              radius: scaledRadiusS
              color: root.backgroundEnabled ? Color.mSurface : "transparent"

              readonly property real progressValue: Math.max(0, Math.min(1, model.elapsedSeconds / Math.max(1, model.targetSeconds)))
              readonly property color taskColor: model.completed ? Color.mPrimary : (model.running ? Color.mPrimary : Color.mOnSurfaceVariant)

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: scaledMarginS
                spacing: Math.max(2, Math.round(4 * widgetScale))

                RowLayout {
                  Layout.fillWidth: true
                  spacing: scaledMarginS

                  NIcon {
                    icon: model.completed ? "circle-check" : (model.running ? "timer" : "circle")
                    pointSize: scaledFontSizeM
                    color: taskColor
                  }

                  NText {
                    text: model.title
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: model.completed ? Color.mOnSurfaceVariant : Color.mOnSurface
                    font.strikeout: model.completed
                    font.pointSize: scaledFontSizeS
                    font.weight: Font.Medium
                  }

                  NIconButton {
                    icon: model.running ? "pause" : "play"
                    enabled: !model.completed
                    baseSize: scaledBaseWidgetSize * 0.72
                    onClicked: {
                      if (model.running)
                        pauseTask(model.id);
                      else
                        startTask(model.id);
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Math.max(4, Math.round(6 * widgetScale))
                  radius: Style.iRadiusXXS
                  color: Color.mSurfaceVariant

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * progressValue
                    radius: parent.radius
                    color: taskColor
                  }
                }

                NText {
                  text: mainInstance ? mainInstance.formatSeconds(model.elapsedSeconds) + " / " + mainInstance.formatSeconds(model.targetSeconds) : "0:00 / 0:00"
                  color: Color.mOnSurfaceVariant
                  font.pointSize: scaledFontSizeS
                }
              }
            }
          }
        }
      }

      Item {
        anchors.fill: parent
        visible: root.filteredTasksModel.count === 0

        NText {
          anchors.centerIn: parent
          text: pluginApi?.tr("desktop_widget.empty_state")
          color: Color.mOnSurfaceVariant
          font.pointSize: scaledFontSizeM
        }
      }
    }
  }

  function scheduleReload() {
    Qt.callLater(loadTasks);
  }

  function startTask(taskId) {
    if (mainInstance)
      mainInstance.startTaskInternal(taskId);
  }

  function pauseTask(taskId) {
    if (mainInstance)
      mainInstance.pauseTaskInternal(taskId);
  }

  function desktopProgressText() {
    var total = pluginApi?.pluginSettings?.count || 0;
    var completed = pluginApi?.pluginSettings?.completedCount || 0;
    var text = pluginApi?.tr("desktop_widget.items_count") || "{completed} of {total}";
    return text.replace("{completed}", completed).replace("{total}", total);
  }

  function loadTasks() {
    filteredTasksModel.clear();

    var tasks = root.rawTasks || [];
    for (var i = 0; i < tasks.length; i++) {
      var task = tasks[i];
      if (root.showCompleted || !task.completed) {
        filteredTasksModel.append({
                                    id: task.id,
                                    title: task.title,
                                    targetSeconds: task.targetSeconds,
                                    elapsedSeconds: task.elapsedSeconds,
                                    completed: task.completed === true,
                                    running: task.running === true
                                  });
      }
    }
  }
}
