extends CharacterBody3D

@export var speed := 7.0
@export var mouse_sensitivity := 0.0025
@export var gravity := 20.0
@onready var camera: Camera3D = $Camera3D
var movement_enabled := false


func _unhandled_input(event: InputEvent) -> void:
	if movement_enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity = Vector3.ZERO
		return
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(movement.x, 0.0, movement.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
