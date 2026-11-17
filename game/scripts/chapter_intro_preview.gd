extends SceneTree
## Replays the three real entry points without writing comic story progress.
func _initialize()->void:call_deferred("run")
func wait_card()->void:
	while root.get_node("ChapterTransition").active:await process_frame
	await process_frame
func close_lines(game:Node)->void:
	while not game.dialogue.is_empty():game.dialogue_panel.finish_typing();game.advance_dialogue()
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.get_window().title="带上她的眼睛 · 前三章开头预览"
	game.prologue.test_mode=true;game.ending_entry.preview_mode=true
	await process_frame;await process_frame
	game.title._start();await wait_card();await create_timer(1.25).timeout
	game.prologue._depart(true);await wait_card();await create_timer(1.25).timeout
	game.dialogue.clear();game.dialogue_panel.hide();game.morning.fast_mode=true;game._begin_morning()
	while game.morning.busy:await process_frame
	game.dialogue.clear();game.dialogue_panel.hide();await create_timer(1.25).timeout
	game._hear_morning_bird();close_lines(game);await wait_card()
	print("CHAPTER_DEMO_READY: three real chapter entries completed")
