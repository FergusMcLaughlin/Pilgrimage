# Autoloaded as GlobalSignalBus
extends Node

# ==================================================
# CARD INPUT SIGNALS
# ==================================================

signal cardHovered(card)
signal cardUnhovered(card)
signal cardPressed(card)
signal cardReleased(card)

# ==================================================
# CARD DRAG SIGNALS
# ==================================================

signal cardDragStarted(card, position)
signal cardDragging(card, position)
signal cardDragEnded(card, position)

# ==================================================
# CARD STATE / VISUAL FLOW SIGNALS
# ==================================================

signal cardFlipped(card)
signal cardStateChanged(card, oldCardState, newCardState)

# ==================================================
# SLOT INPUT SIGNALS
# ==================================================

signal slotHovered(cardSlot)
signal slotUnhovered(cardSlot)
signal slotClicked(cardSlot)
signal slotFilled(cardSlot, card)
signal slotEmptied(cardSlot)

# ==================================================
# BOARD SIGNALS
# ==================================================

signal boardStateChanged()

# ==================================================
# DECK SIGNALS
# ==================================================

signal deckShuffled(deck)
signal deckEmptied(deck)
signal cardAddedToDeck(card)
signal cardDrawnFromDeck(card)

# ==================================================
# ACTION QUEUE SIGNALS
# ==================================================

signal actionEnqueued(action: GameAction)
signal actionPopped(action: GameAction)
signal queueCleared()
signal actionResolved(action: GameAction,result: Variant)

# ==================================================
# GAME CONTROLLER SIGNALS
# ==================================================

signal gameStateChanged(previousState, newState)
signal playerCycleStarted(player, cycleNumber)
signal afterMoveStarted(player, cycleNumber)
signal playerCycleCompleted(player, cycleNumber)

# ==================================================
# PLAYER MOVMENT CONTROLLER SIGNALS
# ==================================================

signal playerCombatRequested(player, defender, playerSlot, targetSlot, cycleNumber)
signal combatStarted(context: CombatContext)
signal combatEnded(result: CombatResult)

# ==================================================
# BOARD REFILL SIGNALS
# ==================================================

signal boardRefillRequested(request: BoardRefillRequest)
signal boardRefillCompleted(result: BoardRefillResult)

# ==================================================
# SCENE LOADER SIGNALS
# ==================================================

signal progressChanged(progress: float)
signal loadFinished()
signal loadScreenReady()

# ==================================================
# CARD INPUT EMIT WRAPPERS
# ==================================================

func emitCardHovered(card) -> void:
	emit_signal("cardHovered", card)

func emitCardUnhovered(card) -> void:
	emit_signal("cardUnhovered", card)

func emitCardPressed(card) -> void:
	emit_signal("cardPressed", card)

func emitCardReleased(card) -> void:
	emit_signal("cardReleased", card)

# ==================================================
# CARD DRAG EMIT WRAPPERS
# ==================================================

func emitCardDragStarted(card, position: Vector2) -> void:
	emit_signal("cardDragStarted", card, position)

func emitCardDragging(card, position: Vector2) -> void:
	emit_signal("cardDragging", card, position)

func emitCardDragEnded(card, position: Vector2) -> void:
	emit_signal("cardDragEnded", card, position)

# ==================================================
# CARD STATE / VISUAL EMIT WRAPPERS
# ==================================================

func emitCardFlipped(card) -> void:
	emit_signal("cardFlipped", card)

func emitCardStateChanged(card, oldCardState, newCardState) -> void:
	emit_signal("cardStateChanged", card, oldCardState, newCardState)

# ==================================================
# SLOT INPUT EMIT WRAPPERS
# ==================================================

func emitSlotHovered(cardSlot) -> void:
	emit_signal("slotHovered", cardSlot)

func emitSlotUnhovered(cardSlot) -> void:
	emit_signal("slotUnhovered", cardSlot)

func emitSlotClicked(cardSlot) -> void:
	emit_signal("slotClicked", cardSlot)

func emitSlotFilled(cardSlot, card) -> void:
	emit_signal("slotFilled", cardSlot, card)

func emitSlotEmptied(cardSlot) -> void:
	emit_signal("slotEmptied", cardSlot)

# ==================================================
# BOARD EMIT WRAPPERS
# ==================================================

func emitBoardStateChanged() -> void:
	emit_signal("boardStateChanged")

# ==================================================
# Deck EMIT WRAPPERS
# ==================================================
func emitDeckShuffled(deck) -> void:
	emit_signal("deckShuffled", deck)

func emitDeckEmptied(deck) -> void:
	emit_signal("deckEmptied", deck)

func emitCardAddedToDeck(card) -> void:
	emit_signal("cardAddedToDeck", card)

func emitCardDrawnFromDeck(card) -> void:
	emit_signal("cardDrawnFromDeck", card)

# ==================================================
# ACTION QUEUE EMIT WRAPPERS
# ==================================================

func emitActionEnqueued(action: GameAction) -> void:
	emit_signal("actionEnqueued", action)

func emitActionPopped(action: GameAction) -> void:
	emit_signal("actionPopped", action)

func emitQueueCleared() -> void:
	emit_signal("queueCleared")

func emitActionResolved(action: GameAction, result: Variant) -> void:
	emit_signal("actionResolved", action, result)

# ==================================================
# GAME CONTROLLER WRAPPERS
# ==================================================

func emitGameStateChanged(previousState, newState) -> void:
	emit_signal("gameStateChanged", previousState, newState)

func emitPlayerCycleStarted(player, cycleNumber) -> void:
	emit_signal("playerCycleStarted", player, cycleNumber)

func emitAfterMoveStarted(player, cycleNumber) -> void:
	emit_signal("afterMoveStarted", player, cycleNumber)

func emitPlayerCycleCompleted(player, cycleNumber) -> void:
	emit_signal("playerCycleCompleted", player, cycleNumber)

# ==================================================
# PLAYER MOVMENT CONTROLLER WRAPPERs
# ==================================================

func emitPlayerCombatRequested(player: Card, defender: Card, playerSlot: CardSlot, targetSlot: CardSlot, cycleNumber: int) -> void:
	emit_signal("playerCombatRequested", player, defender, playerSlot, targetSlot, cycleNumber)

func emitCombatStarted(context: CombatContext) -> void:
	emit_signal("combatStarted", context)

func emitCombatEnded(result: CombatResult) -> void:
	emit_signal("combatEnded", result)

# ==================================================
# BOARD REFILL WRAPPERS
# ==================================================

func emitBoardRefillRequested(request: BoardRefillRequest) -> void:
	emit_signal("boardRefillRequested", request)

func emitBoardRefillResult(result: BoardRefillResult) -> void:
	emit_signal("boardRefillCompleted", result)

# ==================================================
# SCENE LOADER WRAPPERS
# ==================================================
func emitProgressChanged(progress: float) -> void:
	emit_signal("progressChanged", progress)

func emitLoadFinished() -> void:
	emit_signal("loadFinished")

func emitLoadScreenReady() -> void:
	emit_signal("loadScreenReady")
