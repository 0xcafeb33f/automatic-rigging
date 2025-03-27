extends RigidBody2D

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() >= 1:
		state.linear_velocity = state.linear_velocity.normalized() * 500.0
