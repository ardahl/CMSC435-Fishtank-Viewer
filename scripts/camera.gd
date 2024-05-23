extends Node3D

@export var camera: Camera3D
@export var min_distance: float = 0.5
@export var max_distance: float = 2.5
@export var rotation_sensitivity: float = 0.001
@export var zoom_sensitivity: float = 0.01

#var orientation: Quaternion
#var distance: float
var camera_locked: bool = true

var _step_zoom: float = 1
var _mouse_pos: Vector2 = Vector2()
var _rot_x: float = 0
var _rot_y: float = 0
var _cur_scale: Vector3 = Vector3.ONE

# Called when the node enters the scene tree for the first time.
func _ready():
	#orientation = Quaternion()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not camera_locked:
		transform = transform.orthonormalized()
		_process_camera()
	_step_zoom = 1
	_mouse_pos = Vector2()


func _input(event):
	if not camera_locked:
		if event.is_action_pressed("Zoom In"):
			_step_zoom -= zoom_sensitivity
			print(_step_zoom)
		elif event.is_action_pressed("Zoom Out"):
			_step_zoom += zoom_sensitivity
			print(_step_zoom)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_mouse_pos += event.relative


func _process_camera():
	_mouse_pos *= rotation_sensitivity
	var yaw = _mouse_pos.x
	var pitch = _mouse_pos.y
	_rot_x -= yaw	# subtracting since we want to rotate the object in the opposite direction as the mouse movement
	_rot_y -= pitch
	transform.basis = Basis()
	rotate_object_local(Vector3(0, 1, 0), _rot_x) # first rotate in Y
	rotate_object_local(Vector3(1, 0, 0), _rot_y) # then rotate in X
	_cur_scale *= _step_zoom
	_cur_scale = clamp(_cur_scale, Vector3(min_distance, min_distance, min_distance), Vector3(max_distance, max_distance, max_distance))
	transform = transform.scaled(_cur_scale)
