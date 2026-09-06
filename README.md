# Daily Task Timer

A Noctalia Shell plugin for daily recurring tasks that must be completed by running their timers.

## Features

- Add daily tasks with a required duration.
- Start, pause, reset, edit, and delete tasks.
- Tasks are completed only when their elapsed timer reaches the target duration.
- Task progress resets automatically when the local date changes.
- Bar widget, desktop widget, panel, settings, control center widget, and IPC support.

## Example

Create these once:

- Study: 1 hour
- Problem solving: 2 hours

Each day, start a task when you begin working on it. Pause it when you stop. When the timer reaches the configured duration, the task is marked done. On the next local day, the task becomes pending again with zero elapsed time.

## IPC Commands

```bash
# Add a task with a duration in seconds
qs -c noctalia-shell ipc call plugin:daily-task-timer addTask "Study" 3600

# Add a task with a duration in minutes
qs -c noctalia-shell ipc call plugin:daily-task-timer addTaskMinutes "Problem solving" 120

# Start, pause, reset, or remove a task
qs -c noctalia-shell ipc call plugin:daily-task-timer startTask "1234567890"
qs -c noctalia-shell ipc call plugin:daily-task-timer pauseTask "1234567890"
qs -c noctalia-shell ipc call plugin:daily-task-timer resetTask "1234567890"
qs -c noctalia-shell ipc call plugin:daily-task-timer removeTask "1234567890"

# Read state
qs -c noctalia-shell ipc call plugin:daily-task-timer getTasks
qs -c noctalia-shell ipc call plugin:daily-task-timer getStatus

# Reset the current day manually
qs -c noctalia-shell ipc call plugin:daily-task-timer resetToday

# Toggle the panel
qs -c noctalia-shell ipc call plugin:daily-task-timer togglePanel
```
