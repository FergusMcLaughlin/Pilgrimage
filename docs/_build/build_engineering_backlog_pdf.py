from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Pilgrimage_2_Engineering_Backlog.pdf"


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def styles():
    base = getSampleStyleSheet()
    return {
        "Title": ParagraphStyle("Title", parent=base["Title"], fontName="Helvetica-Bold", fontSize=24, leading=29, alignment=TA_LEFT, textColor=colors.HexColor("#111111"), spaceAfter=4),
        "Subtitle": ParagraphStyle("Subtitle", parent=base["Normal"], fontName="Helvetica", fontSize=12.5, leading=16, textColor=colors.HexColor("#555555"), spaceAfter=14),
        "Body": ParagraphStyle("Body", parent=base["BodyText"], fontName="Helvetica", fontSize=9.7, leading=12.4, textColor=colors.HexColor("#1b1b1b"), spaceAfter=5),
        "Small": ParagraphStyle("Small", parent=base["BodyText"], fontName="Helvetica", fontSize=8.6, leading=10.8, textColor=colors.HexColor("#222222"), spaceAfter=3),
        "Lead": ParagraphStyle("Lead", parent=base["BodyText"], fontName="Helvetica", fontSize=9.7, leading=12.8, textColor=colors.HexColor("#1b1b1b"), backColor=colors.HexColor("#F2F4F7"), borderColor=colors.HexColor("#D9DEE7"), borderWidth=0.5, borderPadding=7, spaceAfter=10),
        "H1": ParagraphStyle("H1", parent=base["Heading1"], fontName="Helvetica-Bold", fontSize=15, leading=18, textColor=colors.HexColor("#2E74B5"), spaceBefore=14, spaceAfter=7),
        "H2": ParagraphStyle("H2", parent=base["Heading2"], fontName="Helvetica-Bold", fontSize=12.2, leading=15, textColor=colors.HexColor("#2E74B5"), spaceBefore=11, spaceAfter=4, keepWithNext=True),
        "H3": ParagraphStyle("H3", parent=base["Heading3"], fontName="Helvetica-Bold", fontSize=9.8, leading=12, textColor=colors.HexColor("#1F4D78"), spaceBefore=6, spaceAfter=2, keepWithNext=True),
        "Bullet": ParagraphStyle("Bullet", parent=base["BodyText"], fontName="Helvetica", fontSize=8.9, leading=11.1, textColor=colors.HexColor("#1b1b1b"), leftIndent=8, spaceAfter=2),
        "Code": ParagraphStyle("Code", parent=base["Code"], fontName="Courier", fontSize=7.8, leading=9.6, textColor=colors.HexColor("#222222"), backColor=colors.HexColor("#F7F7F7"), borderPadding=4, spaceAfter=5),
    }


def p(text, style):
    return Paragraph(esc(text), style)


def rich(text, style):
    return Paragraph(text, style)


def bullets(items, st):
    return ListFlowable(
        [ListItem(p(item, st["Bullet"]), leftIndent=10) for item in items],
        bulletType="bullet",
        start="circle",
        leftIndent=13,
        bulletFontName="Helvetica",
        bulletFontSize=6,
        bulletOffsetY=1,
    )


def nums(items, st):
    return ListFlowable(
        [ListItem(p(item, st["Bullet"]), leftIndent=12) for item in items],
        bulletType="1",
        leftIndent=16,
        bulletFontName="Helvetica",
        bulletFontSize=8,
    )


def code(text, st):
    return Paragraph(esc(text).replace("\n", "<br/>"), st["Code"])


def story(title, goal, philosophy, dependencies, files, steps, api, edge_cases, verify):
    return {
        "title": title,
        "goal": goal,
        "philosophy": philosophy,
        "dependencies": dependencies,
        "files": files,
        "steps": steps,
        "api": api,
        "edge_cases": edge_cases,
        "verify": verify,
    }


stories = [
    story(
        "Story 1 - Lock Down Card Placement Ownership",
        "Make the current drag/drop path production-ready before adding new gameplay. A card should move from ON_BOARD to BEING_DRAGGED to either IN_SLOT or back to ON_BOARD through one obvious path.",
        "This preserves the rebuild rule: one owner per responsibility. InputManager owns pointer input, CardSlot owns whether a slot accepts a card, CardStateMachine owns state side effects. Do not recreate the old project's split input ownership.",
        ["None. This is the foundation story."],
        ["src/singletons/input_manager.gd", "src/board/card_slots/card_slot.gd", "src/cards/card.gd", "src/cards/card_states/card_state_machine.gd"],
        [
            "Audit InputManager and keep all pointer drag/drop decisions there. It should connect to cardPressed, slotHovered, and slotUnhovered only.",
            "Keep CardSlot.setCard(card) as the only direct slot placement method. InputManager may call it, but it should not reparent cards itself.",
            "Make InputManager._dropCard(card) call card.cancelDrag() instead of repeating state/mouse_filter logic if you want to tighten encapsulation.",
            "Remove remaining noisy prints from Card.onCardPressed() once card state tests are stable.",
            "Do not add new board input scripts. Future board clicks should go through GlobalSignalBus and GameController, not a second drag manager.",
        ],
        """# Intended ownership
InputManager._finishDragging(mouse_pos)
  -> targetSlot = _findDropTarget()
  -> if targetSlot and targetSlot.canAcceptCard(card): targetSlot.setCard(card)
  -> else: card.cancelDrag()

CardSlot.setCard(card)
  -> currentCard = card
  -> card.reparent(cardAnchor, false)
  -> card.position = Vector2.ZERO
  -> card.placeInSlot()""",
        [
            "Dropping onto an occupied slot must not overwrite currentCard.",
            "Dropping while the dragged card was freed must clear InputManager.cardBeingDragged safely.",
            "card.data may be null in bad test cases; CardSlot.canAcceptCard already guards this and should keep doing so.",
        ],
        [
            "Spawn a card in card_test_scene, drag onto an empty slot, confirm currentState == IN_SLOT.",
            "Try to drag the slotted card again; canBeDragged() should reject it.",
            "Drag a second card onto the same slot; it should not replace the first card.",
        ],
    ),
    story(
        "Story 2 - Add A Real SlotGrid Query API",
        "Give the generated grid a reliable API for movement, refill, combat, and effects. Other systems should never crawl the GridContainer's children manually.",
        "The rebuild should prefer small, named APIs over reaching through scene trees. SlotGrid is the board's source of truth for coordinates and occupancy.",
        ["Story 1"],
        ["src/board/slot_grid/slot_grid.gd"],
        [
            "Rename class_name slot_grid to SlotGrid. Godot style and future type hints will be cleaner.",
            "Change slot.coordinates assignment from Vector2(col, row) to Vector2i(col, row). CardSlot already exports Vector2i.",
            "Decide gridSize meaning and document it. Current code treats gridSize.x as rows and gridSize.y as columns; either keep and name rows/columns or switch cleanly.",
            "Add get_slot_at(coords: Vector2i) -> CardSlot using the slots[row][col] array.",
            "Add get_empty_slots() -> Array[CardSlot] and get_occupied_slots() -> Array[CardSlot].",
            "Add get_center_slot() -> CardSlot. For 3x3 this returns coordinates (1, 1).",
            "Add get_cardinal_neighbours(slot: CardSlot) -> Array[CardSlot].",
        ],
        """func get_slot_at(coords: Vector2i) -> CardSlot:
    if coords.x < 0 or coords.y < 0:
        return null
    if coords.y >= slots.size():
        return null
    if coords.x >= slots[coords.y].size():
        return null
    return slots[coords.y][coords.x]

func get_empty_slots() -> Array[CardSlot]:
    var empty: Array[CardSlot] = []
    for row in slots:
        for slot in row:
            if not slot.isOccupied():
                empty.append(slot)
    return empty""",
        [
            "If gridSize is Vector2i(0, 0), _createGrid() should create no slots but not crash.",
            "If slotScene is missing, push_error and return before instantiate().",
            "get_slot_at() must return null for out-of-bounds coordinates.",
        ],
        [
            "In _ready() after _createGrid(), print/assert slots.size() == 3 for the current scene.",
            "get_center_slot().coordinates should be Vector2i(1, 1) for the current 3x3 grid.",
            "Corner slots should have two cardinal neighbours; center should have four.",
        ],
    ),
    story(
        "Story 3 - Introduce BoardController As The Board Boundary",
        "Create a small board-facing service that owns board operations: place, move, clear, query. It should not own input or combat.",
        "This stops future systems from calling CardSlot and SlotGrid internals directly. The board becomes a bounded subsystem rather than a collection of scene nodes everyone pokes.",
        ["Story 2"],
        ["src/board/board_controller.gd", "src/board/board_controller.tscn or main game scene"],
        [
            "Create BoardController extending Node or Control.",
            "Export a NodePath to SlotGrid or assign it with @onready var grid: SlotGrid.",
            "Add place_card(card: Card, slot: CardSlot) -> bool. It should call slot.setCard(card) after validation.",
            "Add move_card(card: Card, target_slot: CardSlot) -> bool. It should clear the source slot, then place into the target.",
            "Add clear_board() that loops grid.get_occupied_slots() and calls clearSlot().",
            "Emit a new GlobalSignalBus.boardStateChanged signal after successful place/move/clear.",
        ],
        """class_name BoardController
extends Node

@export var grid_path: NodePath
@onready var grid: SlotGrid = get_node(grid_path)

func place_card(card: Card, slot: CardSlot) -> bool:
    if slot == null or not slot.canAcceptCard(card):
        return false
    var ok := slot.setCard(card)
    if ok:
        GlobalSignalBus.emitBoardStateChanged()
    return ok""",
        [
            "Moving from a slot should clear the old slot's currentCard.",
            "Moving to an occupied slot should return false; combat will handle occupied targets later.",
            "BoardController should not call InputManager.lockInput except during future scripted animations.",
        ],
        [
            "Call BoardController.place_card from a test button and confirm slotFilled plus boardStateChanged fire.",
            "Call clear_board and confirm every currentCard is null.",
            "No drag code appears in BoardController.",
        ],
    ),
    story(
        "Story 4 - Build DeckModel Around Card Ids",
        "Add a generic deck that stores card ids, not Card nodes. It can shuffle, draw, add to top/bottom, and report count.",
        "Cards are expensive scene instances and should be created only when revealed. Data-driven ids keep the deck simple, serializable, and testable.",
        ["CardLibrary autoload already exists"],
        ["src/decks/deck_model.gd", "src/decks/deck_model.tscn optional"],
        [
            "Create DeckModel with class_name DeckModel.",
            "Use var cards: Array[String] = [] rather than untyped arrays.",
            "Add initialise_deck(card_ids: Array[String]) that duplicates input and shuffles optionally.",
            "Add draw_card_id() -> String that pop_fronts safely and returns an empty string when empty.",
            "Add draw_card() -> Card that calls CreateCard.createCard(id), but keep draw_card_id available for tests.",
            "Add get_deck_size(), add_card_to_top(id), add_card_to_bottom(id), shuffle_deck().",
            "Add deck signals to GlobalSignalBus: deckShuffled(deck), deckEmptied(deck), cardDrawn(card).",
        ],
        """func draw_card() -> Card:
    var card_id := draw_card_id()
    if card_id == "":
        return null
    var card := CreateCard.new().createCard(card_id)
    if card != null:
        GlobalSignalBus.emitCardDrawn(card)
    return card""",
        [
            "CreateCard is currently not an autoload. Either instantiate CreateCard.new() or promote it later.",
            "If CardLibrary does not have an id, CreateCard returns null; deck should handle that without losing game flow.",
            "Do not put deck click UI behavior in DeckModel yet.",
        ],
        [
            "Initialize with three ids; get_deck_size returns 3.",
            "Draw three cards; size reaches 0 and fourth draw returns null.",
            "Shuffle does not change count.",
        ],
    ),
    story(
        "Story 5 - Implement JourneyDeck Board Refill",
        "Add the board-adventure draw pile. It reveals cards into empty slots and refills the previous slot after the player moves.",
        "This supports the no-hand design: the board is the game space, and the journey deck is how the game introduces choices.",
        ["Story 2", "Story 3", "Story 4"],
        ["src/decks/journey_deck.gd", "src/decks/journey_deck.tscn optional"],
        [
            "Create JourneyDeck extending DeckModel.",
            "Add initialise_journey_deck() with a temporary preset list using ids from data/card_dictionary.json.",
            "Add reveal_top_card(slot: CardSlot) -> Card. It draws a card, calls BoardController.place_card or slot.setCard, and flips/reveals if needed.",
            "Add fill_empty_slots(grid: SlotGrid) to iterate grid.get_empty_slots().",
            "Later, route reveal_top_card through ActionQueue using REVEAL_CARD instead of direct placement.",
        ],
        """func fill_empty_slots(grid: SlotGrid) -> void:
    for slot in grid.get_empty_slots():
        if get_deck_size() <= 0:
            return
        reveal_top_card(slot)""",
        [
            "Do not fill the center slot after the player is placed there.",
            "If deck empties mid-fill, stop without error.",
            "If CreateCard returns null for a bad id, continue to the next slot or fail loudly during setup.",
        ],
        [
            "With a 3x3 empty grid and at least 9 ids, fill_empty_slots fills 9 slots.",
            "With player in center first, fill_empty_slots fills 8 slots.",
            "Deck count decreases by the number of revealed cards.",
        ],
    ),
    story(
        "Story 6 - Define Actions As Gameplay Contracts",
        "Create named action dictionaries before adding effects and combat. Actions describe intent; processors apply changes.",
        "This is the key rebuild improvement over direct script-to-script mutation. It makes effects possible without spaghetti.",
        ["Stories 1-5"],
        ["src/actions/action_types.gd"],
        [
            "Create class_name ActionTypes.",
            "Define const REVEAL_CARD, MOVE_CARD, MODIFY_STATS, DESTROY_CARD, DEAL_DAMAGE, DRAW_CARD, GAME_OVER.",
            "Add static make(type: String, source=null, target=null, data: Dictionary={}) -> Dictionary.",
            "Add static is_valid(action: Dictionary) -> bool.",
            "Do not put action execution here.",
        ],
        """static func make(type: String, source = null, target = null, data: Dictionary = {}) -> Dictionary:
    return {
        "type": type,
        "source": source,
        "target": target,
        "data": data
    }""",
        [
            "Use constants everywhere. Do not type raw strings like 'destroy_card' in effect scripts.",
            "Keep action data dictionaries small and documented per action.",
        ],
        [
            "ActionTypes.is_valid(ActionTypes.make(ActionTypes.MOVE_CARD)) returns true.",
            "Unknown type returns false or warns.",
        ],
    ),
    story(
        "Story 7 - Add ActionQueue Autoload",
        "Add a FIFO queue so gameplay state changes run in a predictable order.",
        "Effects, combat, and deck refill need a shared timeline. A queue prevents nested direct calls where one system mutates state during another system's work.",
        ["Story 6"],
        ["src/singletons/actions/action_queue.gd", "project.godot autoload"],
        [
            "Create action_queue.gd extending Node.",
            "Add var _queue: Array[Dictionary] = [].",
            "Add enqueue_action(action), pop_next_action(), peek_next_action(), queue_has_actions(), clear_queue(), get_queue_size().",
            "Validate actions using ActionTypes.is_valid before appending.",
            "Add actionEnqueued, actionPopped, queueCleared signals locally or via GlobalSignalBus.",
            "Register ActionQueue as an autoload in project.godot.",
        ],
        """func enqueue_action(action: Dictionary) -> void:
    if not ActionTypes.is_valid(action):
        push_warning("ActionQueue rejected invalid action: %s" % [action])
        return
    _queue.append(action)
    emit_signal("actionEnqueued", action)""",
        [
            "Never process actions inside enqueue_action.",
            "Avoid queueing empty dictionaries.",
            "Clear queue on new run setup to avoid old actions firing in a new game.",
        ],
        [
            "Queue size increments after valid enqueue.",
            "Invalid action does not change queue size.",
            "pop_next_action returns actions in insertion order.",
        ],
    ),
    story(
        "Story 8 - Add ActionProcessor Autoload",
        "Resolve queued actions from one place. This becomes the gate for board changes, stat changes, destruction, and later effects.",
        "This keeps rules deterministic. Systems request changes; ActionProcessor performs changes. That is the lead-engineer boundary that prevents the rebuild becoming the old project again.",
        ["Story 6", "Story 7", "Story 3"],
        ["src/singletons/actions/action_processor.gd", "project.godot autoload"],
        [
            "Create action_processor.gd extending Node.",
            "In _process, if not busy and ActionQueue has actions, pop one and resolve it.",
            "Before resolving, call EffectMediator.on_action_pre(action) once that exists.",
            "After resolving, call EffectMediator.on_action_post(action).",
            "Implement handlers: _handle_reveal_card, _handle_move_card, _handle_modify_stats, _handle_destroy_card, _handle_deal_damage.",
            "Keep visual animation minimal until logic is stable.",
        ],
        """func _resolve_action(action: Dictionary) -> void:
    match str(action.get("type", "")):
        ActionTypes.REVEAL_CARD:
            _handle_reveal_card(action)
        ActionTypes.MOVE_CARD:
            _handle_move_card(action)
        ActionTypes.MODIFY_STATS:
            _handle_modify_stats(action)
        _:
            push_warning("Unknown action: %s" % [action])""",
        [
            "Destroyed cards must clear their slot before queue_free.",
            "MODIFY_STATS should clamp health if you decide health cannot go below 0.",
            "MOVE_CARD to an occupied slot should fail unless combat has already cleared it.",
        ],
        [
            "Enqueue MODIFY_STATS and confirm card visuals update.",
            "Enqueue DESTROY_CARD and confirm slot currentCard is null.",
            "Processor does not re-enter itself while busy.",
        ],
    ),
    story(
        "Story 9 - Add Effect Data Registry",
        "Load data/effect_dictionary.json into typed EffectData resources and make them available by id.",
        "This mirrors CardData and keeps effects data-driven. Cards stay declarative: they list effect ids; runtime systems decide what those ids do.",
        ["Card data loader pattern exists"],
        ["src/effects/effect_data.gd", "src/effects/effect_data_factory.gd", "src/singletons/registries/effect_data_registry.gd", "data/effect_dictionary.json"],
        [
            "Create EffectData resource with id, trigger, effectType, effectParameters.",
            "Create EffectDataFactory.fromDictionary(dictionary).",
            "Create EffectDictionaryJsonLoader or reuse a generic JSON loader if you extract one.",
            "Create EffectDataRegistry autoload with get_effect_data(effect_id).",
            "Load all effects at _ready and store by id.",
        ],
        """class_name EffectData
extends Resource

@export var id: String
@export var trigger: String
@export var effectType: String
@export var effectParameters: Dictionary = {}""",
        [
            "Missing effects referenced by CardData.effects should warn but not crash card creation.",
            "Effect parameter names should match JSON exactly at the boundary, then convert to camelCase inside typed code if desired.",
        ],
        [
            "Every id in data/effect_dictionary.json can be fetched from EffectDataRegistry.",
            "Bad id returns null and logs a useful warning.",
        ],
    ),
    story(
        "Story 10 - Add EffectMediator And Effect Instances",
        "Create runtime effect objects from EffectData and dispatch action hooks to them.",
        "This keeps effects from directly subscribing all over the project. The mediator owns listeners; effects own their own reaction logic.",
        ["Story 6", "Story 7", "Story 8", "Story 9"],
        ["src/effects/card_effect_factory.gd", "src/singletons/effects/effect_mediator.gd", "src/cards/card.gd or CardSlot.setCard cleanup hook"],
        [
            "Create CardEffectFactory.create(card: Card, effect_data: EffectData).",
            "Create EffectMediator autoload with listeners: Array[Dictionary].",
            "Add register_card_effects(card) that loops card.data.effects, creates effect instances, and stores {card, effect, trigger}.",
            "Call register_card_effects when a card enters IN_SLOT or after CardSlot.setCard succeeds.",
            "Add remove_listeners_for_card(card) and call it from CardSlot.clearSlot and destroy actions.",
            "Add on_action_pre(action) and on_action_post(action), called by ActionProcessor.",
        ],
        """func on_action_post(action: Dictionary) -> void:
    _clean_dead_listeners()
    for listener in listeners:
        var effect = listener.get("effect")
        if effect != null and effect.has_method("on_action"):
            effect.on_action(action, "post")""",
        [
            "Avoid registering the same card's effects twice if setCard is called repeatedly.",
            "Clean up listeners when cards are queue_freed.",
            "Effects should enqueue actions, not directly alter other cards.",
        ],
        [
            "Place a card with an effect id and confirm mediator listener count increases.",
            "Clear/destroy the card and confirm listener count decreases.",
            "Post-action dispatch calls effect.on_action.",
        ],
    ),
    story(
        "Story 11 - Implement The First Three Effects",
        "Build SolitaryBeast, HealOnKill, and BuffAttackOnKill as proof that the action/effect architecture works.",
        "This deliberately tests three important effect classes: board-state recalculation, pre-destroy reaction, and stat modification.",
        ["Story 10"],
        ["src/effects/card_effects/solitary_beast.gd", "src/effects/card_effects/heal_on_kill.gd", "src/effects/card_effects/buff_attack_on_kill.gd"],
        [
            "SolitaryBeast: on board-changing post actions, count matching cards on the board and enqueue MODIFY_STATS for host card.",
            "HealOnKill: on DESTROY_CARD pre action, if host card is the destroyed target, heal the destroyer.",
            "BuffAttackOnKill: on DESTROY_CARD pre action, if host card is the destroyed target, increase destroyer's attack.",
            "Read base stats from card.data.baseHealth/baseAttack and current stats from card.health/card.attack.",
            "Do not use old card.cardHealth/card.cardAttack names.",
        ],
        """# Example effect rule
func on_action(action: Dictionary, when: String) -> void:
    if when != "pre":
        return
    if action.get("type") != ActionTypes.DESTROY_CARD:
        return
    var attacker: Card = action.get("source")
    var destroyed: Card = action.get("target")
    if destroyed != hostCard:
        return
    ActionQueue.enqueue_action(ActionTypes.make(ActionTypes.MODIFY_STATS, hostCard, attacker, {"health": attacker.health + hostCard.data.baseHealth}))""",
        [
            "Prevent infinite loops: SolitaryBeast should react to board-changing actions, not its own MODIFY_STATS action unless intentional.",
            "If attacker is null or freed, effect should return.",
            "If hostCard is freed, effect should return and mediator should clean it later.",
        ],
        [
            "A Woods card entering board changes SolitaryBeast stats.",
            "Destroying a HealOnKill host increases attacker health.",
            "Destroying a BuffAttackOnKill host increases attacker attack.",
        ],
    ),
    story(
        "Story 12 - Add GameController Setup",
        "Start a run: create player, place them in the center, initialize journey deck, fill remaining slots, enter PLAYER_TURN.",
        "Setup belongs in one run controller, not in card tests or deck scripts. This creates a real game spine while keeping UI optional.",
        ["Stories 2-5"],
        ["src/singletons/managers/game_controller.gd or src/game/game_controller.gd", "main.tscn or new src/main/game_scene.tscn"],
        [
            "Create GameController with enum GameState { SETUP, PLAYER_TURN, MOVING, COMBAT, GAME_OVER }.",
            "Export NodePaths for BoardController, SlotGrid, JourneyDeck.",
            "On start_run(), lock InputManager, clear board, create player with CreateCard.",
            "Place player in slot_grid.get_center_slot().",
            "Initialize JourneyDeck and call fill_empty_slots.",
            "Unlock InputManager and set state PLAYER_TURN.",
        ],
        """func start_run() -> void:
    current_state = GameState.SETUP
    InputManager.lockInput()
    board.clear_board()
    var player := CreateCard.new().createCard("C_0000")
    board.place_card(player, grid.get_center_slot())
    journey_deck.initialise_journey_deck()
    journey_deck.fill_empty_slots(grid)
    current_state = GameState.PLAYER_TURN
    InputManager.unlockInput()""",
        [
            "If player card creation fails, stay in SETUP and push_error.",
            "If center slot is missing, fail setup loudly.",
            "Do not let journey deck overwrite center slot.",
        ],
        [
            "Running main scene places one player in center.",
            "Other empty slots fill from journey deck.",
            "Game state becomes PLAYER_TURN only after setup completes.",
        ],
    ),
    story(
        "Story 13 - Add Board Movement Rules",
        "Allow the player character to move to cardinal-adjacent slots and reject illegal movement.",
        "The board is the play space. Movement rules should be explicit and readable rather than hidden in input code.",
        ["Story 12"],
        ["src/singletons/managers/game_controller.gd", "src/board/slot_grid/slot_grid.gd"],
        [
            "Add a way to identify the player card: CardData.isPlayer already exists.",
            "On slotClicked or cardPressed for board cards, resolve target slot.",
            "Find the current player slot using grid.get_occupied_slots() and card.data.isPlayer.",
            "Check target slot is in grid.get_cardinal_neighbours(player_slot).",
            "If target is empty, enqueue MOVE_CARD.",
            "After move succeeds, enqueue/refill previous slot from JourneyDeck.",
        ],
        """func is_valid_move(from_slot: CardSlot, to_slot: CardSlot) -> bool:
    if from_slot == null or to_slot == null:
        return false
    var delta := to_slot.coordinates - from_slot.coordinates
    return abs(delta.x) + abs(delta.y) == 1""",
        [
            "Clicking the player card itself should not move.",
            "Clicking diagonal slots should do nothing or emit invalid feedback.",
            "During COMBAT or GAME_OVER, ignore movement input.",
        ],
        [
            "Center to top/left/right/bottom works.",
            "Center to corner is rejected.",
            "Previous slot refills after a successful empty-slot move.",
        ],
    ),
    story(
        "Story 14 - Add Combat Resolution",
        "When the player moves into an occupied adjacent slot, resolve combat instead of simple movement.",
        "Combat is game rule logic. It should produce actions and signals, allowing effects and UI to react without special casing.",
        ["Story 8", "Story 13"],
        ["src/game/combat_resolver.gd or GameController method", "src/actions/action_types.gd", "src/singletons/actions/action_processor.gd"],
        [
            "Add CombatResolver.calculate(attacker: Card, defender: Card) -> Dictionary or a GameController method.",
            "Define whether attack > health or attack >= health kills. Old code used >; choose and document.",
            "Enqueue DEAL_DAMAGE for defender and attacker as needed.",
            "If defender dies, enqueue DESTROY_CARD with source attacker target defender.",
            "If attacker survives and defender is destroyed, enqueue MOVE_CARD into defender slot.",
            "Emit battleCompleted(attacker, defender, result) through GlobalSignalBus.",
        ],
        """var result := {
    "attacker_survives": attacker.health > defender.attack,
    "defender_destroyed": attacker.attack >= defender.health,
    "attacker_damage": defender.attack,
    "defender_damage": attacker.attack
}""",
        [
            "Buff cards with 0 attack may be consumed without damaging player if that is intended.",
            "If attacker dies, do not move into defender slot.",
            "Effects triggered by DESTROY_CARD must run before destroyed card is freed.",
        ],
        [
            "Attacking weak enemy destroys it and moves player.",
            "Attacking strong enemy damages or kills player.",
            "battleCompleted signal includes enough data for UI.",
        ],
    ),
    story(
        "Story 15 - Add Game Over State",
        "End the run cleanly when the player dies or another terminal condition occurs.",
        "Clear state boundaries prevent lingering input, queued actions, and invalid board interactions after the run should be over.",
        ["Story 14"],
        ["src/singletons/managers/game_controller.gd", "src/singletons/global_signal_bus.gd"],
        [
            "Add signal gameOver(reason) and emitGameOver(reason) wrapper to GlobalSignalBus.",
            "In GameController, add enter_game_over(reason: String).",
            "Call InputManager.lockInput() and ActionQueue.clear_queue() when entering GAME_OVER.",
            "Trigger game over when player health <= 0 after combat/action processing.",
            "Decide and document empty journey deck outcome: win, exhaustion, or continue until board cleared.",
        ],
        """func enter_game_over(reason: String) -> void:
    current_state = GameState.GAME_OVER
    InputManager.lockInput()
    ActionQueue.clear_queue()
    GlobalSignalBus.emitGameOver(reason)""",
        [
            "Do not emit gameOver more than once.",
            "Queued actions from the previous state should not continue after GAME_OVER unless explicitly allowed.",
        ],
        [
            "Player death locks input.",
            "UI/debug receives a gameOver reason.",
            "Trying to move after game over does nothing.",
        ],
    ),
    story(
        "Story 16 - Build A Real Game Scene",
        "Create a playable scene separate from card_test_scene. The test scene remains a lab; the main scene owns the real run.",
        "The old project let test and production ideas blur. The rebuild should separate experiments from the scene the player actually runs.",
        ["Stories 3-5", "Story 12"],
        ["src/main/game_scene.tscn", "main.tscn", "project.godot"],
        [
            "Create a new game scene with SlotGrid, BoardController, JourneyDeck, and GameController.",
            "Wire exported NodePaths in the editor rather than hardcoding long get_node paths.",
            "Keep card_test_scene.tscn as project main until game_scene setup is reliable.",
            "Once stable, update project.godot run/main_scene to the new scene.",
            "Remove test-only buttons from the real game scene.",
        ],
        """GameScene
  CanvasLayer/UI
  Board
    SlotGrid
    BoardController
  Decks
    JourneyDeck
  GameController""",
        [
            "Do not instance BoardInputControler again; it was intentionally removed.",
            "Do not depend on card_test_scene.gd constants like CARD_START_POS.",
        ],
        [
            "Opening game_scene starts a run without using test buttons.",
            "card_test_scene still runs for card experiments.",
            "No missing NodePath errors appear in output.",
        ],
    ),
    story(
        "Story 17 - Minimal Run UI",
        "Show just enough UI to make the run understandable: state, deck count, combat feedback, game over.",
        "This supports the no-hand design. UI should inform the board game, not become a second card system.",
        ["Story 16"],
        ["src/ui/run_status.gd", "src/ui/run_status.tscn", "src/singletons/global_signal_bus.gd"],
        [
            "Create a small Control scene anchored to a corner.",
            "Show current GameController state.",
            "Show JourneyDeck count after draw/reveal.",
            "Listen to battleCompleted and show short feedback text.",
            "Listen to gameOver and show final reason.",
            "Keep it read-only; no buttons except perhaps restart later.",
        ],
        """RunStatus listens to:
- boardStateChanged
- battleCompleted(attacker, defender, result)
- gameOver(reason)
- deck count changes""",
        [
            "UI should not own game rules.",
            "If a signal arrives before references are ready, ignore safely.",
        ],
        [
            "Deck count changes when slots are filled.",
            "Combat message appears after fight.",
            "Game over message appears and remains visible.",
        ],
    ),
    story(
        "Story 18 - Keep Card Test Scene As A Lab",
        "Protect the card test scene as a place for experiments while preventing it from defining production architecture.",
        "This gives you speed without mess. Experiments stay in src/tests; production code remains clear.",
        ["Always ongoing"],
        ["src/tests/card_test_scene.tscn", "src/tests/card_test_scene.gd"],
        [
            "Keep spawn buttons for representative cards.",
            "Keep state/stat debug controls only in the test scene.",
            "Add future buttons for effect test cards after effects are implemented.",
            "Remove or gate noisy debug printing.",
            "Never make GameController depend on card_test_scene.gd.",
        ],
        """Allowed in tests:
- manual card spawning
- stat cycling
- effect trigger probes
- visual sizing experiments

Not allowed in production:
- test buttons
- debug-only layout constants
- assumptions about CardsRoot""",
        [
            "Test scene may be messy, but mess should not leak into src/main or src/singletons.",
            "If a test helper becomes generally useful, extract it into a real helper with a clear name.",
        ],
        [
            "Card test still creates cards after main scene exists.",
            "Main scene contains no test controls.",
            "Debug print noise is limited to active investigations.",
        ],
    ),
]


def page_cb(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawString(inch, 0.55 * inch, "Pilgrimage_2 Engineering Backlog")
    canvas.drawRightString(7.5 * inch, 0.55 * inch, f"Page {doc.page}")
    canvas.restoreState()


def add_story(flow, s, st):
    flow.append(Paragraph(esc(s["title"]), st["H2"]))
    flow.append(Paragraph("<b>Goal.</b> " + esc(s["goal"]), st["Body"]))
    flow.append(Paragraph("<b>Design justification.</b> " + esc(s["philosophy"]), st["Body"]))
    flow.append(Paragraph("Dependencies", st["H3"]))
    flow.append(bullets(s["dependencies"], st))
    flow.append(Paragraph("Files to create/change", st["H3"]))
    flow.append(bullets(s["files"], st))
    flow.append(Paragraph("Implementation steps", st["H3"]))
    flow.append(nums(s["steps"], st))
    flow.append(Paragraph("Suggested API / shape", st["H3"]))
    flow.append(code(s["api"], st))
    flow.append(Paragraph("Edge cases", st["H3"]))
    flow.append(bullets(s["edge_cases"], st))
    flow.append(Paragraph("Verification", st["H3"]))
    flow.append(bullets(s["verify"], st))
    flow.append(Spacer(1, 8))


def build():
    st = styles()
    doc = BaseDocTemplate(
        str(OUT),
        pagesize=letter,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
        topMargin=0.75 * inch,
        bottomMargin=0.8 * inch,
        title="Pilgrimage_2 Engineering Backlog",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
    doc.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=page_cb))

    flow = []
    flow.append(Paragraph("Pilgrimage_2", st["Title"]))
    flow.append(Paragraph("Engineering Backlog and Implementation Guide", st["Subtitle"]))
    flow.append(Paragraph("<b>Lead engineer note.</b> This document is intentionally more prescriptive than a normal brainstorm. Treat each story as a small ticket bundle: it states why the work exists, what files it touches, the concrete API shape, edge cases, and how to verify it. The main architectural rule is simple: one system owns each responsibility.", st["Lead"]))

    summary_rows = [["Priority", "Story", "Why now"]]
    priorities = [
        ("P0", "Stories 1-3", "Harden card placement and board API before game rules depend on them."),
        ("P1", "Stories 4-8", "Add deck and action pipeline before effects/combat create coupling."),
        ("P2", "Stories 9-11", "Add effects after action flow exists."),
        ("P3", "Stories 12-15", "Build run setup, movement, combat, and end states."),
        ("P4", "Stories 16-18", "Create main scene/UI while preserving the test lab."),
    ]
    for row in priorities:
        summary_rows.append([Paragraph(esc(row[0]), st["Small"]), Paragraph(esc(row[1]), st["Small"]), Paragraph(esc(row[2]), st["Small"])])
    table = Table(summary_rows, colWidths=[0.65 * inch, 1.35 * inch, 4.7 * inch], hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#1F4D78")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8.5),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#D8DDE6")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    flow.append(table)
    flow.append(Spacer(1, 10))

    flow.append(Paragraph("Current Design Constraints", st["H1"]))
    flow.append(bullets([
        "InputManager is currently the only drag/drop owner and should stay that way.",
        "Card uses data: CardData, health, attack. Do not reintroduce old names like cardData, cardHealth, or cardAttack.",
        "CardSlot already owns canAcceptCard(), setCard(), clearSlot(), and currentCard.",
        "SlotGrid currently generates the 3x3 slot array; it needs query helpers before movement/refill work.",
        "No hand system is planned. Journey deck plus board movement is the core play model.",
    ], st))
    flow.append(PageBreak())

    flow.append(Paragraph("Detailed Stories", st["H1"]))
    for s in stories:
        add_story(flow, s, st)

    flow.append(PageBreak())
    flow.append(Paragraph("Definition Of Done For This Backlog", st["H1"]))
    flow.append(bullets([
        "A new developer can open a story and know which files to touch without asking for architectural context.",
        "Every new singleton has a clear reason to be global and is listed in project.godot.",
        "Every gameplay state mutation either belongs to CardStateMachine, CardSlot/BoardController, or ActionProcessor.",
        "The card test scene remains useful but is not required for the main game scene.",
        "Effects do not directly mutate unrelated cards; they enqueue actions.",
    ], st))

    doc.build(flow)
    print(OUT)


if __name__ == "__main__":
    build()
