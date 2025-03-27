extends Node2D

@onready var default_head_pos: Vector2 = %TopHead.position
var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var basketball_pos: Vector2 = get_tree().get_first_node_in_group(&'basketball').global_position
	var target_x: float = (basketball_pos - global_position).x
	target_x += get_tree().get_first_node_in_group(&'basketball').linear_velocity.x * 0.2
	
	#var x_vel: float = sign(target_x) * max(20.0, pow(abs(target_x), 2.0)*0.05)
	var x_vel: float = sign(target_x) * max(100.0, abs(target_x) * 2.8)
	if abs(target_x) <= 20.0:
		x_vel = 0.0
	velocity.x = x_vel
	%WalkAnimation.speed_scale = clamp(5.0 * -x_vel / 500.0, -5.0, 5.0)
	
	global_position += velocity * delta
	%TopHead.position = lerp(default_head_pos, %TopHead.to_local(basketball_pos), max(0.0, 1.0 - abs(basketball_pos.y - %Body.global_position.y) / 300.0))
	#%TopHead.global_position = basketball_pos
	%TopHead.global_position.x = min(%TopHead.global_position.x, %Body.global_position.x)
