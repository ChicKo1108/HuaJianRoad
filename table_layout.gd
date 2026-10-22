extends Control

const DESIGN_SIZE := Vector2(1536.0, 1024.0)

func _ready() -> void:
    get_viewport().size_changed.connect(_fit_board)
    call_deferred("_fit_board")

func _fit_board() -> void:
    var board := get_node_or_null("Board") as Control
    if board == null:
        return
    var viewport_size := get_viewport_rect().size
    var factor := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
    board.scale = Vector2.ONE * maxf(0.1, factor)
    board.position = (viewport_size - DESIGN_SIZE * factor) * 0.5
