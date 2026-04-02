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
signal slotEmptied(cardSlot, card)

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
