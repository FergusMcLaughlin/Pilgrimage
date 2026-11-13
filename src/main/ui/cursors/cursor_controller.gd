#Auto load
extends Node

var defaultTheme = preload("res://data/ui/cursor/cursor_theme.tres")
var theme: CursorSkin
var pointerFrames = []
var grabbableFrames = []
var grabFrames = []
var currentPointerFrame = 0
var currentGrabbableFrame = 0

var stillAnchor = Vector2.ZERO
var stillSeconds = 0.0
var isIdling = false
var idleTimer = 0.0
var isWindowFocused = true

var isClicking = false
var clickTween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	applyTheme(defaultTheme)

func applyTheme(newTheme: CursorSkin) -> bool:
	_resetAnimations()
	theme = null
	if newTheme == null or !newTheme.validCursorSheet():
		push_warning("CursorController: cursor theme is missing a sheet or has a bad clickLastFrame, using the system cursor.")
		_useSystemCursor()
		return false

	theme = newTheme
	pointerFrames = _cutSheet(theme.pointerSheet, theme.pointerFrameSize, theme.pointerFrameCount)
	grabbableFrames = _cutSheet(theme.grabbableSheet, theme.grabbableFrameSize, theme.grabbableFrameCount)
	grabFrames = _cutSheet(theme.grabSheet, theme.grabFrameSize, theme.grabFrameCount)
	_setPointerFrame(0, true)
	_setGrabbableFrame(0, true)
	_setGrabFrame(0)
	return true

func _resetAnimations() -> void:
	if clickTween != null:
		clickTween.kill()
	isClicking = false
	isIdling = false
	stillSeconds = 0.0
	idleTimer = 0.0

func _cutSheet(sheet: Texture2D, frameSize: Vector2i, frameCount: int) -> Array:
	var frames = []
	var image = sheet.get_image()
	for i in frameCount:
		var region = Rect2i(i * frameSize.x, 0, frameSize.x, frameSize.y)
		frames.append(ImageTexture.create_from_image(image.get_region(region)))
	return frames

func _setPointerFrame(frame: int, force: bool = false) -> void:
	if frame == currentPointerFrame and !force:
		return
	currentPointerFrame = frame
	Input.set_custom_mouse_cursor(pointerFrames[frame], Input.CURSOR_ARROW, theme.pointerClickLocation)
	Input.set_custom_mouse_cursor(pointerFrames[frame], Input.CURSOR_POINTING_HAND, theme.pointerClickLocation)

func _setGrabbableFrame(frame: int, force: bool = false) -> void:
	if frame == currentGrabbableFrame and !force:
		return
	currentGrabbableFrame = frame
	Input.set_custom_mouse_cursor(grabbableFrames[frame], Input.CURSOR_MOVE, theme.grabbableClickLocation)

func _setGrabFrame(frame: int) -> void:
	Input.set_custom_mouse_cursor(grabFrames[frame], Input.CURSOR_DRAG, theme.grabClickLocation)

func _input(event: InputEvent) -> void:
	if theme == null:
		return
	if event is InputEventMouseMotion:
		if event.position.distance_to(stillAnchor) >= theme.wakeDistance:
			stillAnchor = event.position
			_wake()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_onLeftButton(event.pressed, get_viewport().gui_get_hovered_control())

func _onLeftButton(pressed: bool, hovered: Control) -> void:
	_wake()
	if pressed and !isGrabbable(hovered):
		_pressClick()
	elif !pressed and isClicking:
		_releaseClick()

func _wake() -> void:
	stillSeconds = 0.0
	idleTimer = 0.0
	if isIdling:
		isIdling = false
		_setPointerFrame(0)
		_setGrabbableFrame(0)

func _pressClick() -> void:
	isClicking = true
	_restartClickTween()
	_tweenPointer(currentPointerFrame, theme.clickLastFrame)

func _releaseClick() -> void:
	isClicking = false
	_restartClickTween()
	if currentPointerFrame < theme.clickLastFrame:
		_tweenPointer(currentPointerFrame, theme.clickLastFrame)
		clickTween.tween_interval(theme.clickMinHoldSeconds)
	_tweenPointer(theme.clickLastFrame, 0)
	clickTween.tween_callback(_wake)

func _restartClickTween() -> void:
	if clickTween != null:
		clickTween.kill()
	clickTween = create_tween()

func _tweenPointer(from: int, to: int) -> void:
	clickTween.tween_method(_setPointerFrame, from, to, abs(to - from) / theme.clickFps)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		isWindowFocused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		isWindowFocused = false

func _process(delta: float) -> void:
	if theme == null or theme.idleFps <= 0.0 or !isWindowFocused:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if clickTween != null and clickTween.is_running():
		return
	stillSeconds += delta
	if stillSeconds < theme.idleDelaySeconds:
		return

	isIdling = true
	idleTimer += delta
	if idleTimer >= 1.0 / theme.idleFps:
		idleTimer -= 1.0 / theme.idleFps
		_setPointerFrame((currentPointerFrame + 1) % pointerFrames.size())
		_setGrabbableFrame((currentGrabbableFrame + 1) % grabbableFrames.size())

func markGrabbable(control: Control, grabbable: bool) -> void:
	if control == null:
		return
	control.mouse_default_cursor_shape = Control.CURSOR_MOVE if grabbable else Control.CURSOR_ARROW

func isGrabbable(control: Control) -> bool:
	return control != null and control.mouse_default_cursor_shape == Control.CURSOR_MOVE

func _useSystemCursor() -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_MOVE, Input.CURSOR_DRAG]:
		Input.set_custom_mouse_cursor(null, shape)

func _exit_tree() -> void:
	_useSystemCursor()
