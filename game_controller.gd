extends Control

const PLAYER_ONE := GameEnums.PlayerId.PLAYER_ONE
const PLAYER_TWO := GameEnums.PlayerId.PLAYER_TWO

var state := GameState.new()
var status_label: Label
var player_one_label: Label
var player_two_label: Label
var geisha_label: Label
var draw_button: Button
var settle_button: Button
var action_buttons: Array[Button] = []

func _ready() -> void:
    get_viewport().size_changed.connect(_fit_board)
    _build_debug_panel()
    _initialize_game()
    call_deferred("_fit_board")

func _fit_board() -> void:
    var board := get_node_or_null("Board") as Control
    if board == null:
        return
    var design_size := Vector2(1536.0, 1024.0)
    var viewport_size := get_viewport_rect().size
    var factor := minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y)
    board.scale = Vector2.ONE * maxf(0.1, factor)
    board.position = (viewport_size - design_size * factor) * 0.5

func _initialize_game() -> void:
    state.initialize()
    _create_geishas()
    _create_gift_deck()
    _set_status("准备完成：点击“开始回合”")
    _refresh_ui()

func _create_geishas() -> void:
    state.geishas.clear()
    var charms := [1, 2, 2, 2, 2, 3, 4]
    for index in 7:
        var geisha := GeishaData.new().setup(
            "geisha_%d" % (index + 1),
            "艺伎 %d" % (index + 1),
            charms[index],
            "gift_%d" % (index + 1)
        )
        state.geishas.append(geisha)

func _create_gift_deck() -> void:
    state.deck.clear()
    var card_id := 1
    for geisha_index in 7:
        var count := state.geishas[geisha_index].charm_value
        for _copy in count:
            var card := GiftCardData.new().setup(
                "gift_card_%d" % card_id,
                "gift_%d" % (geisha_index + 1),
                "geisha_%d" % (geisha_index + 1)
            )
            state.deck.append(card)
            card_id += 1
    state.deck.shuffle()

func _start_round() -> void:
    state.begin_round()
    state.removed_card = state.deck.pop_back()
    for player in state.players.values():
        for _card_index in 6:
            if state.deck.is_empty():
                break
            player.hand_cards.append(state.deck.pop_back())
    _set_status("第 %d 回合开始：%s 抽牌" % [state.round_number, _player_name(state.active_player)])
    _refresh_ui()

func _draw_card() -> void:
    if state.phase != GameEnums.GamePhase.ROUND_DEAL and state.phase != GameEnums.GamePhase.PLAYER_DRAW:
        return
    if state.deck.is_empty():
        _set_status("牌库已空，请进行结算")
        return
    var player: PlayerState = state.players[state.active_player]
    player.hand_cards.append(state.deck.pop_back())
    state.phase = GameEnums.GamePhase.PLAYER_CHOOSE_ACTION
    _set_status("%s 已抽牌，请选择一个行动" % _player_name(state.active_player))
    _refresh_ui()

func _choose_action(action_type: GameEnums.ActionType) -> void:
    if state.phase != GameEnums.GamePhase.PLAYER_CHOOSE_ACTION:
        return
    var player: PlayerState = state.players[state.active_player]
    var token := player.get_token(action_type)
    if token == null or not token.is_available():
        _set_status("这个行动本回合已经使用过")
        return
    if player.hand_cards.is_empty():
        _set_status("手牌不足，无法行动")
        return
    token.mark_used()
    _resolve_action(action_type)
    state.actions_completed[state.active_player] += 1
    if state.actions_completed[PLAYER_ONE] >= 4 and state.actions_completed[PLAYER_TWO] >= 4:
        state.phase = GameEnums.GamePhase.ROUND_SCORING
        _set_status("双方已完成 4 次行动，请点击“结算”")
    else:
        state.active_player = PLAYER_TWO if state.active_player == PLAYER_ONE else PLAYER_ONE
        state.phase = GameEnums.GamePhase.PLAYER_DRAW
        _set_status("行动完成，轮到%s抽牌" % _player_name(state.active_player))
    _refresh_ui()

func _resolve_action(action_type: GameEnums.ActionType) -> void:
    var current: PlayerState = state.players[state.active_player]
    var other_id := PLAYER_TWO if state.active_player == PLAYER_ONE else PLAYER_ONE
    var other: PlayerState = state.players[other_id]
    match action_type:
        GameEnums.ActionType.SECRET:
            var card: GiftCardData = current.hand_cards.pop_back()
            card.is_hidden = true
            current.secret_cards.append(card)
        GameEnums.ActionType.TRADEOFF:
            for _index in mini(2, current.hand_cards.size()):
                current.tradeoff_cards.append(current.hand_cards.pop_back())
        GameEnums.ActionType.GIFT:
            for _index in mini(3, current.hand_cards.size()):
                var card: GiftCardData = current.hand_cards.pop_back()
                if _index == 0:
                    other.hand_cards.append(card)
                else:
                    _send_card(current, card)
        GameEnums.ActionType.COMPETITION:
            for _index in mini(4, current.hand_cards.size()):
                var card: GiftCardData = current.hand_cards.pop_back()
                if _index % 2 == 0:
                    _send_card(other, card)
                else:
                    _send_card(current, card)

func _send_card(player: PlayerState, card: GiftCardData) -> void:
    if not player.sent_cards_by_geisha.has(card.target_geisha_id):
        player.sent_cards_by_geisha[card.target_geisha_id] = []
    player.sent_cards_by_geisha[card.target_geisha_id].append(card)
    card.location = &"sent"

func _settle_round() -> void:
    if state.phase != GameEnums.GamePhase.ROUND_SCORING:
        _set_status("双方必须各完成 4 次行动后才能结算")
        return
    for player_id in [PLAYER_ONE, PLAYER_TWO]:
        var player: PlayerState = state.players[player_id]
        for card in player.secret_cards:
            _send_card(player, card)
        player.secret_cards.clear()
    for geisha in state.geishas:
        var one_count := _gift_count(PLAYER_ONE, geisha.geisha_id)
        var two_count := _gift_count(PLAYER_TWO, geisha.geisha_id)
        if one_count > two_count:
            geisha.owner = GameEnums.GeishaOwner.PLAYER_ONE
        elif two_count > one_count:
            geisha.owner = GameEnums.GeishaOwner.PLAYER_TWO
    state.phase = GameEnums.GamePhase.CHECK_VICTORY
    var one_won := state.has_won(PLAYER_ONE)
    var two_won := state.has_won(PLAYER_TWO)
    if one_won or two_won:
        state.winner = PLAYER_ONE if one_won else PLAYER_TWO
        state.phase = GameEnums.GamePhase.GAME_OVER
        _set_status("%s 获胜！" % _player_name(state.winner))
    else:
        state.starting_player = PLAYER_TWO if state.starting_player == PLAYER_ONE else PLAYER_ONE
        state.phase = GameEnums.GamePhase.ROUND_RESET
        _set_status("本回合结算完成，点击“开始回合”继续")
    _refresh_ui()

func _gift_count(player_id: GameEnums.PlayerId, geisha_id: StringName) -> int:
    var player: PlayerState = state.players[player_id]
    return player.sent_cards_by_geisha.get(geisha_id, []).size()

func _build_debug_panel() -> void:
    var panel := VBoxContainer.new()
    panel.name = "GameControls"
    panel.position = Vector2(1060, 250)
    panel.size = Vector2(420, 570)
    panel.add_theme_constant_override("separation", 8)
    get_node("Board").add_child(panel)
    var title := Label.new()
    title.text = "游戏控制"
    title.add_theme_font_size_override("font_size", 24)
    panel.add_child(title)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(360, 60)
    panel.add_child(status_label)
    draw_button = Button.new()
    draw_button.text = "开始回合 / 抽牌：开始新回合或抽 1 张礼物牌"
    draw_button.pressed.connect(_on_draw_button_pressed)
    panel.add_child(draw_button)
    for pair in [["密约", GameEnums.ActionType.SECRET], ["取舍", GameEnums.ActionType.TRADEOFF], ["赠予", GameEnums.ActionType.GIFT], ["竞争", GameEnums.ActionType.COMPETITION]]:
        var button := Button.new()
        button.text = "%s：%s" % [pair[0], _action_description(pair[1])]
        button.pressed.connect(_choose_action.bind(pair[1]))
        action_buttons.append(button)
        panel.add_child(button)
    settle_button = Button.new()
    settle_button.text = "结算本回合：比较 7 位艺伎归属"
    settle_button.pressed.connect(_settle_round)
    panel.add_child(settle_button)
    player_one_label = Label.new()
    panel.add_child(player_one_label)
    player_two_label = Label.new()
    panel.add_child(player_two_label)
    geisha_label = Label.new()
    geisha_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(geisha_label)

func _action_description(action_type: GameEnums.ActionType) -> String:
    match action_type:
        GameEnums.ActionType.SECRET:
            return "暗置 1 张"
        GameEnums.ActionType.TRADEOFF:
            return "弃置 2 张"
        GameEnums.ActionType.GIFT:
            return "展示 3 张，对手拿 1 张"
        GameEnums.ActionType.COMPETITION:
            return "展示 4 张，分成两组"
    return "行动"

func _on_draw_button_pressed() -> void:
    if state.phase in [GameEnums.GamePhase.SETUP, GameEnums.GamePhase.ROUND_RESET]:
        _start_round()
    else:
        _draw_card()

func _set_status(message: String) -> void:
    if status_label:
        status_label.text = message

func _player_name(id: GameEnums.PlayerId) -> String:
    return "玩家 1" if id == PLAYER_ONE else "玩家 2"

func _refresh_ui() -> void:
    if not status_label:
        return
    draw_button.text = "开始回合" if state.phase in [GameEnums.GamePhase.SETUP, GameEnums.GamePhase.ROUND_RESET] else "抽牌"
    draw_button.disabled = state.phase not in [GameEnums.GamePhase.SETUP, GameEnums.GamePhase.ROUND_RESET, GameEnums.GamePhase.PLAYER_DRAW, GameEnums.GamePhase.ROUND_DEAL]
    for button in action_buttons:
        button.disabled = state.phase != GameEnums.GamePhase.PLAYER_CHOOSE_ACTION
    settle_button.disabled = state.phase != GameEnums.GamePhase.ROUND_SCORING
    var one: PlayerState = state.players.get(PLAYER_ONE)
    var two: PlayerState = state.players.get(PLAYER_TWO)
    player_one_label.text = "玩家1：手牌 %d｜艺伎 %d｜魅力 %d" % [one.hand_cards.size(), state.get_controlled_geisha_count(PLAYER_ONE), state.get_charm_score(PLAYER_ONE)]
    player_two_label.text = "玩家2：手牌 %d｜艺伎 %d｜魅力 %d" % [two.hand_cards.size(), state.get_controlled_geisha_count(PLAYER_TWO), state.get_charm_score(PLAYER_TWO)]
    var owners := []
    for geisha in state.geishas:
        owners.append("%s:%s" % [geisha.display_name, _owner_text(geisha.owner)])
    geisha_label.text = "艺伎归属：" + "  ".join(owners)

func _owner_text(owner: GameEnums.GeishaOwner) -> String:
    if owner == GameEnums.GeishaOwner.PLAYER_ONE:
        return "玩家1"
    if owner == GameEnums.GeishaOwner.PLAYER_TWO:
        return "玩家2"
    return "中立"
