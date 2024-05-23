extends Node

@export var meshes: Array[MeshInstance3D] = []

var color: Color:
	get:
		return color
	set(value):
		# Set value then update the color of the children meshes
		color = value
		for m in meshes:
			var mat = m.get_surface_override_material(0)
			mat.albedo_color = color
			m.set_surface_override_material(0, mat)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
