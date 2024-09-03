extends MeshInstance3D

#TODO: fix fish velocity parsing errors

@export var fps: int = 60
@export var fish: PackedScene
@export var food: PackedScene
@export var oob_color: Color

# Node references
var _file_dialog
var _text_file
var _loading_container
var _loading_bar
var _error_box
var _pause_button
var _curr_time_label
var _total_time_label
var _timeline
# Frame storage
var _fish = [[]]
var _food = [[]]
# Runtime variables
var _tank_paused = true
var _has_fish = false
var _loading = false
var _load_percentage = 0.0
var _current_time: float = 0.0
var _current_frame: int = 0
var _total_time: float = 0.0
var _total_frames: int = 0
var _load_mutex = Mutex.new()
var _thread = Thread.new()
var _tank_bounds = Vector3(0.5, 0.25, 0.125)
var _color_oob_fish = false


# Called when the node enters the scene tree for the first time.
func _ready():
	_file_dialog = get_node("../UserInterface/FileDialog")
	_file_dialog.hide()
	_text_file = get_node("../UserInterface/FileInput/SelectedFile")
	_text_file.set_text("")
	_loading_container = get_node("../UserInterface/LoadingBackground")
	_loading_bar = get_node("../UserInterface/LoadingBackground/LoadingContainer/ProgressBar")
	_loading_container.hide()
	_error_box = get_node("../UserInterface/ErrorDialog")
	_pause_button = get_node("../UserInterface/Timeline/PauseButton")
	_curr_time_label = get_node("../UserInterface/Timeline/TimelineContainer/CurrentTime")
	_total_time_label = get_node("../UserInterface/Timeline/TimelineContainer/TotalTime")
	_timeline = get_node("../UserInterface/Timeline/TimelineContainer/Slider")
	# set target fps
	Engine.set_max_fps(fps)


# Called every frame. 'delta' is the elapsed time since the previous frame.
# delta is in seconds
func _process(delta):
	if _loading:
		_load_mutex.lock()
		_loading_bar.set_value(_load_percentage)
		_load_mutex.unlock()
	if _has_fish:
		_clean_tank()
#		print("Fish: ", _fish[_current_frame].size(), "  Food: ", _food[_current_frame].size())
		_show_fish(_current_frame)
		_show_food(_current_frame)
		_update_timeline(_current_frame)
		if  not _tank_paused:
			_current_time += delta
			_current_frame += 1
			if _current_frame >= _total_frames:
				_current_time = 0
				_current_frame = 1


# Open File button pressed
func _on_open_file_pressed():
#	_tank_paused = true
	_pause_button.set_pressed(false)
	_file_dialog.show()


# File selected in file dialog
func _on_file_dialog_file_selected(path):
	_text_file.set_text(path)
	_file_dialog.hide()
	_load_file(path)
#	_tank_paused = false
	_pause_button.set_pressed(false)


# Load File button pressed
func _on_load_file_pressed():
	if not _text_file.get_text().is_empty():
		_load_file(_text_file.get_text())


# Pressing cancel on the file dialog
func _on_file_dialog_canceled():
#	_tank_paused = false
	_pause_button.set_pressed(true)


func _setup_timeline():
	_timeline.set_max(_total_frames)
	_timeline.set_value_no_signal(0)
	var time = float(_total_frames) / fps
	var total_string = "%.1f Sec\n%3d Frames" % [time, _total_frames]
	_total_time_label.set_text(total_string)
	_current_time = float(_current_frame) / fps


func _update_timeline(frame):
	_timeline.set_value_no_signal(frame)
#	var time = float(frame) / fps
	var total_string = "%.1f Sec\nFrame %03d" % [_current_time, frame]
	_curr_time_label.set_text(total_string)


func _clean_tank():
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _show_fish(frame):
	for f in _fish[frame]:
		# Spawn instance of fish
		var fish_inst = fish.instantiate()
		# Adjust cone length to z*10*sqrt(vel.norm())
		var curr = fish_inst.get_child(1).get_scale()
		var axis = f.velocity
		var speed_sq = axis.length_squared()
		var dir = f.position + Vector3(0, 0, 1)
		if speed_sq > 1e-4:
			var speed = sqrt(speed_sq)
			axis /= speed
			# Cone is the second node in the scene
			fish_inst.get_child(1).set_scale(Vector3(curr.x, curr.y, curr.z*10*sqrt(speed)))
			# Rotate to same direction as vel
			dir = f.position - axis
		# Move to position
		fish_inst.look_at_from_position(f.position, dir)
		fish_inst.color = f.color
		# If OOB coloring is on, check if out of bounds
		if _color_oob_fish:
			var pos_diff = f.position.abs() - _tank_bounds
			var inbounds = true
			for i in range(3):
				if pos_diff[i] > 0:
					inbounds = false
					break
			if not inbounds:
				fish_inst.color = oob_color
		add_child(fish_inst)


func _show_food(frame):
	for f in _food[frame]:
		# Spawn instance of food
		var food_inst = food.instantiate()
		# Move to position
#		print("Pos: ", f.position.x, ",", f.position.y, ",", f.position.z)
		food_inst.set_position(f.position)
		food_inst.color = f.color
		add_child(food_inst)


func _reset_tank():
	_current_time = 0.0
	_current_frame = 0
	_total_time = 0.0
	_total_frames = 0
	_has_fish = false
	_clean_tank()
	_fish = [[]]
	_food = [[]]
	_tank_paused = true
	_setup_timeline()
	_update_timeline(_current_frame)


func toggle_oob_coloring():
	_color_oob_fish = not _color_oob_fish
	print("Fish Color: ", str(_color_oob_fish))
	return _color_oob_fish


func _load_file(file):
	print("Loading ", file)
	# Clear out arrays incase fish already exist (reloading file)
	_reset_tank()
	_pause_button.set_pressed(false)
	_loading = true
	_loading_bar.set_max(100)
	_loading_bar.set_value(0)
	_loading_container.show()
	var err = _thread.start(_load_file_threadwork.bind(file))
	if err:
		push_error("Couldn't start file loading thread. Error code = %d" % [ err ])
		return
#		var _error = await self.file_load_finished


# Does all the actual loading in a thread so the loading bar can be updated
# returns an array of the form [Error, err_string]
func _load_file_threadwork(file) -> Array:
	var ecode = [OK, "OK"]
	# open file
	var f = FileAccess.open(file, FileAccess.READ)
	# first line of file is the number of frames
	var line = f.get_line().strip_edges()
	while line.length() == 0 or line[0] == '#':
		line = f.get_line().strip_edges()
		if f.eof_reached():
			var err_str = "No input for number of frames. Empty file"
			ecode = [ERR_FILE_EOF, err_str]
			break
	if ecode[0] != OK: #error out early
		call_deferred("_finish_load")
		return ecode
	var nframes = line.to_int()
	_total_frames = nframes
	for frame in range(nframes):
#		print("Frame ", frame, "/", nframes)
		var fish_array = []
		var food_array = []
		# get the number of fish for the current frame
		line = f.get_line().strip_edges()
		while line.length() == 0 or line[0] == '#':
			line = f.get_line().strip_edges()
			if f.eof_reached():
				var err_str = "Only able read in " + str(frame) + " of " + str(nframes) + " frames."
				ecode = [ERR_FILE_EOF, err_str]
				break
		var num_fish = line.to_int()
		for i in range(num_fish):
			line = f.get_line().strip_edges()
			while line.length() == 0 or line[0] == '#':
				line = f.get_line().strip_edges()
				if f.eof_reached():
					var err_str = "Only able to read in " + str(i) + " of " + str(num_fish) + " fish for frame " + str(frame) + "."
					ecode = [ERR_FILE_EOF, err_str]
					break
			var fish_string = line
			# Tried using regex to test for correctness as well, but was too complicated to be able 
			# to match all forms of decimal numbers and exponentials
			# Originally just replaced all the brackets and commas with spaces and used split_floats(" ", false)
			#	however, would like to not replace all instances to preserve extra output for user extensions
			# to this affect, get substrings of the position and velocity and parse only those
			var vec_start = fish_string.find("[")
			if vec_start == -1:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			vec_start += 1
			var vec_end = fish_string.find("]") 
			if vec_end == -1:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			vec_end -= vec_start
			var fish_pos_str = fish_string.substr(vec_start, vec_end)
			vec_start = fish_string.find("[", vec_start+1) 
			if vec_start == -1:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			vec_start += 1
			var end_pos = fish_string.find("]", vec_start)
			if end_pos == -1:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			vec_end = end_pos - vec_start
			var fish_vel_str = fish_string.substr(vec_start, vec_end)
			# To get the rest of the string if you're extending it, do var str = fish_string.substr(end_pos+1)
			#print("Fish Pos: ", fish_pos_str)
			#print("Fish Vel: ", fish_vel_str)
			#if end_pos+1 < fish_string.length():
				#print("Fish Remain: ", fish_string.substr(end_pos+1))
			fish_pos_str = fish_pos_str.replace(",", " ")
			fish_vel_str = fish_vel_str.replace(",", " ")
			var fish_pos_arr = fish_pos_str.split_floats(" ", false)
			var fish_vel_arr = fish_vel_str.split_floats(" ", false)
			# Do the error checking here, should be 6 floats total (3 pos and 3 vel)
			if fish_pos_arr.size() != 3 or fish_vel_arr.size() != 3:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			# If there is still content after pos and vel, attempt to parse as a color
			var fish_color = Color.GREEN
			if end_pos+1 < fish_string.length(): # if there is remaining text in the line
				var remain_str = fish_string.substr(end_pos+1).strip_edges() # get the rest of the line and strip whitespace off ends
				if remain_str.length() > 0:
					#check for [ and ]
					vec_start = remain_str.find("[")
					if vec_start != -1:
						vec_start += 1
						end_pos = remain_str.find("]", vec_start)
						if end_pos != -1:
							vec_end = end_pos - vec_start
							var fish_color_str = remain_str.substr(vec_start, vec_end)
							fish_color_str = fish_color_str.replace(",", " ")
							var fish_color_arr = fish_color_str.split_floats(" ", false)
							if fish_color_arr.size() == 3 and fish_color_arr[0] >= 0.0 and fish_color_arr[0] <= 1.0 and fish_color_arr[1] >= 0.0 and fish_color_arr[1] <= 1.0 and fish_color_arr[2] >= 0.0 and fish_color_arr[2] <= 1.0:
								fish_color = Color(fish_color_arr[0], fish_color_arr[1], fish_color_arr[2])
			var new_fish = Fish.new()
			new_fish.position = Vector3(fish_pos_arr[0], fish_pos_arr[1], fish_pos_arr[2])
			new_fish.velocity = Vector3(fish_vel_arr[0], fish_vel_arr[1], fish_vel_arr[2])
			new_fish.color = fish_color
			fish_array.push_back(new_fish)
		if ecode[0] != OK:
			break
		line = f.get_line().strip_edges()
		while line.length() == 0 or line[0] == '#':
			line = f.get_line().strip_edges()
			print(str(f.eof_reached()), ": ", line)
			if f.eof_reached():
				var err_str = "File ends before reading number of food for frame " + str(frame) + "."
				ecode = [ERR_FILE_EOF, err_str]
				break
		var num_food = line.to_int()
		for i in range(num_food):
			line = f.get_line().strip_edges()
			while line.length() == 0 or line[0] == '#':
				line = f.get_line().strip_edges()
				if f.eof_reached():
					var err_str = "Only able to read in " + str(i) + " of " + str(num_food) + " food for frame " + str(frame) + "."
					ecode = [ERR_FILE_EOF, err_str]
					break
			var food_string = line
			# Do the same thing for the food vector as the position
			var vec_start = food_string.find("[")
			if vec_start == -1:
				var err_str = "Invalid input: Food " + str(i) + " in frame " + str(frame) + ": " + food_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			vec_start += 1
			var end_pos = food_string.find("]")
			if end_pos == -1:
				var err_str = "Invalid input: Food " + str(i) + " in frame " + str(frame) + ": " + food_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			var vec_end = end_pos - vec_start
			var food_pos_str = food_string.substr(vec_start, vec_end)
			# Similarly, get the remaining output with var str = food_string.substr(end_pos+1)
			#if end_pos+1 < food_string.length():
				#print("Food Remain: ", food_string.substr(end_pos+1))
			food_pos_str = food_pos_str.replace(",", " ")
			var food_arr = food_pos_str.split_floats(" ", false)
			if food_arr.size() != 3:
				var err_str = "Invalid input: Food " + str(i) + " in frame " + str(frame) + ": " + food_string
				ecode = [ERR_INVALID_DATA, err_str]
				break
			var food_color = Color.BLUE
			if end_pos+1 < food_string.length(): # if there is remaining text in the line
				var remain_str = food_string.substr(end_pos+1).strip_edges() # get the rest of the line and strip whitespace off ends
				if remain_str.length() > 0:
					#check for [ and ]
					vec_start = remain_str.find("[")
					if vec_start != -1:
						vec_start += 1
						end_pos = remain_str.find("]", vec_start)
						if end_pos != -1:
							vec_end = end_pos - vec_start
							var food_color_str = remain_str.substr(vec_start, vec_end)
							food_color_str = food_color_str.replace(",", " ")
							var food_color_arr = food_color_str.split_floats(" ", false)
							if food_color_arr.size() == 3 and food_color_arr[0] >= 0.0 and food_color_arr[0] <= 1.0 and food_color_arr[1] >= 0.0 and food_color_arr[1] <= 1.0 and food_color_arr[2] >= 0.0 and food_color_arr[2] <= 1.0:
								food_color = Color(food_color_arr[0], food_color_arr[1], food_color_arr[2])
			var new_food = Food.new()
			new_food.position = Vector3(food_arr[0], food_arr[1], food_arr[2])
			new_food.color = food_color
			food_array.push_back(new_food)
		if ecode[0] != OK:
			break
		_fish.push_back(fish_array)
		_food.push_back(food_array)
#		var timer = get_tree().create_timer(0.01)
#		while(timer.time_left > 1.0e-8):
#			continue
		_load_mutex.lock()
		_load_percentage = 100 * (frame / float(nframes))
		_load_mutex.unlock()
	call_deferred("_finish_load")
	return ecode


func _finish_load():
	var _error = _thread.wait_to_finish()
	if _error[0]:
		_error_box.set_text(_error[1] + "\nError Code = " + str(_error[0]))
		_error_box.show()
		_reset_tank()
		pass
	else:
		_setup_timeline()
		_current_frame = 1
		_current_time = 0
		_loading_container.hide()
		_tank_paused = false
		_has_fish = true
		_pause_button.set_pressed(true)
		_loading = false


func _pause_tank():
	_pause_button.set_pressed(false)


func _on_pause_button_toggled(button_pressed):
	if(_has_fish):
		print("Play status: ", button_pressed)
		_tank_paused = not button_pressed
	else:
		_pause_button.set_pressed_no_signal(false)


func _on_slider_value_changed(value):
	_pause_tank()
	_current_frame = value
	_current_time = float(_current_frame) / fps


func _on_skip_first_pressed():
	_current_frame = 1
	_current_time = 0.0
	_pause_tank()


func _on_skip_last_pressed():
	_current_frame = _total_frames
	_current_time = _total_time
	_pause_tank()


func _on_step_back_pressed():
	if _current_frame > 1:
		_current_frame -= 1
		_current_time -= 1.0 / fps
		_pause_tank()


func _on_step_forward_pressed():
	if _current_frame < _total_frames:
		_current_frame += 1
		_current_time += 1.0 / fps
		_pause_tank()


# Do the same for both hitting OK and the close button
func _on_error_dialog_confirmed():
	_loading_container.hide()


func _on_error_dialog_canceled():
	_loading_container.hide()


class Fish:
	var position: Vector3 = Vector3.ZERO:
		set(new_position):
			position = new_position
		get:
			return position
	var velocity: Vector3 = Vector3.ZERO:
		set(new_velocity):
			velocity = new_velocity
		get:
			return velocity
	var color: Color = Color.GREEN:
		set(new_color):
			color = new_color
		get:
			return color
	
	func _to_string():
		return "Position: " + str(position) + ", Velocity: " + str(velocity)


class Food:
	var position: Vector3 = Vector3.ZERO:
		set(new_position):
			position = new_position
		get:
			return position
	var color: Color = Color.BLUE:
		set(new_color):
			color = new_color
		get:
			return color
	
	func _to_string():
		return "Position: " + str(position)
