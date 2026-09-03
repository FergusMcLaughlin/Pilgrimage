extends CanvasLayer

@export var animationPlayer: AnimationPlayer

func _ready() -> void:
	await  animationPlayer.animation_finished
	GlobalSignalBus.emitLoadScreenReady()

func _onProgressChanged(progress: float) -> void:
	#TODO: add in a progress bar here
	pass

func _onLoadFinished() -> void:
	animationPlayer.play_backwards("screenTransition")
	await animationPlayer.animation_finished
	queue_free()
