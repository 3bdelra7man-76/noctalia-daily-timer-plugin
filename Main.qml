import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var rawTasks: []
  property bool initialized: false
  property int tickSaveCounter: 0

  Component.onCompleted: initialize()
  onPluginApiChanged: initialize()

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: pluginApi !== null
    onTriggered: root.tick()
  }

  IpcHandler {
    target: "plugin:daily-task-timer"

    function togglePanel() {
      if (!pluginApi)
        return;
      pluginApi.withCurrentScreen(screen => {
                                    pluginApi.togglePanel(screen);
                                  });
    }

    function getTasks(): string {
      root.checkDailyReset();
      return JSON.stringify(root.rawTasks);
    }

    function getStatus(): string {
      root.checkDailyReset();
      return JSON.stringify({
                              date: root.todayKey(),
                              total: root.rawTasks.length,
                              completed: root.completedCount(),
                              active: root.rawTasks.length - root.completedCount(),
                              activeTaskId: root.activeTaskId()
                            });
    }

    function addTask(title: string, targetSeconds: int) {
      if (root.createTask(title, targetSeconds)) {
        ToastService.showNotice(pluginApi.tr("main.added_task"));
      } else {
        ToastService.showError(pluginApi.tr("main.error_create_failed"));
      }
    }

    function addTaskMinutes(title: string, minutes: int) {
      addTask(title, minutes * 60);
    }

    function updateTask(id: string, title: string, targetSeconds: int) {
      root.updateTaskDefinition(id, title, targetSeconds) ? ToastService.showNotice(pluginApi.tr("main.updated_task")) : ToastService.showError(pluginApi.tr("main.error_update_failed"));
    }

    function startTask(id: string) {
      root.startTaskInternal(id) ? ToastService.showNotice(pluginApi.tr("main.started_task")) : ToastService.showError(pluginApi.tr("main.error_task_not_found"));
    }

    function pauseTask(id: string) {
      root.pauseTaskInternal(id) ? ToastService.showNotice(pluginApi.tr("main.paused_task")) : ToastService.showError(pluginApi.tr("main.error_task_not_found"));
    }

    function resetTask(id: string) {
      root.resetTaskInternal(id) ? ToastService.showNotice(pluginApi.tr("main.reset_task")) : ToastService.showError(pluginApi.tr("main.error_task_not_found"));
    }

    function removeTask(id: string) {
      root.deleteTask(id) ? ToastService.showNotice(pluginApi.tr("main.removed_task")) : ToastService.showError(pluginApi.tr("main.error_remove_failed"));
    }

    function resetToday() {
      root.resetAllForToday(root.todayKey());
      ToastService.showNotice(pluginApi.tr("main.reset_today"));
    }
  }

  function initialize() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;

    ensureSettings();
    rawTasks = normalizeTasks(pluginApi.pluginSettings.tasks || []);

    if (pluginApi.pluginSettings.currentDate !== todayKey()) {
      resetAllForToday(todayKey());
      initialized = true;
      return;
    }

    applyRunningElapsed(Date.now());
    publishTasks(true);
    initialized = true;
  }

  function ensureSettings() {
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings || {};

    if (!pluginApi.pluginSettings.tasks)
      pluginApi.pluginSettings.tasks = [];
    if (pluginApi.pluginSettings.currentDate === undefined)
      pluginApi.pluginSettings.currentDate = todayKey();
    if (pluginApi.pluginSettings.count === undefined)
      pluginApi.pluginSettings.count = 0;
    if (pluginApi.pluginSettings.completedCount === undefined)
      pluginApi.pluginSettings.completedCount = 0;
    if (pluginApi.pluginSettings.activeTaskId === undefined)
      pluginApi.pluginSettings.activeTaskId = "";
    if (pluginApi.pluginSettings.showCompleted === undefined)
      pluginApi.pluginSettings.showCompleted = defaults.showCompleted ?? true;
    if (pluginApi.pluginSettings.showBackground === undefined)
      pluginApi.pluginSettings.showBackground = defaults.showBackground ?? true;
    if (pluginApi.pluginSettings.isExpanded === undefined)
      pluginApi.pluginSettings.isExpanded = defaults.isExpanded ?? false;
    if (pluginApi.pluginSettings.autoPauseOtherTasks === undefined)
      pluginApi.pluginSettings.autoPauseOtherTasks = defaults.autoPauseOtherTasks ?? true;
  }

  function todayKey() {
    var now = new Date();
    var month = pad2(now.getMonth() + 1);
    var day = pad2(now.getDate());
    return now.getFullYear() + "-" + month + "-" + day;
  }

  function checkDailyReset() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return false;

    var today = todayKey();
    if (pluginApi.pluginSettings.currentDate !== today) {
      resetAllForToday(today);
      return true;
    }
    return false;
  }

  function resetAllForToday(dateKey) {
    for (var i = 0; i < rawTasks.length; i++) {
      rawTasks[i].elapsedSeconds = 0;
      rawTasks[i].completed = false;
      rawTasks[i].running = false;
      rawTasks[i].startedAt = 0;
    }

    pluginApi.pluginSettings.currentDate = dateKey;
    pluginApi.pluginSettings.activeTaskId = "";
    publishTasks(true);
  }

  function tick() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;

    if (checkDailyReset())
      return;

    var result = applyRunningElapsed(Date.now());
    if (!result.changed)
      return;

    tickSaveCounter++;
    publishTasks(result.completedCount > 0 || tickSaveCounter >= 15);

    if (tickSaveCounter >= 15)
      tickSaveCounter = 0;
  }

  function applyRunningElapsed(nowMs) {
    var changed = false;
    var completedNow = 0;

    for (var i = 0; i < rawTasks.length; i++) {
      var task = rawTasks[i];
      if (!task.running || task.completed)
        continue;

      if (!task.startedAt || task.startedAt <= 0) {
        task.startedAt = nowMs;
        changed = true;
        continue;
      }

      var delta = Math.floor((nowMs - task.startedAt) / 1000);
      if (delta <= 0)
        continue;

      task.elapsedSeconds = Math.min(task.targetSeconds, task.elapsedSeconds + delta);
      task.startedAt = nowMs;
      changed = true;

      if (task.elapsedSeconds >= task.targetSeconds) {
        task.elapsedSeconds = task.targetSeconds;
        task.completed = true;
        task.running = false;
        task.startedAt = 0;
        completedNow++;

        if (pluginApi) {
          ToastService.showNotice(pluginApi.tr("main.completed_task") + ": " + task.title);
        }
      }
    }

    return {
      changed: changed,
      completedCount: completedNow
    };
  }

  function createTask(title, targetSeconds) {
    checkDailyReset();

    var normalizedTitle = String(title || "").trim();
    var normalizedTarget = normalizeDuration(targetSeconds);

    if (!normalizedTitle) {
      ToastService.showError(pluginApi.tr("main.error_title_empty"));
      return false;
    }
    if (normalizedTarget < 60) {
      ToastService.showError(pluginApi.tr("main.error_invalid_duration"));
      return false;
    }

    rawTasks.push({
                    id: Date.now() + rawTasks.length,
                    title: normalizedTitle,
                    targetSeconds: normalizedTarget,
                    elapsedSeconds: 0,
                    completed: false,
                    running: false,
                    startedAt: 0,
                    createdAt: new Date().toISOString()
                  });
    publishTasks(true);
    return true;
  }

  function updateTaskDefinition(id, title, targetSeconds) {
    checkDailyReset();

    var index = findTaskIndex(id);
    if (index === -1)
      return false;

    var normalizedTitle = String(title || "").trim();
    var normalizedTarget = normalizeDuration(targetSeconds);

    if (!normalizedTitle) {
      ToastService.showError(pluginApi.tr("main.error_title_empty"));
      return false;
    }
    if (normalizedTarget < 60) {
      ToastService.showError(pluginApi.tr("main.error_invalid_duration"));
      return false;
    }

    applyRunningElapsed(Date.now());

    rawTasks[index].title = normalizedTitle;
    rawTasks[index].targetSeconds = normalizedTarget;
    rawTasks[index].elapsedSeconds = Math.min(rawTasks[index].elapsedSeconds, normalizedTarget);
    rawTasks[index].completed = rawTasks[index].elapsedSeconds >= normalizedTarget;
    if (rawTasks[index].completed) {
      rawTasks[index].running = false;
      rawTasks[index].startedAt = 0;
    }

    publishTasks(true);
    return true;
  }

  function startTaskInternal(id) {
    checkDailyReset();
    applyRunningElapsed(Date.now());

    var index = findTaskIndex(id);
    if (index === -1)
      return false;

    var task = rawTasks[index];
    if (task.completed)
      return false;

    var nowMs = Date.now();
    if (pluginApi.pluginSettings.autoPauseOtherTasks !== false) {
      for (var i = 0; i < rawTasks.length; i++) {
        if (i !== index && rawTasks[i].running) {
          rawTasks[i].running = false;
          rawTasks[i].startedAt = 0;
        }
      }
    }

    task.running = true;
    task.startedAt = nowMs;
    publishTasks(true);
    return true;
  }

  function pauseTaskInternal(id) {
    checkDailyReset();
    applyRunningElapsed(Date.now());

    var index = findTaskIndex(id);
    if (index === -1)
      return false;

    rawTasks[index].running = false;
    rawTasks[index].startedAt = 0;
    publishTasks(true);
    return true;
  }

  function resetTaskInternal(id) {
    checkDailyReset();

    var index = findTaskIndex(id);
    if (index === -1)
      return false;

    rawTasks[index].elapsedSeconds = 0;
    rawTasks[index].completed = false;
    rawTasks[index].running = false;
    rawTasks[index].startedAt = 0;
    publishTasks(true);
    return true;
  }

  function deleteTask(id) {
    checkDailyReset();

    var index = findTaskIndex(id);
    if (index === -1)
      return false;

    rawTasks.splice(index, 1);
    publishTasks(true);
    return true;
  }

  function normalizeDuration(value) {
    var parsed = Math.floor(Number(value));
    if (isNaN(parsed) || parsed < 0)
      return 0;
    return parsed;
  }

  function normalizeTasks(tasks) {
    var normalized = [];
    for (var i = 0; i < tasks.length; i++) {
      var task = tasks[i] || {};
      var target = normalizeDuration(task.targetSeconds || task.durationSeconds || 3600);
      var elapsed = normalizeDuration(task.elapsedSeconds || 0);
      var safeTarget = Math.max(60, target);
      var safeElapsed = Math.min(elapsed, safeTarget);

      normalized.push({
                        id: task.id !== undefined ? task.id : Date.now() + i,
                        title: String(task.title || task.text || "").trim(),
                        targetSeconds: safeTarget,
                        elapsedSeconds: safeElapsed,
                        completed: task.completed === true || safeElapsed >= safeTarget,
                        running: task.running === true,
                        startedAt: Number(task.startedAt || 0),
                        createdAt: task.createdAt || new Date().toISOString()
                      });

      if (normalized[normalized.length - 1].completed) {
        normalized[normalized.length - 1].running = false;
        normalized[normalized.length - 1].startedAt = 0;
      }
    }
    return normalized;
  }

  function cloneTasks(tasks) {
    var cloned = [];
    for (var i = 0; i < tasks.length; i++) {
      cloned.push({
                    id: tasks[i].id,
                    title: tasks[i].title,
                    targetSeconds: tasks[i].targetSeconds,
                    elapsedSeconds: tasks[i].elapsedSeconds,
                    completed: tasks[i].completed,
                    running: tasks[i].running,
                    startedAt: tasks[i].startedAt,
                    createdAt: tasks[i].createdAt
                  });
    }
    return cloned;
  }

  function publishTasks(shouldSave) {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;

    rawTasks = cloneTasks(rawTasks);
    pluginApi.pluginSettings.tasks = cloneTasks(rawTasks);
    pluginApi.pluginSettings.count = rawTasks.length;
    pluginApi.pluginSettings.completedCount = completedCount();
    pluginApi.pluginSettings.activeTaskId = activeTaskId();

    if (shouldSave)
      pluginApi.saveSettings();
  }

  function findTask(id) {
    return rawTasks.find(t => t.id == id) || null;
  }

  function findTaskIndex(id) {
    return rawTasks.findIndex(t => t.id == id);
  }

  function completedCount() {
    var count = 0;
    for (var i = 0; i < rawTasks.length; i++) {
      if (rawTasks[i].completed)
        count++;
    }
    return count;
  }

  function activeTaskId() {
    for (var i = 0; i < rawTasks.length; i++) {
      if (rawTasks[i].running)
        return String(rawTasks[i].id);
    }
    return "";
  }

  function progressForTask(task) {
    if (!task || !task.targetSeconds)
      return 0;
    return Math.max(0, Math.min(1, task.elapsedSeconds / task.targetSeconds));
  }

  function remainingSeconds(task) {
    if (!task)
      return 0;
    return Math.max(0, task.targetSeconds - task.elapsedSeconds);
  }

  function formatSeconds(totalSeconds) {
    var total = Math.max(0, Math.floor(Number(totalSeconds || 0)));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var seconds = total % 60;

    if (hours > 0)
      return hours + ":" + pad2(minutes) + ":" + pad2(seconds);

    return minutes + ":" + pad2(seconds);
  }

  function pad2(value) {
    return value < 10 ? "0" + value : String(value);
  }
}
