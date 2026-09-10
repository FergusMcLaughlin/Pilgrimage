extends Node

var loadingScene: PackedScene = preload("res://src/main/ui/overlays/loading_overlay.tscn")
var loadedResource: PackedScene
var scenePathToLoad: String
var progress: Array = []
var useSubThreads: bool = true
var isLoading: bool = false

func _ready() -> void:
	set_process(false)

func loadScene(scenePath: String) -> void:
	if isLoading:
		push_warning("LoadScene: load already in progress.")
		return
	
	if scenePath.is_empty() or not ResourceLoader.exists(scenePath, "PackedScene"):
		push_error("LoadScene: invalid PackedScene path: " + scenePath)
		return
	
	scenePathToLoad = scenePath
	isLoading = true
	progress.clear()
	
	var newLoadScreen = loadingScene.instantiate()
	add_child(newLoadScreen)
	
	GlobalSignalBus.progressChanged.connect(newLoadScreen._onProgressChanged)
	GlobalSignalBus.loadFinished.connect(newLoadScreen._onLoadFinished)
	GlobalSignalBus.loadScreenClosed.connect(_onLoadScreenClosed, CONNECT_ONE_SHOT)
	
	await GlobalSignalBus.loadScreenReady
	
	_startLoading()

func _startLoading() -> void:
	var state = ResourceLoader.load_threaded_request(scenePathToLoad, "", useSubThreads)
	if state == OK:
		set_process(true)
	else:
		_finishLoadingWithError("LoadScene: could not start threaded loading for '%s' (error %s)." % [scenePathToLoad, state])

func _process(_delta: float) -> void:
	var loadStatus = ResourceLoader.load_threaded_get_status(scenePathToLoad, progress)
	if not progress.is_empty():
		GlobalSignalBus.emitProgressChanged(progress[0])
	
	match loadStatus:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finishLoadingWithError("LoadScene: invalid resource for scene '%s'." % scenePathToLoad)
		ResourceLoader.THREAD_LOAD_FAILED:
			_finishLoadingWithError("LoadScene: threaded load failed for scene '%s'." % scenePathToLoad)
		ResourceLoader.THREAD_LOAD_LOADED:
			_finishLoading()

func _finishLoading() -> void:
	loadedResource = ResourceLoader.load_threaded_get(scenePathToLoad)
	var state = get_tree().change_scene_to_packed(loadedResource)
	if state != OK:
		_finishLoadingWithError("LoadScene: could not change to scene '%s' (error %s)." % [scenePathToLoad, state])
		return
	
	set_process(false)
	GlobalSignalBus.emitLoadFinished()

func _finishLoadingWithError(message: String) -> void:
	push_error(message)
	set_process(false)
	GlobalSignalBus.emitLoadFinished()

func _onLoadScreenClosed() -> void:
	isLoading = false

func isCurrentlyLoadingScene() -> bool:
	return isLoading
