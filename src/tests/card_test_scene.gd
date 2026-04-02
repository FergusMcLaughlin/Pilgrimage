extends Node2D

@onready var cardsRoot: Node2D = $CardsRoot

@onready var addPlayerButton: Button = $CanvasLayer/Controls/AddPlayerButton
@onready var addKnightButton: Button = $CanvasLayer/Controls/AddKnightButton
@onready var addGoatmanButton: Button = $CanvasLayer/Controls/AddGoatmanButton
@onready var addStewButton: Button = $CanvasLayer/Controls/AddStewButton
@onready var clearCardsButton: Button = $CanvasLayer/Controls/ClearCardsButton

var createCard := CreateCard.new()

var cards: Array[Card] = []
var activeCardIndex := -1

var dragging := false
var drag_offset := Vector2.ZERO

@export var debug_stat_cycle := true
@export var debug_interval_seconds := 1.0
@export var debug_delta := 2
var _debug_timer: Timer
var _debug_phase := 0

@export var debug_state_cycle := false
@export var debug_state_interval_seconds := 2.0
var _debug_state_timer: Timer
var _debug_state_phase := 0

const CARD_START_POS := Vector2(200, 320)
const CARD_SPACING_X := 180

func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
	GlobalSignalBus.cardFlipped.connect(_onCardFlipped)

	if GlobalSignalBus.has_signal("cardStateChanged"):
		GlobalSignalBus.cardStateChanged.connect(_onCardStateChanged)

	_connect_buttons()

	if debug_stat_cycle:
		_start_debug_stat_cycle()

	if debug_state_cycle:
		_start_debug_state_cycle()

func _connect_buttons() -> void:
	addPlayerButton.pressed.connect(_onAddPlayerPressed)
	addKnightButton.pressed.connect(_onAddKnightPressed)
	addGoatmanButton.pressed.connect(_onAddGoatmanPressed)
	addStewButton.pressed.connect(_onAddStewPressed)
	clearCardsButton.pressed.connect(_onClearCardsPressed)

func _onAddPlayerPressed() -> void:
	_add_card_by_id("C_0000")

func _onAddKnightPressed() -> void:
	_add_card_by_id("M_0010")

func _onAddGoatmanPressed() -> void:
	_add_card_by_id("M_0011")

func _onAddStewPressed() -> void:
	_add_card_by_id("M_0007")

func _onClearCardsPressed() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()

	cards.clear()
	activeCardIndex = -1
	dragging = false

	print("Cleared all test cards")

func _add_card_by_id(cardId: String) -> void:
	var newCard: Card = createCard.createCard(cardId)
	if newCard == null:
		push_error("Failed to create test card for id %s" % cardId)
		return

	cardsRoot.add_child(newCard)
	cards.append(newCard)

	_layout_cards()

	activeCardIndex = cards.size() - 1
	_print_active_card()

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

	_apply_test_state(CardState.State.IN_DECK)

func _layout_cards() -> void:
	for i in range(cards.size()):
		var card := cards[i]
		if card == null:
			continue

		card.global_position = CARD_START_POS + Vector2(i * CARD_SPACING_X, 0)

func _get_active_card() -> Card:
	if cards.is_empty():
		return null

	if activeCardIndex < 0 or activeCardIndex >= cards.size():
		return null

	return cards[activeCardIndex]

func _set_active_card(index: int) -> void:
	if index < 0 or index >= cards.size():
		return

	activeCardIndex = index
	dragging = false
	_print_active_card()

func _print_active_card() -> void:
	var card := _get_active_card()
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

func _start_debug_stat_cycle() -> void:
	_debug_timer = Timer.new()
	_debug_timer.wait_time = debug_interval_seconds
	_debug_timer.one_shot = false
	_debug_timer.autostart = true
	add_child(_debug_timer)
	_debug_timer.timeout.connect(_on_debug_stat_timeout)

func _start_debug_state_cycle() -> void:
	_debug_state_timer = Timer.new()
	_debug_state_timer.wait_time = debug_state_interval_seconds
	_debug_state_timer.one_shot = false
	_debug_state_timer.autostart = true
	add_child(_debug_state_timer)
	_debug_state_timer.timeout.connect(_on_debug_state_timeout)

func _on_debug_stat_timeout() -> void:
	var card := _get_active_card()
	if card == null or card.data == null:
		return

	if card.data.type == "player":
		return

	var base_hp := card.data.baseHealth
	var base_ap := card.data.baseAttack

	match _debug_phase % 3:
		0:
			card.health = base_hp
			card.attack = base_ap
		1:
			card.health = base_hp + debug_delta
			card.attack = base_ap + debug_delta
		2:
			card.health = max(0, base_hp - debug_delta)
			card.attack = max(0, base_ap - debug_delta)

	_debug_phase += 1

	if card.visuals:
		card.visuals.refresh()

func _on_debug_state_timeout() -> void:
	var state_order := [
		CardState.State.IN_DECK,
		CardState.State.ON_BOARD,
		CardState.State.BEING_DRAGGED,
		CardState.State.IN_SLOT
	]

	var next_state: int = state_order[_debug_state_phase % state_order.size()]
	_debug_state_phase += 1
	_apply_test_state(next_state)

func _apply_test_state(new_state: int) -> void:
	var card := _get_active_card()
	if card == null:
		return

	card.setCardState(new_state)

	if new_state == CardState.State.BEING_DRAGGED:
		dragging = true
		drag_offset = card.global_position - get_global_mouse_position()
	else:
		dragging = false

	print("Card test state set to: %s" % _get_state_name(new_state))

func _onCardPressed(c: Card) -> void:
	var index := cards.find(c)
	if index != -1:
		_set_active_card(index)

	if c != _get_active_card():
		return

	dragging = true
	drag_offset = c.global_position - get_global_mouse_position()
	_apply_test_state(CardState.State.BEING_DRAGGED)

func _input(event: InputEvent) -> void:
	var card := _get_active_card()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging = false
			_apply_test_state(CardState.State.ON_BOARD)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and card != null:
			card.flipCard()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_active_card(0)
			KEY_2:
				_set_active_card(1)
			KEY_3:
				_set_active_card(2)
			KEY_4:
				_set_active_card(3)

			KEY_Q:
				_apply_test_state(CardState.State.IN_DECK)
			KEY_W:
				_apply_test_state(CardState.State.ON_BOARD)
			KEY_E:
				_apply_test_state(CardState.State.BEING_DRAGGED)
			KEY_R:
				_apply_test_state(CardState.State.IN_SLOT)

			KEY_SPACE:
				_cycle_to_next_state()

func _process(_delta: float) -> void:
	var card := _get_active_card()
	if card == null:
		return

	if dragging and card.currentState == CardState.State.BEING_DRAGGED:
		card.global_position = get_global_mouse_position() + drag_offset

func _cycle_to_next_state() -> void:
	var card := _get_active_card()
	if card == null:
		return

	var next_state := CardState.State.IN_DECK

	match card.currentState:
		CardState.State.IN_DECK:
			next_state = CardState.State.ON_BOARD
		CardState.State.ON_BOARD:
			next_state = CardState.State.BEING_DRAGGED
		CardState.State.BEING_DRAGGED:
			next_state = CardState.State.IN_SLOT
		CardState.State.IN_SLOT:
			next_state = CardState.State.IN_DECK

	_apply_test_state(next_state)

func _onCardFlipped(c: Card) -> void:
	if c != _get_active_card():
		return

	print("Card flipped")

func _onCardStateChanged(changed_card: Card, old_state: int, new_state: int) -> void:
	if changed_card != _get_active_card():
		return

	print(
		"Card state changed: %s -> %s" %
		[_get_state_name(old_state), _get_state_name(new_state)]
	)

func _get_state_name(state: int) -> String:
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
