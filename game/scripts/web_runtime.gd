extends Node
func _enter_tree()->void:
    var font=load("res://assets/web-fonts/MicrosoftYaHei.ttf")
    ThemeDB.fallback_font=font
    ThemeDB.get_default_theme().default_font=font
    ProjectSettings.set_setting("audio/general/default_playback_type",0)
func _ready()->void:
    get_tree().node_added.connect(_configure_audio)
func _configure_audio(node:Node)->void:
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        node.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
