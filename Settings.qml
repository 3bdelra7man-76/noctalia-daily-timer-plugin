import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property bool valueShowCompleted: pluginApi?.pluginSettings?.showCompleted !== undefined ? pluginApi.pluginSettings.showCompleted : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted
  property bool valueShowBackground: pluginApi?.pluginSettings?.showBackground !== undefined ? pluginApi.pluginSettings.showBackground : pluginApi?.manifest?.metadata?.defaultSettings?.showBackground
  property bool valueAutoPauseOtherTasks: pluginApi?.pluginSettings?.autoPauseOtherTasks !== undefined ? pluginApi.pluginSettings.autoPauseOtherTasks : pluginApi?.manifest?.metadata?.defaultSettings?.autoPauseOtherTasks

  readonly property var mainInstance: pluginApi?.mainInstance

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("DailyTaskTimer", "Settings UI loaded");
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show_completed.label")
    description: pluginApi?.tr("settings.show_completed.description")
    checked: root.valueShowCompleted
    onToggled: function (checked) {
      root.valueShowCompleted = checked;
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.background_color.label")
    description: pluginApi?.tr("settings.background_color.description")
    checked: root.valueShowBackground
    onToggled: function (checked) {
      root.valueShowBackground = checked;
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.auto_pause_other_tasks.label")
    description: pluginApi?.tr("settings.auto_pause_other_tasks.description")
    checked: root.valueAutoPauseOtherTasks
    onToggled: function (checked) {
      root.valueAutoPauseOtherTasks = checked;
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: pluginApi?.tr("settings.reset_today.label")
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
      }

      NText {
        text: pluginApi?.tr("settings.reset_today.description")
        color: Color.mOnSurfaceVariant
        font.pointSize: Style.fontSizeS
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }
    }

    NButton {
      text: pluginApi?.tr("settings.reset_today.button")
      icon: "rotate-ccw"
      onClicked: {
        if (mainInstance) {
          mainInstance.resetAllForToday(mainInstance.todayKey());
          ToastService.showNotice(pluginApi.tr("main.reset_today"));
        }
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("DailyTaskTimer", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.showCompleted = root.valueShowCompleted;
    pluginApi.pluginSettings.showBackground = root.valueShowBackground;
    pluginApi.pluginSettings.autoPauseOtherTasks = root.valueAutoPauseOtherTasks;
    pluginApi.saveSettings();
    Logger.i("DailyTaskTimer", "Settings saved successfully");
  }
}
