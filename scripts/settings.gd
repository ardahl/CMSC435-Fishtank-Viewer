extends MenuButton

@export var fishtank: MeshInstance3D
@export var fps_box: ConfirmationDialog
@export var tank_walls: Node
@export var camera: Node

var _fps_input
var _refresh_rate

# Called when the node enters the scene tree for the first time.
func _ready():
	get_popup().id_pressed.connect(_on_id_pressed.bind())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_id_pressed(id: int):
	var popup = get_popup()
	var ind = popup.get_item_index(id)
	var option_str = popup.get_item_text(ind)
	print("Menu Pressed: ", option_str)
	if option_str == "FPS":
		print("Max fps: ", Engine.get_max_fps())
#		_fps_input.get_line_edit().set_text(str(Engine.get_max_fps()))
		_fps_input.set_value(Engine.get_max_fps())
		fps_box.popup()
	if option_str == "Color Out-Of-Bounds Fish":
		print("Toggling coloring out of bounds fish")
		var oob_bool = fishtank.toggle_oob_coloring()
		popup.set_item_checked(ind, oob_bool)
	if option_str == "Tank Walls":
		if popup.is_item_checked(ind): #is currently checked so uncheck
			tank_walls.hide()
			popup.set_item_checked(ind, false)
		else: #otherwise currenly unchecked so make checked
			tank_walls.show()
			popup.set_item_checked(ind, true)
	if option_str == "Lock Camera":
		if popup.is_item_checked(ind):
			camera.camera_locked = false
			popup.set_item_checked(ind, false)
		else:
			camera.camera_locked = true
			popup.set_item_checked(ind, true)


func _on_fps_input_text_submitted(new_text):
	var new_fps = int(new_text)
	print("Setting new fps to ", new_fps)
	Engine.set_max_fps(new_fps)
	fishtank.fps = new_fps
	fishtank._setup_timeline()


func _on_fps_box_confirmed():
	var new_fps = int(_fps_input.get_line_edit().get_text())
	print("Setting new fps to ", new_fps)
	Engine.set_max_fps(new_fps)
	fishtank.fps = new_fps
	fishtank._setup_timeline()


func _on_tank_ready():
	_fps_input = fps_box.get_node("FpsInput")
	_refresh_rate = ceil(DisplayServer.screen_get_refresh_rate())
#	_fps_input.get_line_edit().set_text(str(_refresh_rate))
	_fps_input.set_value(_refresh_rate)
	_fps_input.set_tooltip_text(str("Value must be between 1 and ", _refresh_rate, " (monitor refresh rate)"))
	_fps_input.get_line_edit().text_submitted.connect(_on_fps_input_text_submitted.bind())
