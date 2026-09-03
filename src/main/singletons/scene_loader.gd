extends Node

var loadingScene: PackedScene = preload("uid://dvy0qsnpnpwnp")
var loadedResource: PackedScene
var scenePath: String
var progress: Array = []
var useSubThreads: bool = true

func _ready() -> void:
	set_process(false)

func loadScene(scenePathToLoad: String) -> void:
	scenePath = scenePathToLoad
	
	var newLoadScreen = loadingScene.instantiate()
	add_child(newLoadScreen)
	
	GlobalSignalBus.progressChanged.connect(newLoadScreen._onProgressChanged)
	GlobalSignalBus.loadFinished.connect(newLoadScreen._onLoadFinished)
	
	await GlobalSignalBus.loadScreenReady
	
	_startLoad()

func _startLoad() -> void:
	var state = ResourceLoader.load_threaded_request(scenePath, "", useSubThreads)
	if state == OK:
		set_process(true)

func _process(_delta: float) -> void:
	var loadStatus = ResourceLoader.load_threaded_get_status(scenePath, progress)
	GlobalSignalBus.emitProgressChanged(progress[0])
	
	match loadStatus:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Something went wrong trying to load scene '%s'" % scenePath)
			set_process(false)
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Thread load failed when trying to load scene '%s'" % scenePath)
			set_process(false)
		ResourceLoader.THREAD_LOAD_LOADED:
			loadedResource = ResourceLoader.load_threaded_get(scenePath)
			get_tree().change_scene_to_packed(loadedResource)
			GlobalSignalBus.emitLoadFinished()
			set_process(false)
