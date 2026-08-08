class_name CardEffect
extends RefCounted

var hostCard: Card
var data: EffectData
var context: EffectContext

func setup (card: Card, effectData: EffectData, effectContext: EffectContext) -> void:
	hostCard = card
	data = effectData
	context = effectContext

func onActivated() -> void:
	pass

func onEvent(_event: Dictionary) -> void:
	pass

func onDeactivated() -> void:
	pass
