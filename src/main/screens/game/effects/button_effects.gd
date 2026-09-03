extends Node
class_name ButtonEffects

@export var easeType: Tween.EaseType = Tween.EASE_OUT
@export var transitionType: Tween.TransitionType = Tween.TRANS_QUAD
@export_range(0.01, 1.0, 0.01) var animationDuration: float = 0.14
@export var scaleAmount: Vector2 = Vector2(1.06, 1.06)
@export var rotationAmount: float = 3.0

@onready var button: Button = get_parent()

var tween: Tween
var mouseHovered := false
var focusHovered := false
var baseScale := Vector2.ONE
var baseRotation := 0.0

func _ready() -> void:
	baseScale = button.scale
	baseRotation = button.rotation_degrees

	button.mouse_entered.connect(_onMouseHovered.bind(true))
	button.mouse_exited.connect(_onMouseHovered.bind(false))
	button.focus_entered.connect(_onFocusChanged.bind(true))
	button.focus_exited.connect(_onFocusChanged.bind(false))
	button.pressed.connect(_onButtonPressed)
	button.resized.connect(_centrePivot)
	call_deferred("_centrePivot")

func _onButtonPressed() -> void:
	if button.disabled:
		return

	resetTween(false)
	var hoverScale := _getHoverScale()
	var pressedScale := hoverScale * Vector2(0.94, 0.94)
	tween.tween_property(button, "scale", pressedScale, animationDuration * 0.35)
	tween.parallel().tween_property(button, "rotation_degrees", baseRotation, animationDuration * 0.35)
	tween.chain().tween_property(button, "scale", hoverScale, animationDuration * 0.65)
	tween.parallel().tween_property(button, "rotation_degrees", _getHoverRotation(), animationDuration * 0.65)

func _onMouseHovered(isHovered: bool) -> void:
	mouseHovered = isHovered
	_refreshHoverVisual()

func _onFocusChanged(isFocused: bool) -> void:
	focusHovered = isFocused
	_refreshHoverVisual()

func _refreshHoverVisual() -> void:
	resetTween()
	var isActive := !button.disabled and (mouseHovered or focusHovered)
	tween.tween_property(button, "scale", _getHoverScale() if isActive else baseScale, animationDuration)
	tween.parallel().tween_property(
		button,
		"rotation_degrees",
		_getHoverRotation() if isActive else baseRotation,
		animationDuration
	)

func _getHoverScale() -> Vector2:
	return baseScale * scaleAmount

func _getHoverRotation() -> float:
	return baseRotation + rotationAmount

func _centrePivot() -> void:
	button.pivot_offset = button.size * 0.5

func resetTween(runInParallel: bool = true) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(easeType).set_trans(transitionType).set_parallel(runInParallel)
