class_name ActionType
extends RefCounted

const MOVE_CARD = "move_card"
const MODIFY_STATS = "modify_stats"
const DEAL_DAMAGE = "deal_damage"
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
	MODIFY_STATS,
	DEAL_DAMAGE,
	REMOVE_CARD,
	DELETE_CARD,
	REVIVE_CARD,
	DRAW_CARD,
	REVEAL_CARD,
	HIDE_CARD,
	MUTATE_CARD,
	GAME_OVER
]

static func make(actionType: String, source: Variant = null, target: Variant = null, payload: GameActionPayload = null) -> GameAction:
	return GameAction.create(actionType, source, target, payload)
