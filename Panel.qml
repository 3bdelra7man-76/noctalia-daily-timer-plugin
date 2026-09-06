import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 720 * Style.uiScaleRatio
  property real contentPreferredHeight: 520 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  property ListModel filteredTasksModel: ListModel {}
  property var rawTasks: []
  property bool showCompleted: true
  property bool showEmptyState: false

  readonly property var mainInstance: pluginApi?.mainInstance

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

  Component.onCompleted: {
    if (pluginApi)
      Logger.i("DailyTaskTimer", "Panel initialized");
  }

  onPluginApiChanged: scheduleReload()
  onRawTasksChanged: scheduleReload()
  onShowCompletedChanged: scheduleReload()

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "timer"
              pointSize: Style.fontSizeXL
            }

            NText {
              text: pluginApi?.tr("panel.header.title")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            NText {
              text: progressSummary()
              color: Color.mOnSurfaceVariant
              font.pointSize: Style.fontSizeS
            }

            Item {
              Layout.fillWidth: true
            }

            NButton {
              text: pluginApi?.tr("panel.header.reset_today_button")
              icon: "rotate-ccw"
              fontSize: Style.fontSizeS
              onClicked: resetToday()
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NTextInput {
              id: taskTitleInput
              Layout.fillWidth: true
              placeholderText: pluginApi?.tr("panel.add_task.title_placeholder")
              Keys.onReturnPressed: addTask()
            }

            NTextInput {
              id: taskHoursInput
              Layout.preferredWidth: 76 * Style.uiScaleRatio
              placeholderText: pluginApi?.tr("panel.add_task.hours_placeholder")
              text: "1"
              Keys.onReturnPressed: addTask()
            }

            NTextInput {
              id: taskMinutesInput
              Layout.preferredWidth: 92 * Style.uiScaleRatio
              placeholderText: pluginApi?.tr("panel.add_task.minutes_placeholder")
              text: "0"
              Keys.onReturnPressed: addTask()
            }

            NIconButton {
              icon: "plus"
              tooltipText: pluginApi?.tr("panel.add_task.add_button")
              baseSize: Style.baseWidgetSize * 1.15
              customRadius: Style.iRadiusS
              onClicked: addTask()
            }
          }

          ListView {
            id: taskListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredTasksModel
            spacing: Style.marginS
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
              id: delegateItem
              width: ListView.view.width
              height: 104 * Style.uiScaleRatio

              required property int index
              required property var modelData

              readonly property real progressValue: Math.max(0, Math.min(1, modelData.elapsedSeconds / Math.max(1, modelData.targetSeconds)))
              readonly property color stateColor: modelData.completed ? Color.mPrimary : (modelData.running ? Color.mPrimary : Color.mOnSurfaceVariant)

              Rectangle {
                anchors.fill: parent
                color: Color.mSurface
                radius: Style.radiusS

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginS

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NIcon {
                      icon: modelData.completed ? "circle-check" : (modelData.running ? "timer" : "circle")
                      pointSize: Style.fontSizeM
                      color: delegateItem.stateColor
                    }

                    NText {
                      text: modelData.title
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                      color: modelData.completed ? Color.mOnSurfaceVariant : Color.mOnSurface
                      font.strikeout: modelData.completed
                      font.pointSize: Style.fontSizeM
                      font.weight: Font.Medium
                    }

                    NText {
                      text: taskStateText(modelData)
                      color: delegateItem.stateColor
                      font.pointSize: Style.fontSizeS
                    }

                    NIconButton {
                      icon: modelData.running ? "pause" : "play"
                      tooltipText: modelData.running ? pluginApi?.tr("panel.task_item.pause_button_tooltip") : pluginApi?.tr("panel.task_item.start_button_tooltip")
                      enabled: !modelData.completed
                      baseSize: Style.baseWidgetSize * 0.95
                      onClicked: {
                        if (modelData.running)
                          pauseTask(modelData.id);
                        else
                          startTask(modelData.id);
                      }
                    }

                    NIconButton {
                      icon: "pencil"
                      tooltipText: pluginApi?.tr("panel.task_item.edit_button_tooltip")
                      baseSize: Style.baseWidgetSize * 0.95
                      onClicked: openEditTask(modelData)
                    }

                    NIconButton {
                      icon: "rotate-ccw"
                      tooltipText: pluginApi?.tr("panel.task_item.reset_button_tooltip")
                      baseSize: Style.baseWidgetSize * 0.95
                      onClicked: resetTask(modelData.id)
                    }

                    NIconButton {
                      icon: "trash"
                      tooltipText: pluginApi?.tr("panel.task_item.delete_button_tooltip")
                      colorFg: Color.mError
                      baseSize: Style.baseWidgetSize * 0.95
                      onClicked: removeTask(modelData.id)
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8 * Style.uiScaleRatio
                    color: Color.mSurfaceVariant
                    radius: Style.iRadiusXXS

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: parent.width * delegateItem.progressValue
                      radius: parent.radius
                      color: delegateItem.stateColor
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                      text: mainInstance ? mainInstance.formatSeconds(modelData.elapsedSeconds) : "0:00"
                      color: Color.mOnSurface
                      font.pointSize: Style.fontSizeS
                      font.weight: Font.Medium
                    }

                    NText {
                      text: "/"
                      color: Color.mOnSurfaceVariant
                      font.pointSize: Style.fontSizeS
                    }

                    NText {
                      text: mainInstance ? mainInstance.formatSeconds(modelData.targetSeconds) : "0:00"
                      color: Color.mOnSurfaceVariant
                      font.pointSize: Style.fontSizeS
                    }

                    Item {
                      Layout.fillWidth: true
                    }

                    NText {
                      text: mainInstance ? mainInstance.formatSeconds(Math.max(0, modelData.targetSeconds - modelData.elapsedSeconds)) : "0:00"
                      color: Color.mOnSurfaceVariant
                      font.pointSize: Style.fontSizeS
                    }
                  }
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.filteredTasksModel.count === 0 && root.showEmptyState

            NText {
              anchors.centerIn: parent
              text: pluginApi?.tr("panel.empty_state.message")
              color: Color.mOnSurfaceVariant
              font.pointSize: Style.fontSizeM
            }
          }
        }
      }
    }
  }

  Popup {
    id: editDialog

    property var taskId: ""
    property int targetSeconds: 3600

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: 420 * Style.uiScaleRatio
    height: 220 * Style.uiScaleRatio

    background: Rectangle {
      color: Color.mSurface
      border.color: Color.mOutline
      border.width: Style.borderS
      radius: Style.radiusL
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("panel.edit_task.title")
        font.pointSize: Style.fontSizeL
        font.weight: Font.Medium
        color: Color.mOnSurface
      }

      NTextInput {
        id: editTitleInput
        Layout.fillWidth: true
        placeholderText: pluginApi?.tr("panel.add_task.title_placeholder")
        Keys.onReturnPressed: saveEditedTask()
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NTextInput {
          id: editHoursInput
          Layout.fillWidth: true
          placeholderText: pluginApi?.tr("panel.add_task.hours_placeholder")
          Keys.onReturnPressed: saveEditedTask()
        }

        NTextInput {
          id: editMinutesInput
          Layout.fillWidth: true
          placeholderText: pluginApi?.tr("panel.add_task.minutes_placeholder")
          Keys.onReturnPressed: saveEditedTask()
        }
      }

      Item {
        Layout.fillHeight: true
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Item {
          Layout.fillWidth: true
        }

        NButton {
          text: pluginApi?.tr("panel.edit_task.cancel_button")
          onClicked: editDialog.close()
        }

        NButton {
          text: pluginApi?.tr("panel.edit_task.save_button")
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: saveEditedTask()
        }
      }
    }
  }

  function scheduleReload() {
    Qt.callLater(loadTasks);
  }

  function addTask() {
    if (!mainInstance)
      return;

    var targetSeconds = durationSecondsFromInputs(taskHoursInput.text, taskMinutesInput.text);
    if (mainInstance.createTask(taskTitleInput.text, targetSeconds)) {
      taskTitleInput.text = "";
      taskTitleInput.forceActiveFocus();
    }
  }

  function openEditTask(task) {
    editDialog.taskId = task.id;
    editDialog.targetSeconds = task.targetSeconds;
    editTitleInput.text = task.title;
    setDurationInputs(task.targetSeconds, editHoursInput, editMinutesInput);
    editDialog.open();
  }

  function saveEditedTask() {
    if (!mainInstance)
      return;

    var targetSeconds = durationSecondsFromInputs(editHoursInput.text, editMinutesInput.text);
    if (mainInstance.updateTaskDefinition(editDialog.taskId, editTitleInput.text, targetSeconds))
      editDialog.close();
  }

  function startTask(taskId) {
    if (mainInstance)
      mainInstance.startTaskInternal(taskId);
  }

  function pauseTask(taskId) {
    if (mainInstance)
      mainInstance.pauseTaskInternal(taskId);
  }

  function resetTask(taskId) {
    if (mainInstance)
      mainInstance.resetTaskInternal(taskId);
  }

  function removeTask(taskId) {
    if (mainInstance)
      mainInstance.deleteTask(taskId);
  }

  function resetToday() {
    if (mainInstance)
      mainInstance.resetAllForToday(mainInstance.todayKey());
  }

  function durationSecondsFromInputs(hoursText, minutesText) {
    var hours = parseInteger(hoursText);
    var minutes = parseInteger(minutesText);
    return Math.max(0, (hours * 3600) + (minutes * 60));
  }

  function parseInteger(value) {
    var parsed = Math.floor(Number(String(value || "").trim()));
    if (isNaN(parsed) || parsed < 0)
      return 0;
    return parsed;
  }

  function setDurationInputs(seconds, hoursInput, minutesInput) {
    var totalMinutes = Math.floor(seconds / 60);
    hoursInput.text = String(Math.floor(totalMinutes / 60));
    minutesInput.text = String(totalMinutes % 60);
  }

  function taskStateText(task) {
    if (task.completed)
      return pluginApi?.tr("panel.task_item.completed");
    if (task.running)
      return pluginApi?.tr("panel.task_item.running");
    return pluginApi?.tr("panel.task_item.pending");
  }

  function progressSummary() {
    var total = pluginApi?.pluginSettings?.count || 0;
    var completed = pluginApi?.pluginSettings?.completedCount || 0;
    var text = pluginApi?.tr("bar_widget.progress") || "{completed} of {total} done";
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
                                    running: task.running === true,
                                    startedAt: task.startedAt,
                                    createdAt: task.createdAt
                                  });
      }
    }

    root.showEmptyState = filteredTasksModel.count === 0;
  }
}
