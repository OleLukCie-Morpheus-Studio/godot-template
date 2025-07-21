extends Control
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var op:String="res://op.tscn"

func _ready() -> void:
	_playAnim("logo1")


func _playAnim(strs:String):
	animation_player.play(strs)

func _on_animation_finished()->void:
	get_tree().change_scene_to_file(op)
	#get_tree().change_scene_to_file()
	#get_tree().change_scren_to_packed()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		if animation_player.is_playing():
			var anim_length=animation_player.current_animation_length
			animation_player.seek(anim_length)
