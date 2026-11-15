extends Node

var failures := 0
var passed := 0

func _ready() -> void:
	var cursor = CursorController
	var realTheme: CursorSkin = cursor.defaultTheme
	var frameSeconds = 1.0 / realTheme.idleFps

	_expect(cursor.applyTheme(realTheme), "The real cursor theme applies.")
	_expect(cursor.pointerFrames.size() == realTheme.pointerFrameCount, "Pointer sheet is cut into pointerFrameCount frames.")
	_expect(cursor.grabbableFrames.size() == realTheme.grabbableFrameCount, "Grabbable sheet is cut into grabbableFrameCount frames.")
	_expect(cursor.grabFrames.size() == realTheme.grabFrameCount, "Grab sheet is cut into grabFrameCount frames.")
	_expect(Vector2i(cursor.pointerFrames[0].get_size()) == realTheme.pointerFrameSize, "Pointer frames are pointerFrameSize.")
	_expect(cursor.currentPointerFrame == 0 and cursor.currentGrabbableFrame == 0, "Applying a theme starts on frame 0.")

	_expect(!cursor.applyTheme(null) and cursor.theme == null, "No theme falls back to the system cursor.")
	var noSheet: CursorSkin = realTheme.duplicate()
	noSheet.pointerSheet = null
	_expect(!cursor.applyTheme(noSheet) and cursor.theme == null, "A missing sheet falls back to the system cursor.")
	var badClick: CursorSkin = realTheme.duplicate()
	badClick.clickLastFrame = badClick.pointerFrameCount
	_expect(!cursor.applyTheme(badClick) and cursor.theme == null, "A clickLastFrame outside the sheet falls back to the system cursor.")

	var control := Control.new()
	cursor.markGrabbable(control, true)
	_expect(cursor.isGrabbable(control), "markGrabbable(true) makes a control grabbable.")
	cursor.markGrabbable(control, false)
	_expect(!cursor.isGrabbable(control) and !cursor.isGrabbable(null), "markGrabbable(false) and null are not grabbable.")
	control.free()

	cursor.applyTheme(realTheme)
	cursor._process(realTheme.idleDelaySeconds / 2.0)
	_expect(cursor.currentPointerFrame == 0 and !cursor.isIdling, "No idle before idleDelaySeconds.")
	cursor._process(realTheme.idleDelaySeconds + frameSeconds)
	_expect(cursor.isIdling and cursor.currentPointerFrame == 1 and cursor.currentGrabbableFrame == 1, "Still past the delay: pointer and grabbable step to frame 1.")
	cursor._input(_mouseMotion(cursor.stillAnchor + Vector2(1, 0)))
	_expect(cursor.isIdling and cursor.currentPointerFrame == 1, "Jitter under wakeDistance doesn't stop the idle.")
	cursor._input(_mouseMotion(cursor.stillAnchor + Vector2(realTheme.wakeDistance + 1.0, 0)))
	_expect(!cursor.isIdling and cursor.currentPointerFrame == 0 and cursor.currentGrabbableFrame == 0, "A real move snaps back to frame 0.")

	cursor.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	cursor._process(1.0)
	_expect(!cursor.isIdling and cursor.currentPointerFrame == 0, "No idle while the window isn't focused.")
	cursor.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	cursor._process(1.0)
	_expect(cursor.isIdling and cursor.currentPointerFrame == 1, "Idle comes back when the window is focused again.")

	var noIdle: CursorSkin = realTheme.duplicate()
	noIdle.idleFps = 0.0
	cursor.applyTheme(noIdle)
	cursor._process(1.0)
	_expect(!cursor.isIdling and cursor.currentPointerFrame == 0, "idleFps 0 turns the idle off.")

	cursor.applyTheme(realTheme)
	cursor._input(_mouseButton(true))
	cursor.clickTween.custom_step(1.0)
	_expect(cursor.currentPointerFrame == realTheme.clickLastFrame, "Holding the button holds clickLastFrame.")
	cursor._input(_mouseButton(false))
	var released = _stepClick(cursor)
	_expect(released[-1] == 0 and released.max() <= realTheme.clickLastFrame, "Releasing plays back up to frame 0.")
	cursor._process(realTheme.idleDelaySeconds / 2.0)
	_expect(!cursor.isIdling and cursor.currentPointerFrame == 0, "The idle waits the full delay after a click.")

	cursor._input(_mouseButton(true))
	cursor.clickTween.custom_step(1.0 / 60.0)
	cursor._input(_mouseButton(false))
	var quick = _stepClick(cursor)
	_expect(quick.max() == realTheme.clickLastFrame and quick[-1] == 0, "A quick click plays the whole press, then comes back up.")
	_expect(quick == _sortedThenReversed(quick), "A quick click never turns around halfway.")

	cursor._input(_mouseButton(true))
	cursor.clickTween.custom_step(1.0)
	cursor._input(_mouseButton(false))
	cursor.clickTween.custom_step(2.0 / realTheme.clickFps)
	var midRelease = cursor.currentPointerFrame
	cursor._input(_mouseButton(true))
	cursor.clickTween.custom_step(1.0 / 60.0)
	_expect(midRelease > 0 and cursor.currentPointerFrame >= midRelease, "Clicking again mid-release carries on from the current frame.")
	cursor._input(_mouseButton(false))
	_stepClick(cursor)

	var grabbable := Control.new()
	cursor.markGrabbable(grabbable, true)
	cursor._onLeftButton(true, grabbable)
	_expect(!cursor.isClicking and cursor.currentPointerFrame == 0, "Pressing on a grabbable doesn't play the click.")
	cursor._onLeftButton(false, grabbable)
	_expect(!cursor.isClicking and cursor.currentPointerFrame == 0, "Releasing after a grabbable press doesn't play the click.")
	grabbable.free()

	cursor.applyTheme(realTheme)
	print("Cursor controller: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _mouseMotion(position: Vector2) -> InputEventMouseMotion:
	var event = InputEventMouseMotion.new()
	event.position = position
	return event

func _mouseButton(pressed: bool) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func _stepClick(cursor) -> Array:
	var frames = []
	for i in 240:
		if !cursor.clickTween.is_running():
			break
		cursor.clickTween.custom_step(1.0 / 60.0)
		frames.append(cursor.currentPointerFrame)
	return frames

func _sortedThenReversed(frames: Array) -> Array:
	var peak = frames.find(frames.max())
	var down = frames.slice(0, peak + 1)
	var up = frames.slice(peak)
	down.sort()
	up.sort()
	up.reverse()
	return down + up.slice(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
