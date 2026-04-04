extends Control

@onready var cardsRoot: Control = $CanvasLayer/CardsRoot

@onready var addPlayerButton: Button = $CanvasLayer/Controls/AddPlayerButton
@onready var addKnightButton: Button = $CanvasLayer/Controls/AddKnightButton
@onready var addGoatmanButton: Button = $CanvasLayer/Controls/AddGoatmanButton
@onready var addStewButton: Button = $CanvasLayer/Controls/AddStewButton
@onready var clearCardsButton: Button = $CanvasLayer/Controls/ClearCardsButton

var createCard := CreateCard.new()

var cards: Array[Card] = []
var activeCardIndex := -1

@export var debug_stat_cycle := true
@export var debug_interval_seconds := 1.0
@export var debug_delta := 2
var debugTimer: Timer
var debugPhase := 0

@export var debug_state_cycle := false
@export var debug_state_interval_seconds := 2.0
var debugStateTimer: Timer
var debugStatePhase := 0

const CARD_START_POS := Vector2(200, 320)
const CARD_SPACING_X := 180

func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
	GlobalSignalBus.cardFlipped.connect(_onCardFlipped)
	GlobalSignalBus.cardStateChanged.connect(_onCardStateChanged)

	_connectButtons()

	if debug_stat_cycle:
		_startDebugStatCycle()

	if debug_state_cycle:
		_startDebugStateCycle()

func _connectButtons() -> void:
	addPlayerButton.pressed.connect(_onAddPlayerPressed)
	addKnightButton.pressed.connect(_onAddKnightPressed)
	addGoatmanButton.pressed.connect(_onAddGoatmanPressed)
	addStewButton.pressed.connect(_onAddStewPressed)
	clearCardsButton.pressed.connect(_onClearCardsPressed)

func _onAddPlayerPressed() -> void:
	_addCardById("C_0000")

func _onAddKnightPressed() -> void:
	_addCardById("M_0010")

func _onAddGoatmanPressed() -> void:
	_addCardById("M_0011")

func _onAddStewPressed() -> void:
	_addCardById("M_0007")

func _onClearCardsPressed() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()

	cards.clear()
	activeCardIndex = -1

	print("Cleared all test cards")

func _addCardById(cardId: String) -> void:
	var newCard: Card = createCard.createCard(cardId)
	if newCard == null:
		push_error("Failed to create test card for id %s" % cardId)
		return

	cardsRoot.add_child(newCard)
	cards.append(newCard)

	_layoutCards()

	activeCardIndex = cards.size() - 1
	_printActiveCard()

	if newCard.data != null:
		print(
			"Created card %s | name=%s type=%s hp=%s atk=%s image=%s" %
			[
				newCard.data.id,
				newCard.data.name,
				newCard.data.type,
				str(newCard.health),
				str(newCard.attack),
				newCard.data.imagePath
			]
		)

	_applyTestState(CardState.State.ON_BOARD)

func _layoutCards() -> void:
	for i in range(cards.size()):
		var card := cards[i]
		if card == null:
			continue

		if card.currentState == CardState.State.IN_SLOT:
			continue

		card.global_position = CARD_START_POS + Vector2(i * CARD_SPACING_X, 0)

func _getActiveCard() -> Card:
	if cards.is_empty():
		return null

	if activeCardIndex < 0 or activeCardIndex >= cards.size():
		return null

	return cards[activeCardIndex]

func _setActiveCard(index: int) -> void:
	if index < 0 or index >= cards.size():
		return

	activeCardIndex = index
	_printActiveCard()

func _printActiveCard() -> void:
	var card := _getActiveCard()
	if card == null:
		return

	print(
		"Active card -> index=%s id=%s name=%s type=%s" %
		[
			str(activeCardIndex),
			card.data.id,
			card.data.name,
			card.data.type
		]
	)

func _startDebugStatCycle() -> void:
	debugTimer = Timer.new()
	debugTimer.wait_time = debug_interval_seconds
	debugTimer.one_shot = false
	debugTimer.autostart = true
	add_child(debugTimer)
	debugTimer.timeout.connect(_onDebugStatTimeout)

func _startDebugStateCycle() -> void:
	debugStateTimer = Timer.new()
	debugStateTimer.wait_time = debug_state_interval_seconds
	debugStateTimer.one_shot = false
	debugStateTimer.autostart = true
	add_child(debugStateTimer)
	debugStateTimer.timeout.connect(_onDebugStateTimeout)

func _onDebugStatTimeout() -> void:
	var card := _getActiveCard()
	if card == null or card.data == null:
		return

	if card.data.type == "player":
		return

	var baseHp := card.data.baseHealth
	var baseAp := card.data.baseAttack

	match debugPhase % 3:
		0:
			card.health = baseHp
			card.attack = baseAp
		1:
			card.health = baseHp + debug_delta
			card.attack = baseAp + debug_delta
		2:
			card.health = max(0, baseHp - debug_delta)
			card.attack = max(0, baseAp - debug_delta)

	debugPhase += 1

	if card.visuals:
		card.visuals.refresh()

func _onDebugStateTimeout() -> void:
	var stateOrder := [
		CardState.State.IN_DECK,
		CardState.State.ON_BOARD,
		CardState.State.BEING_DRAGGED,
		CardState.State.IN_SLOT
	]

	var nextState: int = stateOrder[debugStatePhase % stateOrder.size()]
	debugStatePhase += 1
	_applyTestState(nextState)

func _applyTestState(newState: int) -> void:
	var card := _getActiveCard()
	if card == null:
		return

	card.setCardState(newState)

	print("Card test state set to: %s" % _getStateName(newState))

func _onCardPressed(card: Card) -> void:
	var index := cards.find(card)
	if index != -1:
		_setActiveCard(index)

func _input(event: InputEvent) -> void:
	var card := _getActiveCard()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and card != null:
			card.flipCard()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_setActiveCard(0)
			KEY_2:
				_setActiveCard(1)
			KEY_3:
				_setActiveCard(2)
			KEY_4:
				_setActiveCard(3)

			KEY_Q:
				_applyTestState(CardState.State.IN_DECK)
			KEY_W:
				_applyTestState(CardState.State.ON_BOARD)
			KEY_E:
				_applyTestState(CardState.State.BEING_DRAGGED)
			KEY_R:
				_applyTestState(CardState.State.IN_SLOT)

			KEY_SPACE:
				_cycleToNextState()

func _cycleToNextState() -> void:
	var card := _getActiveCard()
	if card == null:
		return

	var nextState := CardState.State.IN_DECK

	match card.currentState:
		CardState.State.IN_DECK:
			nextState = CardState.State.ON_BOARD
		CardState.State.ON_BOARD:
			nextState = CardState.State.BEING_DRAGGED
		CardState.State.BEING_DRAGGED:
			nextState = CardState.State.IN_SLOT
		CardState.State.IN_SLOT:
			nextState = CardState.State.IN_DECK

	_applyTestState(nextState)

func _onCardFlipped(card: Card) -> void:
	if card != _getActiveCard():
		return

	print("Card flipped")

func _onCardStateChanged(changedCard: Card, oldState: int, newState: int) -> void:
	if changedCard != _getActiveCard():
		return

	print(
		"Card state changed: %s -> %s" %
		[_getStateName(oldState), _getStateName(newState)]
	)

func _getStateName(state: int) -> String:
	match state:
		CardState.State.IN_DECK:
			return "IN_DECK"
		CardState.State.ON_BOARD:
			return "ON_BOARD"
		CardState.State.BEING_DRAGGED:
			return "BEING_DRAGGED"
		CardState.State.IN_SLOT:
			return "IN_SLOT"
		_:
			return "UNKNOWN"
