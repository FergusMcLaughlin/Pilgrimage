extends Node

const GRID := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const DECK := preload("res://src/main/decks/deck_types/journey_deck.tscn")
var _board_notifications := 0
var _healed := false
var _finished_combat: CombatResult

func _ready() -> void:
	await _probe_input_and_clear()
	await _probe_failed_removal()
	await _probe_healing_in_real_combat()
	await _probe_interrupted_reveal()
	print("AUDIT_PROBES_FINISHED")
	get_tree().quit()

func _fixture() -> Dictionary:
	var fixture := Node.new()
	var grid: SlotGrid = GRID.instantiate()
	grid.name = "Grid"
	var board := BoardController.new()
	board.slotGridPath = NodePath("../Grid")
	var deck: JourneyDeck = DECK.instantiate()
	fixture.add_child(grid)
	fixture.add_child(board)
	fixture.add_child(deck)
	add_child(fixture)
	deck.boardController = board
	deck.slotGrid = grid
	deck.journeyDeckCardBag.initialiseDeck(["M_0002", "M_0001"], false)
	return {"root": fixture, "grid": grid, "board": board, "deck": deck}

func _settle() -> void:
	for i in range(600):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	push_error("Probe action system did not settle")

func _cleanup(fixture: Dictionary) -> void:
	await _settle()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	fixture.root.queue_free()
	await get_tree().process_frame

func _probe_input_and_clear() -> void:
	var f := _fixture()
	InputManager.lockInput()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	f.deck.deckImage.gui_input.emit(click)
	await _settle()
	print("PROBE locked_deck_click: locked=%s occupied=%s deck_count=%s" % [InputManager.inputLocked, f.grid.getOccupiedSlots().size(), f.deck.getDeckSize()])
	var slot: CardSlot = f.grid.getOccupiedSlots()[0]
	var card := slot.currentCard
	f.board.clearBoard()
	print("PROBE clear_board: occupied=%s old_card_valid=%s old_card_still_visible=%s child_count=%s effects_retained=%s" % [f.grid.getOccupiedSlots().size(), is_instance_valid(card), card.is_visible_in_tree(), slot.cardAnchor.get_child_count(), EffectProcessor.activeEffectsByCard.has(card)])
	var replacement := CreateCard.new().createCard("M_0001")
	f.board.placeCard(replacement, slot)
	print("PROBE clear_then_replace: slot_children=%s" % slot.cardAnchor.get_child_count())
	var spare := CreateCard.new().createCard("M_0001")
	f.root.add_child(spare)
	var count_changes := func(): _board_notifications += 1
	GlobalSignalBus.boardStateChanged.connect(count_changes)
	InputManager._placeCardInSlot(spare, f.grid.getEmptySlots()[0])
	GlobalSignalBus.boardStateChanged.disconnect(count_changes)
	print("PROBE input_placement: card_in_slot=%s board_notifications=%s" % [f.board.getSlotCardIsIn(spare) != null, _board_notifications])
	var game := GameController.new()
	var movement := PlayerMovementController.new()
	movement.gameController = game
	movement.boardController = f.board
	movement.slotGrid = f.grid
	f.root.add_child(movement)
	game.playerCard = replacement
	game.state = GameController.GameState.PLAYER_READY
	GlobalSignalBus.emitCardPressed(spare)
	print("PROBE locked_combat_input: locked=%s game_state=%s" % [InputManager.inputLocked, GameController.GameState.keys()[game.state]])
	game.free()
	await _cleanup(f)

func _probe_failed_removal() -> void:
	var f := _fixture()
	var goatman: Card = await f.deck.revealToNextEmptySlot()
	await _settle()
	print("PROBE before_failed_removal: effects_active=%s" % EffectProcessor.activeEffectsByCard.has(goatman))
	f.board.remove_from_group("boardController")
	var action := ActionType.make(ActionType.REMOVE_CARD, null, goatman, RemoveCardPayload.create(0, "audit_failed_remove"))
	ActionQueue.enqueueAction(action)
	var result = await ActionQueue.waitForActionToResolve(action)
	f.board.add_to_group("boardController")
	print("PROBE failed_removal: result=%s card_still_on_board=%s effects_active=%s" % [result, f.board.getSlotCardIsIn(goatman) != null, EffectProcessor.activeEffectsByCard.has(goatman)])
	await _cleanup(f)

func _probe_healing_in_real_combat() -> void:
	var f := _fixture()
	var game := GameController.new()
	var resolver := CombatResolver.new()
	game.boardController = f.board
	game.slotGrid = f.grid
	game.journeyDeck = f.deck
	resolver.gameController = game
	resolver.boardController = f.board
	resolver.slotGrid = f.grid
	f.root.add_child(game)
	f.root.add_child(resolver)
	var player := CreateCard.new().createCard("C_0000")
	var defender := CreateCard.new().createCard("M_0001")
	player.health = 1
	player.attack = 1
	defender.health = 10
	defender.attack = 1
	var player_slot: CardSlot = f.grid.getCenterSlot()
	var defender_slot: CardSlot = f.grid.getSlotAt(Vector2i(1, 0))
	f.board.placeCard(player, player_slot)
	f.board.placeCard(defender, defender_slot)
	game.playerCard = player
	game.playerCycleNumber = 1
	game.state = GameController.GameState.COMBAT
	# Simulate a future death-prevention effect through its actual action boundary.
	var heal_on_damage := func(action: GameAction, result: Variant):
		if action.type == ActionType.DEAL_DAMAGE and result is DamageResult and result.targetCardId == "C_0000" and result.wasLethal:
			ActionQueue.enqueueAction(ActionType.make(ActionType.MODIFY_STATS, null, action.target, ModifyStatsPayload.create("health", 5, "audit_healing_effect")))
		if action.type == ActionType.MODIFY_STATS and action.payload.cause == "audit_healing_effect":
			_healed = is_instance_valid(action.target) and action.target.health > 0
	var combat_finished := func(result: CombatResult): _finished_combat = result
	GlobalSignalBus.actionResolved.connect(heal_on_damage)
	GlobalSignalBus.combatEnded.connect(combat_finished)
	GlobalSignalBus.emitPlayerCombatRequested(player, defender, player_slot, defender_slot, 1)
	await _settle()
	await get_tree().process_frame
	GlobalSignalBus.actionResolved.disconnect(heal_on_damage)
	GlobalSignalBus.combatEnded.disconnect(combat_finished)
	print("PROBE real_combat_heal: healed_before_removal=%s player_survives=%s state=%s burial_health=%s" % [_healed, is_instance_valid(player), GameController.GameState.keys()[game.state], _finished_combat.playerGraveyardEntry.statSnapshot.health if _finished_combat != null and _finished_combat.playerGraveyardEntry != null else -1])
	await _cleanup(f)

func _probe_interrupted_reveal() -> void:
	var f := _fixture()
	var action := ActionType.make(ActionType.REVEAL_CARD, f.deck, f.grid.getEmptySlots()[0], RevealCardPayload.create("audit_scene_exit"))
	ActionQueue.enqueueAction(action)
	for i in range(30):
		await get_tree().process_frame
		if ActionProcessor.isProcessingAction:
			break
	print("PROBE before_scene_exit: processor_busy=%s" % ActionProcessor.isProcessingAction)
	f.root.queue_free()
	await get_tree().create_timer(1.0).timeout
	print("PROBE after_scene_exit: processor_busy=%s queue_size=%s" % [ActionProcessor.isProcessingAction, ActionQueue.getActionQueueSize()])
