extends Control
class_name  CardOutline
#code this myself i think
@export var glow_color: Color = Color(0.18, 0.02, 0.02, 1.0)
@export var border_color: Color = Color(0.55, 0.06, 0.04, 1.0)
@export var border_width: float = 2.0
@export var base_expand: float = 4.0
@export var pulse_expand: float = 1.0
@export var pulse_speed: float = 0.45
@export var fade_speed: float = 6.0
@export var corner_radius: float = 18.0

var hover_t: float = 0.0
var target_hover_t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	var old_hover_t := hover_t
	hover_t = move_toward(hover_t, target_hover_t, fade_speed * delta)

	if hover_t > 0.001 or target_hover_t > 0.001 or old_hover_t > 0.001:
		queue_redraw()

func show_hover() -> void:
	target_hover_t = 1.0
	queue_redraw()

func hide_hover() -> void:
	target_hover_t = 0.0
	queue_redraw()

func _draw() -> void:
	if hover_t <= 0.001:
		return

	var pulse := (sin(Time.get_ticks_msec() / 1000.0 * TAU * pulse_speed) + 1.0) * 0.5
	var expand := base_expand + pulse * pulse_expand

	var outer_rect := Rect2(
		Vector2(-expand, -expand),
		size + Vector2(expand * 2.0, expand * 2.0)
	)

	var wash_a := (0.05 + pulse * 0.03) * hover_t
	var border_a := (0.55 + pulse * 0.10) * hover_t

	var wash_col := glow_color
	var border_col := border_color

	wash_col.a = wash_a
	border_col.a = border_a

	draw_rect(outer_rect.grow(3), wash_col, true)
	_draw_rect_outline(outer_rect, border_col, border_width)

func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, color, false, width)
