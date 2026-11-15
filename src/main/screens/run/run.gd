extends Control

const GAME_OVER_OVERLAY_SCENE = preload("res://src/main/ui/overlays/game_over_overlay.tscn")

@export_file("*.tscn") var postRunScenePath: String

@onready var gameController = %GameController
@onready var encounterModal = %EncounterModal
@onready var gameOverLayer = %GameOverLayer

var gameOverOverlay: Node

func _ready() -> void:
	InputManager.debugDraggingEnabled = false
	InputManager.debugBoardController = null
	GlobalSignalBus.gameOverRequested.connect(_onGameOverRequested)
	GlobalSignalBus.gameOverContinueRequested.connect(_onGameOverContinueRequested)
	await gameController.startRun()

func _onGameOverRequested() -> void:
	encounterModal.close()
	if is_instance_valid(gameOverOverlay):
		return
	gameOverOverlay = GAME_OVER_OVERLAY_SCENE.instantiate()
	gameOverLayer.add_child(gameOverOverlay)

func _onGameOverContinueRequested() -> void:
	if !is_instance_valid(gameOverOverlay) or ScreenLoader.isCurrentlyLoadingScene():
		return
	await ScreenLoader.loadScene(postRunScenePath)

func _exit_tree() -> void:
	if GlobalSignalBus.gameOverRequested.is_connected(_onGameOverRequested):
		GlobalSignalBus.gameOverRequested.disconnect(_onGameOverRequested)
	if GlobalSignalBus.gameOverContinueRequested.is_connected(_onGameOverContinueRequested):
		GlobalSignalBus.gameOverContinueRequested.disconnect(_onGameOverContinueRequested)
