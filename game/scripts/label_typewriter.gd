extends Node
## Reveals the actual editable label text; no copy of the dialogue is rendered.
const Pace=preload("res://scripts/reading_pace.gd")
var label:Label
var previous:=""
var elapsed:=0.0
func setup(value:Label)->void:label=value
func refresh()->void:
	if label==null:return
	if label.text!=previous:previous=label.text;elapsed=0;label.visible_characters=0
func typing()->bool:
	refresh();return label!=null and label.is_visible_in_tree() and label.visible_characters>=0 and label.visible_characters<label.text.length()
func finish()->bool:
	if not typing():return false
	label.visible_characters=-1;elapsed=float(label.text.length());return true
func _process(delta:float)->void:
	if label==null or not label.is_visible_in_tree():return
	var stage:=label.get_parent()
	if "paused" in stage and stage.paused:return
	refresh()
	if label.visible_characters<0:return
	elapsed+=delta*Pace.CHARACTERS_PER_SECOND
	label.visible_characters=mini(int(elapsed),label.text.length())
