#Autoloaded as GlobalSignalBus
extends Node

#Signals-

#Card

signal cardHovered(card)
signal cardUnhovered(card)
signal cardClicked(card)
signal cardFlipped(card)

#Emit Wrappers-

#Card

func emitCardHovered(card) -> void:
	emit_signal("cardHovered", card)

func emitCardUnhovered(card) -> void:
	emit_signal("cardUnhovered", card)

func emitCardClicked(card) -> void:
	emit_signal("cardClicked", card)

func emitCardFlipped(card) -> void:
	emit_signal("cardFlipped", card)
