extends CanvasLayer

@onready var _overlay: ColorRect = $CRTOverlay


func _ready() -> void:
	AlertSystem.combat_changed.connect(_on_combat_changed)
	_overlay.visible = not AlertSystem.combat_mode


func _on_combat_changed(in_combat: bool) -> void:
	_overlay.visible = not in_combat
