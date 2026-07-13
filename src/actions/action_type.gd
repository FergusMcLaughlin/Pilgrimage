class_name ActionType
extends RefCounted

const MOVE_CARD = "move_card"
const DEAL_DAMAGE = "deal_damage"
const HEAL = "heal" # unique to modify stats as im thinking of possible effects implactaions i want ot handle buffs different to say lifesteal
const MODIFY_STATS = "modify_stats"
const REMOVE_CARD = "remove_card"
const DELETE_CARD = "delete_card"
const REVIVE_CARD = "revive_card"
const DRAW_CARD = "draw_card"
const REVEAL_CARD = "reveal_card"
const HIDE_CARD = "hide_card"
const MUTATE_CARD = "mutate_card"
const GAME_OVER = "game_over"

const VALID_TYPES: Array[String] = [
	MOVE_CARD,
	DEAL_DAMAGE,
	HEAL,
	MODIFY_STATS,
	REMOVE_CARD,
	DELETE_CARD,
	REVIVE_CARD,
	DRAW_CARD,
	REVEAL_CARD,
	HIDE_CARD,
	MUTATE_CARD,
	GAME_OVER,
]

static func make(actionType: String, source = null, target = null, data: Dictionary = {}) -> Dictionary:
	return {
		"type": actionType,
		"source": source,
		"target": target,
		"data": data.duplicate(),
	}
	
static func isValid(action: Dictionary) -> bool:
	if action.is_empty():
		push_error("ActionType: Malformed action. Action is empty.")
		return false
	
	if(!action.has("type") || !action.has("source") || !action.has("target") || !action.has("data")):
		push_error("ActionType: Malformed action. Missing required action parts.")
		return false
	
	if !(action["type"] is String):
		push_error("ActionType: Malformed action. Type is not a String.")
		return false
	
	if action["type"] not in VALID_TYPES:
		push_error("ActionType: Unknown action type: %s." % action["type"])
		return false
	
	if !(action["data"] is Dictionary):
		push_error("ActionType: Malformed action. Data is not a Dictionary.")
		return false
	
	return true
