class_name StairStepping
extends RefCounted
## Lets a CharacterBody3D climb small ledges (curbs, rugs, low steps) as part
## of its normal walk instead of needing a jump. move_and_slide() treats any
## ledge taller than floor_max_angle allows as a vertical wall; this probes
## just ahead of the body and, if the obstruction is short enough and there is
## headroom to clear it, lifts the body onto it before move_and_slide() runs.
##
## Call once per physics frame, after velocity.x/z are set for the frame but
## before move_and_slide().

static func apply(body: CharacterBody3D, delta: float, max_step_height: float = 0.3) -> void:
	if body.velocity.y > 0.1:
		return
	var planar_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if planar_velocity.is_zero_approx():
		return
	if not body.is_on_floor():
		# A capsule can rise a few centimetres onto a tread's corner while the
		# contact normal is still too steep to count as floor. Allow stepping
		# only if a real, walkable surface remains immediately below its feet.
		var supported := false
		for forward: float in [0.0, 0.15, 0.3]:
			var feet := body.global_position + planar_velocity.normalized() * forward
			var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.05, feet - Vector3.UP * 0.2)
			ray.exclude = [body.get_rid()]
			var floor_hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
			if not floor_hit.is_empty() and (floor_hit.normal as Vector3).y >= cos(body.floor_max_angle):
				supported = true
				break
		if not supported:
			return
	var motion := planar_velocity * delta

	# If the flat path ahead is already clear, there is no step to climb.
	var flat_collision := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, motion, flat_collision):
		return

	# Is there room to lift the body up by max_step_height? A low ceiling or
	# overhang caps how far it can rise.
	var lift_collision := KinematicCollision3D.new()
	var lifted := max_step_height
	if body.test_move(body.global_transform, Vector3.UP * max_step_height, lift_collision):
		lifted = lift_collision.get_travel().y
		if lifted <= 0.001:
			return

	# From the lifted height, can the body now clear the obstruction? If it is
	# still blocked up here, it is a wall taller than max_step_height, not a step.
	var lifted_transform := body.global_transform
	lifted_transform.origin.y += lifted
	if body.test_move(lifted_transform, motion, KinematicCollision3D.new()):
		return

	# Measure how far down the stepped-up surface actually is, so the body
	# settles onto it instead of floating for a frame.
	var forward_transform := lifted_transform
	forward_transform.origin += motion
	var settle_collision := KinematicCollision3D.new()
	if body.test_move(forward_transform, Vector3.DOWN * lifted, settle_collision):
		var drop := settle_collision.get_travel().y
		body.global_position.y += lifted + drop
		# Edge contacts may not be marked as floor yet. Cancel accumulated
		# gravity after a supported step so move_and_slide does not undo it.
		body.velocity.y = 0.0
		body.apply_floor_snap()
