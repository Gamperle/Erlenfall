extends Node3D

@onready var _welcome_label: Label = $UI/WelcomeLabel


func _ready() -> void:
	_welcome_label.text = tr("UI_WELCOME")
