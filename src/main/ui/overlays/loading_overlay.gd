extends CanvasLayer

@export var animationPlayer: AnimationPlayer

func _ready() -> void:
	await animationPlayer.animation_finished
	GlobalSignalBus.emitLoadScreenReady()

func _onProgressChanged(progress: float) -> void:
	# TODO: add a progress bar here.
	pass

func _onLoadFinished() -> void:
	animationPlayer.play_backwards("screenTransition")
	await animationPlayer.animation_finished
	GlobalSignalBus.emitLoadScreenClosed()
	queue_free()
