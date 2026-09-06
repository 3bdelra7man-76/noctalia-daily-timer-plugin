import QtQuick
import Quickshell
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  icon: "timer"

  function getTooltipText() {
    if (!pluginApi)
      return "Daily Task Timer";

    var total = pluginApi.pluginSettings?.count || 0;
    var completed = pluginApi.pluginSettings?.completedCount || 0;
    if (total === 0)
      return pluginApi.tr("control_center.empty");

    return pluginApi.tr("control_center.tooltip").replace("{completed}", completed).replace("{total}", total);
  }

  tooltipText: getTooltipText()

  onClicked: {
    if (pluginApi)
      pluginApi.togglePanel(screen);
  }

  onRightClicked: {
    if (pluginApi && pluginApi.manifest)
      BarService.openPluginSettings(screen, pluginApi.manifest);
  }
}
