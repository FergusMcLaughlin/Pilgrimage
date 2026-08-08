# Codex Help So Far and Working Process

Date: 2026-08-05

## Summary

Codex found, installed, enabled, and tested the Godot **Project Time Tracker** add-on for the Pilgrimage project.

The add-on itself loaded successfully. During the test, Godot also displayed some pre-existing project script errors. Codex reported those errors but did not change or fix them because the request was only to install the add-on.

## What Codex Helped With

### 1. Found the downloaded add-on

The downloaded Time Tracker files were found in:

`/home/fergus/Downloads/godot-project-time-tracker-871a8bd081e6697d634f36da607f65c3e8a346f8(1)/`

There are also ZIP copies in the Downloads folder.

The actual Godot plug-in is named **Project Timer**, and its plug-in folder is:

`addons/project_time_tracker/`

### 2. Found the Godot project

Codex identified the Pilgrimage project here:

`/home/fergus/Workspace/Pilgrimage/`

Its main project configuration file is:

`/home/fergus/Workspace/Pilgrimage/project.godot`

### 3. Installed the add-on

The plug-in was copied to:

`/home/fergus/Workspace/Pilgrimage/addons/project_time_tracker/`

The installed folder contains the plug-in configuration, scripts, scene, and icon files.

### 4. Enabled the add-on

Codex added the following setting to `project.godot`:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/project_time_tracker/plugin.cfg")
```

This tells Godot to enable Project Time Tracker when the Pilgrimage project opens.

You can also inspect this setting in Godot under:

**Project > Project Settings > Plugins**

### 5. Tested the installation

Codex opened the project using Godot 4.7 in headless editor mode. Godot:

- discovered and initialized the plug-in;
- imported its icon;
- loaded the editor layout;
- exited successfully.

No error from the Project Time Tracker plug-in was reported.

## Other Errors Godot Reported

These errors appeared in the terminal during the verification. They are part of the existing project and are not caused by Time Tracker.

### Missing card scene

Godot reported this from:

`res://src/main/cards/card_loaders/create_card.gd:3`

The script tries to preload:

`res://src/cards/card.tscn`

Godot could not find that file at the specified location. This caused dependent scripts such as `deck_card_bag.gd`, `journey_deck.gd`, and `action_processor.gd` to fail compilation.

### Missing function

Godot reported this from:

`res://src/main/singletons/effects/effect_processor.gd:32`

The script refers to a function named:

`_queueHealthGain()`

Godot could not find that function in the script.

These errors should also appear in Godot's **Debugger > Errors** panel. They have not yet been fixed.

## How Codex Normally Works

When asked to change the project, Codex normally follows this process:

1. **Understand the request.** Determine the intended result and keep the work within that scope.
2. **Inspect the project first.** Find the relevant files, understand the current structure, and check for existing work that should be preserved.
3. **Make focused changes.** Edit only what is needed and avoid overwriting unrelated changes.
4. **Verify the result.** Run Godot, tests, or another appropriate check when possible.
5. **Separate new problems from existing ones.** Clearly state whether an error was introduced by the change or already existed.
6. **Report what changed.** Explain the result, name the important files, and mention anything that still needs attention.

Codex will not normally fix unrelated problems unless asked. This keeps each task controlled and makes it easier to understand which change caused which result.

## Useful Ways to Ask Codex for Help

Requests can be written in ordinary language. Helpful examples include:

- “Find out why this Godot error is happening, but do not change anything yet.”
- “Fix the missing `card.tscn` reference and test the project.”
- “Explain this script to me in simple terms.”
- “Implement this feature and write an Obsidian note explaining it.”
- “Review my current changes without editing them.”
- “Run the relevant tests and fix any failures caused by this change.”

It is useful to say whether Codex should only investigate, make the fix, or both. If no special format is requested, Codex will use the safest reasonable interpretation of the task.

## Suggested Next Steps

1. Open Pilgrimage in Godot and confirm that Project Timer is visible and enabled.
2. Ask Codex to investigate the missing `card.tscn` reference.
3. Ask Codex to investigate the missing `_queueHealthGain()` function.
4. Keep those fixes as separate tasks so each one can be tested clearly.
