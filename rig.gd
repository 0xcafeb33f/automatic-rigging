@tool
extends EditorScript

const alpha_threshold: float = 0.10
const edge_distance: float = 2000.0

func get_sprite(scene: Node) -> Sprite2D:
	if scene is Sprite2D:
		return scene as Sprite2D
	for child: Node in scene.get_children():
		var sprite: Sprite2D = get_sprite(child)
		if sprite != null:
			return sprite
	return null

func get_skeleton(scene: Node) -> Skeleton2D:
	if scene is Skeleton2D:
		return scene as Skeleton2D
	for child: Node in scene.get_children():
		var skeleton: Skeleton2D = get_skeleton(child)
		if skeleton != null:
			return skeleton
	return null

func get_all_bones(parent: Node) -> Array[Bone2D]:
	var all_bones: Array[Bone2D] = []
	if parent is Bone2D:
		all_bones.append(parent)
	for child: Node in parent.get_children():
		all_bones.append_array(get_all_bones(child))
	return all_bones

func filter_text(s: String) -> String:
	var buf: PackedByteArray = s.to_ascii_buffer()
	var i: int = 0
	for b in buf:
		if not ((b >= 97 and b <= 122) or (b >= 65 and b <= 90)):
			buf.remove_at(i)
		else:
			i += 1
	return buf.get_string_from_ascii()

func average_angle(angle1: float, angle2: float) -> float:
	while abs(angle1 - angle2) > PI:
		if abs(angle1) < abs(angle2):
			angle2 += 2*PI * sign(angle1 - angle2)
		else:
			angle1 += 2*PI * sign(angle2 - angle1)
	return (angle1 + angle2) / 2.0

func is_angle_greater(angle1: float, angle2: float) -> bool:
	while abs(angle1 - angle2) > PI:
		if abs(angle1) < abs(angle2):
			angle2 += 2*PI * sign(angle1 - angle2)
		else:
			angle1 += 2*PI * sign(angle2 - angle1)
	return angle1 > angle2

func get_polygon(image: Image) -> PackedVector2Array:
	var edges: PackedVector2Array = PackedVector2Array()
	var next_pixel: Vector2i = Vector2i(-1, -1)
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var p: Color = image.get_pixel(x, y)
			if p.a > alpha_threshold:
				next_pixel = Vector2i(x, y)
				break
		if next_pixel != Vector2i(-1, -1):
			break
	
	var found_origin: bool = false
	while not found_origin:
		edges.append(next_pixel)
		
		var found_next: bool = false
		var search_distance: int = 1
		while not found_origin and not found_next:
			for y in range(max(0, int(next_pixel.y)-search_distance), min(image.get_height(), int(next_pixel.y)+search_distance+1)):
				for x in range(max(0, int(next_pixel.x)-search_distance), min(image.get_width(), int(next_pixel.x)+search_distance+1)):
					var test_pixel: Vector2i = Vector2i(x, y)
					if Vector2(test_pixel) == edges[0]:
						found_origin = true
					if edges.has(test_pixel):
						continue
					if image.get_pixelv(test_pixel).a <= alpha_threshold:
						continue
					var on_edge: bool = false
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if abs(dx) == abs(dy):
								continue
							if x+dx<0 or x+dx>=image.get_width():
								continue
							if y+dy<0 or y+dy>=image.get_height():
								continue
							if image.get_pixel(x+dx, y+dy).a <= alpha_threshold:
								on_edge = true
								break
						if on_edge:
							break
					if not on_edge:
						continue
					found_origin = false
					found_next = true
					next_pixel = test_pixel
					break
				if found_next:
					break
			search_distance += 1
	
	if not Geometry2D.is_polygon_clockwise(edges):
		edges.reverse()
	return edges

func get_error(start: Vector2, end: Vector2, intermediate: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(0, len(intermediate)):
		var dist: float = Geometry2D.get_closest_point_to_segment(intermediate[i], start, end).distance_to(intermediate[i])
		if dist > 0.9:
			total += pow(dist, 2.0)
	return total

func prune_polygon(polygon_points: PackedVector2Array, threshold_error: float = 5.0) -> PackedVector2Array:
	if len(polygon_points) <= 2:
		return polygon_points
	var new_points: PackedVector2Array = PackedVector2Array()
	var start: Vector2 = polygon_points[0]
	var start_i: int = 0
	new_points.append(start)
	var i: int = 1
	while i < len(polygon_points):
		var end: Vector2 = polygon_points[i]
		var error: float = get_error(start, end, polygon_points.slice(start_i, i))
		if error > threshold_error:
			if start_i < i - 1:
				i -= 1
				end = polygon_points[i]
			new_points.append(end)
			start = end
			start_i = i
		i += 1
	if get_error(polygon_points[0], start, polygon_points.slice(start_i, len(polygon_points))) > threshold_error:
		new_points.append(polygon_points[-1])
	return new_points

func clear_intersections(polygon_points: PackedVector2Array) -> PackedVector2Array:
	var i: int = 0
	while i < len(polygon_points):
		var j: int = i + 1
		while j < len(polygon_points):
			var intersect = Geometry2D.segment_intersects_segment(polygon_points[i - 1], polygon_points[i], polygon_points[j - 1], polygon_points[j])
			if intersect != null and not polygon_points[i].is_equal_approx(intersect):
				polygon_points.remove_at(j - 1)
				j -= 1
			j += 1
		i += 1
	return polygon_points

func expand_polygon(polygon_points: PackedVector2Array, amount: float = 5.0) -> PackedVector2Array:
	if len(polygon_points) <= 2:
		return polygon_points
	var new_points: PackedVector2Array = PackedVector2Array()
	new_points = Geometry2D.offset_polygon(polygon_points, amount)[0]
	return new_points

func get_polygon_area(polygon_points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(0, len(polygon_points)):
		total += polygon_points[i].y * polygon_points[i-1].x - polygon_points[i].x * polygon_points[i-1].y
	return (-total / 2.0)

func get_polygon_perimeter(polygon_points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(0, len(polygon_points)):
		total += polygon_points[i].distance_to(polygon_points[i - 1])
	return total

func get_polygon_thickness(polygon_points: PackedVector2Array) -> float:
	return get_polygon_area(polygon_points) / get_polygon_perimeter(polygon_points)

func has_bone_child(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Bone2D:
			return true
		if has_bone_child(child):
			return true
	return false

func get_trim_polygon(bone: Bone2D, bone_name: String, bone_image: Image, sprite: Sprite2D) -> PackedVector2Array:
	var trim_polygon: PackedVector2Array = PackedVector2Array()
	
	var top_center: Vector2 = Vector2.ZERO
	var top_angle: float = NAN
	if (bone.get_parent() is Bone2D and
		bone_name.to_lower() == filter_text(bone.get_parent().name.to_lower())):
		var top_bone: Bone2D = bone.get_parent()
		top_center = bone.global_position
		top_angle = average_angle(top_bone.get_bone_angle(), bone.get_bone_angle())
	
	var bottom_center: Vector2 = Vector2.ZERO
	var bottom_angle: float = NAN
	for child: Node in bone.get_children():
		if (child is Bone2D and
			bone_name.to_lower() == filter_text(child.name.to_lower())):
			var bottom_bone: Bone2D = child
			bottom_center = bottom_bone.global_position
			bottom_angle = average_angle(bottom_bone.get_bone_angle(), bone.get_bone_angle())
			break
	
	if not is_nan(top_angle) or not is_nan(bottom_angle):
		if not is_nan(top_angle) and not is_nan(bottom_angle):
			var top_left: Vector2 = Vector2.RIGHT.rotated(top_angle).orthogonal()*edge_distance+top_center
			var top_right: Vector2 = -Vector2.RIGHT.rotated(top_angle).orthogonal()*edge_distance+top_center
			while abs(top_angle - bottom_angle) > PI/2.0:
				if top_angle > bottom_angle:
					bottom_angle += PI
				else:
					bottom_angle -= PI
			
			var bottom_left: Vector2 = Vector2.RIGHT.rotated(bottom_angle).orthogonal()*edge_distance+bottom_center
			var bottom_right: Vector2 = -Vector2.RIGHT.rotated(bottom_angle).orthogonal()*edge_distance+bottom_center
			var left_intersection = Geometry2D.segment_intersects_segment(top_center, top_left, bottom_center, bottom_left)
			var right_intersection = Geometry2D.segment_intersects_segment(top_center, top_right, bottom_center, bottom_right)
			if left_intersection != null and right_intersection != null: # Shouldn't be possible?
				trim_polygon = PackedVector2Array([left_intersection, top_center, right_intersection, bottom_center])
			elif left_intersection != null:
				trim_polygon = PackedVector2Array([left_intersection, top_center, top_right, bottom_right, bottom_center])
			elif right_intersection != null:
				trim_polygon = PackedVector2Array([top_left, top_center, right_intersection, bottom_center, bottom_left])
			else:
				trim_polygon = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
		elif not is_nan(top_angle):
			var top_left: Vector2 = Vector2.RIGHT.rotated(top_angle).orthogonal()*edge_distance+top_center
			var top_right: Vector2 = -Vector2.RIGHT.rotated(top_angle).orthogonal()*edge_distance+top_center
			var bottom_left: Vector2 = Vector2.RIGHT.rotated(top_angle)*edge_distance+top_left
			var bottom_right: Vector2 = Vector2.RIGHT.rotated(top_angle)*edge_distance+top_right
			trim_polygon = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
		elif not is_nan(bottom_angle):
			var bottom_left: Vector2 = Vector2.RIGHT.rotated(bottom_angle).orthogonal()*edge_distance+bottom_center
			var bottom_right: Vector2 = -Vector2.RIGHT.rotated(bottom_angle).orthogonal()*edge_distance+bottom_center
			var top_left: Vector2 = -Vector2.RIGHT.rotated(bottom_angle)*edge_distance+bottom_left
			var top_right: Vector2 = -Vector2.RIGHT.rotated(bottom_angle)*edge_distance+bottom_right
			trim_polygon = PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
		trim_polygon = to_sprite_coords(trim_polygon, sprite, bone_image)
	
	return trim_polygon

func to_sprite_coord(point: Vector2, sprite: Sprite2D, bone_image: Image) -> Vector2:
	return (Transform2D(0.0,
		Vector2(bone_image.get_width()/2.0-0.5, bone_image.get_height()/2.0-0.5)) *
		sprite.global_transform.affine_inverse() * point)

func to_sprite_coords(points: PackedVector2Array, sprite: Sprite2D, bone_image: Image) -> PackedVector2Array:
	return (Transform2D(0.0,
		Vector2(bone_image.get_width()/2.0-0.5, bone_image.get_height()/2.0-0.5)) *
		sprite.global_transform.affine_inverse() * points)

func from_sprite_coord(point: Vector2, sprite: Sprite2D, bone_image: Image, dest: Node = null) -> Vector2:
	return (sprite.global_transform * # TODO add sprite offset
			((dest.global_transform.affine_inverse() if dest != null else Transform2D.IDENTITY) *
			(Transform2D(0.0,
			Vector2(-bone_image.get_width()/2.0+0.5, -bone_image.get_height()/2.0+0.5)) *
			point)))

func from_sprite_coords(points: PackedVector2Array, sprite: Sprite2D, bone_image: Image, dest: Node = null) -> PackedVector2Array:
	return (sprite.global_transform * # TODO add sprite offset
			((dest.global_transform.affine_inverse() if dest != null else Transform2D.IDENTITY) *
			(Transform2D(0.0,
			Vector2(-bone_image.get_width()/2.0+0.5, -bone_image.get_height()/2.0+0.5)) *
			points)))

func get_point_on_polygon(start: Vector2, end: Vector2, polygon_points: PackedVector2Array) -> Vector2:
	var best_point: Vector2 = Vector2.RIGHT*edge_distance
	for i in range(0, len(polygon_points)):
		var intersect = Geometry2D.segment_intersects_segment(start, end, polygon_points[i-1], polygon_points[i])
		if intersect != null:
			if start.distance_squared_to(intersect) < start.distance_squared_to(best_point):
				best_point = intersect
	return best_point

func add_point_to_polygon(point: Vector2, polygon_points: PackedVector2Array) -> PackedVector2Array:
	var i: int = 0
	while i < len(polygon_points):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, polygon_points[i - 1], polygon_points[i])
		if point.is_equal_approx(closest):
			polygon_points.insert(i, point)
			return polygon_points
		i += 1
	return polygon_points

func get_joint_direction(internal_point: Vector2, polygon_points: PackedVector2Array) -> float:
	var shortest_length: float = INF
	var best_angle: float = 0.0
	var best_vector: Vector2 = Vector2.ZERO
	for angle_deg: int in range(0, 360):
		var angle: float = deg_to_rad(angle_deg)
		var start: Vector2 = Vector2.RIGHT.rotated(angle)*edge_distance+internal_point
		var end: Vector2 = -Vector2.RIGHT.rotated(angle)*edge_distance+internal_point
		var intersected_lines: Array[PackedVector2Array] = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([start, end]), polygon_points)
		if len(intersected_lines) == 0:
			continue
		var intersected_line: PackedVector2Array = intersected_lines[0]
		var length: float = intersected_line[0].distance_squared_to(intersected_line[1])
		if length < shortest_length:
			shortest_length = length
			best_vector = Vector2.RIGHT.rotated(angle)
			best_angle = angle
	return best_angle

func get_points_between(point1: Vector2, point2: Vector2, all_points: PackedVector2Array, include_ends: bool = false) -> Array[int]:
	var p1_idx: int = all_points.find(point1)
	var p2_idx: int = all_points.find(point2)
	if p1_idx == -1 or p2_idx == -1:
		print('Error: point not found in list!')
		return []
	
	var start_idx: int = min(p1_idx, p2_idx)
	var end_idx: int = max(p1_idx, p2_idx)
	
	var out: Array[int] = []
	
	var remove_outer: bool = (start_idx + len(all_points) - end_idx) < (end_idx - start_idx)
	if remove_outer:
		for i in range(0, len(all_points)):
			if i < start_idx or i > end_idx:
				out.append(i)
			if include_ends and (i == start_idx or i == end_idx):
				out.append(i)
	else:
		if include_ends:
			for i in range(start_idx, end_idx+1):
				out.append(i)
		else:
			for i in range(start_idx+1, end_idx):
				out.append(i)
	return out

func find_approx(point: Vector2, array: PackedVector2Array) -> int:
	for i in range(0, len(array)):
		if point.is_equal_approx(array[i]):
			return i
	return -1

func _run() -> void:
	var sprite_path: String = "res://assets/"
	var sprite_extension: String = "png"
	
	const polygon_name: String = 'Polygons'
	const physics_name: String = 'Body'
	const target_name: String = 'Target'
	const update_modifications: bool = true
	const joint_angle: float = deg_to_rad(30.0)
	
	
	
	if not sprite_path.ends_with('/'):
		sprite_path = sprite_path + '/'
	if not sprite_extension.begins_with('.'):
		sprite_extension = '.' + sprite_extension.to_lower()
	
	var scene: Node = get_scene()
	var skeleton: Skeleton2D = get_skeleton(scene)
	
	if skeleton == null:
		print('Error: Missing skeleton')
		return
	var sprite: Sprite2D = get_sprite(scene)
	if sprite == null:
		print('Error: Missing sprite')
		return
	var all_bones: Array[Bone2D] = get_all_bones(skeleton)
	
	var all_sprites: Dictionary = {}
	
	for filename in DirAccess.open(sprite_path).get_files():
		if filename.to_lower().ends_with(sprite_extension):
			all_sprites[filename.to_lower().split('.')[0]] = load(sprite_path + filename)
	
	var parent: Node = skeleton.get_parent()
	if parent == null or parent.has_node(polygon_name) or parent.has_node(physics_name):
		print('Error: Tree already has resulting nodes, or is missing parent')
		return
	
	var polygon_parent: Node2D = Node2D.new()
	polygon_parent.name = polygon_name
	parent.add_child(polygon_parent)
	polygon_parent.owner = scene
	
	var physics_parent: StaticBody2D = StaticBody2D.new()
	physics_parent.name = physics_name
	parent.add_child(physics_parent)
	physics_parent.owner = scene
	
	var target_parent: Node2D
	if parent.has_node(target_name):
		target_parent = parent.get_node(target_name)
	else:
		if update_modifications:
			target_parent = Node2D.new()
			target_parent.name = target_name
			parent.add_child(target_parent)
			target_parent.owner = scene
	
	var modifications: SkeletonModificationStack2D = null
	if update_modifications:
		modifications = SkeletonModificationStack2D.new()
		skeleton.set_modification_stack(modifications)
	else:
		modifications = skeleton.get_modification_stack()
	
	var partial_bones: Dictionary = {}
	for bone: Bone2D in all_bones:
		var bone_name: String = filter_text(bone.name)
		if not all_sprites.keys().has(bone_name.to_lower()):
			continue
		var partial_bone: bool = filter_text(bone.name) != bone.name
		var bone_sprite: CompressedTexture2D = all_sprites[bone_name.to_lower()]
		var bone_image: Image = bone_sprite.get_image()
		
		var has_partial_parent: bool = false
		
		# Tasks:
		# 1. Get border of bone_sprite
		var polygon_points: PackedVector2Array = get_polygon(bone_image)
		var accuracy_threshold: float = get_polygon_thickness(polygon_points) * get_polygon_area(polygon_points) / 10000
		
		# 2. If partial_bone, then trim to length of bone
		var trim_polygon: PackedVector2Array = PackedVector2Array()
		if partial_bone:
			if (bone.get_parent() is Bone2D and
				bone_name.to_lower() == filter_text(bone.get_parent().name.to_lower())):
				has_partial_parent = true
			
			trim_polygon = get_trim_polygon(bone, bone_name, bone_image, sprite)
			var new_polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon_points, trim_polygon)
			if len(new_polygons) >= 1: # Should always be true
				polygon_points = new_polygons[0]
		
		# 3. Selectively remove points to minimize error
		polygon_points = prune_polygon(polygon_points, accuracy_threshold)
		
		# 4. Transform and set as points of new CollisionPolygon2D
		var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
		collision_polygon.name = bone.name
		physics_parent.add_child(collision_polygon)
		collision_polygon.polygon = from_sprite_coords(polygon_points, sprite, bone_image, collision_polygon)
		collision_polygon.owner = scene
		
		# 5. Set up RemoteTransform2D pointing at CollisionPolygon2D
		var remote_transform: RemoteTransform2D = RemoteTransform2D.new()
		remote_transform.name = 'Transform' + bone.name
		bone.add_child(remote_transform)
		remote_transform.global_position = skeleton.global_position
		remote_transform.owner = scene
		remote_transform.remote_path = remote_transform.get_path_to(collision_polygon)
		
		var sprite_points: PackedVector2Array = expand_polygon(polygon_points)
		if not partial_bone:
			# 6. Transform polygon, and set as points of new Polygon2D node (with bone_sprite as sprite)
			var polygon: Polygon2D = Polygon2D.new()
			polygon.name = bone.name
			polygon_parent.add_child(polygon)
			polygon.owner = scene
			polygon.texture = bone_sprite
			polygon.texture_offset = -sprite.position+Vector2(bone_image.get_width()/2, bone_image.get_height()/2)
			polygon.polygon = from_sprite_coords(sprite_points, sprite, bone_image, polygon)
			polygon.uv = polygon.polygon
			polygon.skeleton = polygon.get_path_to(skeleton)
			polygon.clear_bones()
			# 7. Set all weights to 1 with a single polygon
			for i in range(0, skeleton.get_bone_count()):
				var i_bone: Bone2D = skeleton.get_bone(i)
				var i_bone_path: NodePath = skeleton.get_path_to(i_bone)
				var weights: PackedFloat32Array = PackedFloat32Array()
				weights.resize(len(polygon.polygon))
				if i_bone == bone:
					weights.fill(1.0)
				else:
					weights.fill(0.0)
				polygon.add_bone(i_bone_path, weights)
		elif partial_bone:
			var new_polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(trim_polygon, sprite_points)
			if len(new_polygons) >= 1: # Should always be true
				sprite_points = new_polygons[0]
			# 6. Record all points and Bone2D node in dictionary
			if not partial_bones.has(bone_name):
				partial_bones[bone_name] = []
			partial_bones[bone_name].append({
				'node': bone,
				'points': sprite_points,
				'has_partial_parent': has_partial_parent,
				'trim_polygon': trim_polygon
			})
			
	
	print('Next: Partial bones')
	for bone_name: String in partial_bones.keys():
		var bone_sprite: CompressedTexture2D = all_sprites[bone_name.to_lower()]
		var bone_image: Image = bone_sprite.get_image()
		
		var all_points: PackedVector2Array = PackedVector2Array()
		
		# 9. Combine all points into one polygon
		var polygon_points: PackedVector2Array = get_polygon(bone_image)
		var accuracy_threshold: float = get_polygon_thickness(polygon_points) * get_polygon_area(polygon_points) / 10000
		polygon_points = expand_polygon(prune_polygon(polygon_points, accuracy_threshold))
		
		# add points to joints
		for data: Dictionary in partial_bones[bone_name]:
			var bone: Bone2D = data['node']
			var has_partial_parent: bool = data['has_partial_parent']
			if has_partial_parent:
				var point: Vector2 = to_sprite_coord(bone.global_position, sprite, bone_image)
				
				var joint_direction: float = average_angle(bone.get_bone_angle(), bone.get_parent().get_bone_angle()) + PI/2
				var top_right: Vector2 = get_point_on_polygon(point, point + Vector2.RIGHT.rotated(joint_direction - joint_angle) * edge_distance, polygon_points)
				var bottom_right: Vector2 = get_point_on_polygon(point, point + Vector2.RIGHT.rotated(joint_direction + joint_angle) * edge_distance, polygon_points)
				var bottom_left: Vector2 = get_point_on_polygon(point, point + Vector2.LEFT.rotated(joint_direction - joint_angle) * edge_distance, polygon_points)
				var top_left: Vector2 = get_point_on_polygon(point, point + Vector2.LEFT.rotated(joint_direction + joint_angle) * edge_distance, polygon_points)
				polygon_points = add_point_to_polygon(top_right, polygon_points)
				polygon_points = add_point_to_polygon(bottom_right, polygon_points)
				polygon_points = add_point_to_polygon(bottom_left, polygon_points)
				polygon_points = add_point_to_polygon(top_left, polygon_points)
				
				
				var to_remove: Array[int] = []
				to_remove.append_array(get_points_between(top_left, bottom_left, polygon_points))
				
				var right_points: Array = []
				to_remove.append_array(get_points_between(top_right, bottom_right, polygon_points))
				
				
				to_remove.sort()
				to_remove.reverse()
				for i in to_remove:
					polygon_points.remove_at(i)
				
				data['top_right'] = top_right
				data['bottom_right'] = bottom_right
				data['bottom_left'] = bottom_left
				data['top_left'] = top_left
		
		# 10. Add internal points near joints
		var internal_points: PackedVector2Array = PackedVector2Array()
		# 11. Break points down into internal polygons
		var polygons: Array[PackedInt32Array] = []
		
		var all_joints: Array = []
		for data: Dictionary in partial_bones[bone_name]:
			var bone: Bone2D = data['node']
			var points: PackedVector2Array = data['points']
			var has_partial_parent: bool = data['has_partial_parent']
			var trim_polygon: PackedVector2Array = data['trim_polygon']
			if has_partial_parent:
				var point: Vector2 = to_sprite_coord(bone.global_position, sprite, bone_image)
				internal_points.append(point)
				
				var local_points: Array = Array(polygon_points)
				local_points.sort_custom(func(a, b): return point.distance_squared_to(a) < point.distance_squared_to(b))
				var joint_points: Array = []
				
				var quadrants: Array = []
				var joint_direction: float = average_angle(bone.get_bone_angle(), bone.get_parent().get_bone_angle()) + PI/2
				
				var top_right: Vector2 = data['top_right']
				var bottom_right: Vector2 = data['bottom_right']
				var bottom_left: Vector2 = data['bottom_left']
				var top_left: Vector2 = data['top_left']
				
				var left_points: Array = []
				left_points = get_points_between(top_left, bottom_left, polygon_points, true).map(func(i: int): return polygon_points[i])
				
				var right_points: Array = []
				right_points = get_points_between(top_right, bottom_right, polygon_points, true).map(func(i: int): return polygon_points[i])
				
				joint_points.append_array(left_points)
				joint_points.append_array(right_points)
				joint_points.sort_custom(func(a, b): return (a - point).angle() > (b - point).angle())
				all_joints.append(joint_points)
				
				left_points = left_points.map(func(x): return polygon_points.find(x))
				right_points = right_points.map(func(x): return polygon_points.find(x))
				for local_joint_points in [
					[polygon_points.find(top_left), polygon_points.find(top_right)],
					left_points,
					[polygon_points.find(bottom_left), polygon_points.find(bottom_right)],
					right_points
				]:
					var local_polygon: PackedInt32Array = PackedInt32Array()
					local_polygon.append(internal_points.find(point) + len(polygon_points))
					local_polygon.append_array(local_joint_points)
					polygons.append(local_polygon)
		
		var bone_polygons: Array = [polygon_points]
		
		for joint: PackedVector2Array in all_joints:
			var new_polygons: Array = []
			for bone_polygon: PackedVector2Array in bone_polygons:
				new_polygons.append_array(Geometry2D.clip_polygons(bone_polygon, joint))
			bone_polygons = new_polygons
		
		var bone_polygon_owners: Array[Bone2D] = []
		
		for bone_polygon: PackedVector2Array in bone_polygons:
			var centroid: Vector2 = Vector2.ZERO
			for i in range(0, len(bone_polygon)):
				centroid += bone_polygon[i]
			centroid /= len(bone_polygon)
			
			var min_dist: float = INF
			var bone_owner: Bone2D = null
			
			for data: Dictionary in partial_bones[bone_name]:
				var bone: Bone2D = data['node']
				var bone_start: Vector2 = bone.global_position
				var bone_end: Vector2 = bone_start + Vector2.RIGHT.rotated(bone.get_bone_angle()) * bone.get_length()
				bone_start = to_sprite_coord(bone_start, sprite, bone_image)
				bone_end = to_sprite_coord(bone_end, sprite, bone_image)
				var bone_center: Vector2 = (bone_start + bone_end) / 2.0
				var dist: float = centroid.distance_squared_to(bone_center)
				if dist < min_dist:
					min_dist = dist
					bone_owner = bone
			
			bone_polygon_owners.append(bone_owner)
			
			polygons.append(PackedInt32Array(Array(bone_polygon).map(func(x): return find_approx(x, polygon_points))))
		
		all_points.append_array(polygon_points)
		all_points.append_array(internal_points)
		
		# 12. Set up weights based on proximity to each bone
		var weights: Dictionary = {}
		for data: Dictionary in partial_bones[bone_name]:
			var bone: Bone2D = data['node']
			var points: PackedVector2Array = data['points']
			var has_partial_parent: bool = data['has_partial_parent']
			var trim_polygon: PackedVector2Array = data['trim_polygon']
			
			var local_weights: PackedFloat32Array = PackedFloat32Array()
			local_weights.resize(len(all_points))
			local_weights.fill(0.0)
			
			for i in range(0, len(bone_polygon_owners)):
				var bone_owner: Bone2D = bone_polygon_owners[i]
				if bone_owner == bone:
					var bone_polygon: PackedVector2Array = bone_polygons[i]
					for j in range(0, len(bone_polygon)):
						local_weights[find_approx(bone_polygon[j], all_points)] = 1.0
			
			var bone_start: Vector2 = bone.global_position
			var bone_end: Vector2 = bone_start + Vector2.RIGHT.rotated(bone.get_bone_angle()) * bone.get_length()
			bone_start = to_sprite_coord(bone_start, sprite, bone_image)
			bone_end = to_sprite_coord(bone_end, sprite, bone_image)
			
			for i in range(0, len(internal_points)):
				var point: Vector2 = internal_points[i]
				if point.is_equal_approx(Geometry2D.get_closest_point_to_segment(point, bone_start, bone_end)):
					local_weights[all_points.find(point)] = 1.0
			
			weights[bone] = local_weights
		
		
		var polygon: Polygon2D = Polygon2D.new()
		polygon.name = bone_name
		polygon_parent.add_child(polygon)
		polygon.owner = scene
		polygon.texture = bone_sprite
		polygon.texture_offset = -sprite.position+Vector2(bone_image.get_width()/2, bone_image.get_height()/2)
		polygon.polygon = from_sprite_coords(all_points, sprite, bone_image, polygon)
		polygon.internal_vertex_count = len(internal_points)
		polygon.polygons = polygons
		polygon.uv = polygon.polygon
		polygon.skeleton = polygon.get_path_to(skeleton)
		polygon.clear_bones()
		
		for i in range(0, skeleton.get_bone_count()):
			var i_bone: Bone2D = skeleton.get_bone(i)
			var i_bone_path: NodePath = skeleton.get_path_to(i_bone)
			var local_weights: PackedFloat32Array = PackedFloat32Array()
			local_weights.resize(len(polygon.polygon))
			if weights.keys().has(i_bone):
				local_weights = weights[i_bone]
			else:
				local_weights.fill(0.0)
			polygon.add_bone(i_bone_path, local_weights)
	
	if update_modifications:
		print('Next: modifications')
		var pending_bones: Dictionary = {}
		var bone_to_target: Dictionary = {}
		for bone: Bone2D in all_bones:
			var bone_name: String = filter_text(bone.name)
			var parent_bone: Node = bone.get_parent()
			if not all_sprites.keys().has(bone_name.to_lower()):
				if bone_to_target.has(parent_bone):
					bone_to_target[bone] = bone_to_target[parent_bone]
				continue
			var partial_bone: bool = filter_text(bone.name) != bone.name
			var target: Node2D
			if filter_text(bone.name).to_lower() != filter_text(parent_bone.name).to_lower():
				var local_parent: Node = (bone_to_target[parent_bone]
											if bone_to_target.has(parent_bone)
											else target_parent)
				if local_parent.has_node(bone_name):
					target = local_parent.get_node(bone_name)
				else:
					target = Node2D.new()
					target.name = bone_name
					local_parent.add_child(target)
					target.owner = scene
			else:
				target = bone_to_target[parent_bone]
			bone_to_target[bone] = target
			var bone_start: Vector2 = bone.global_position
			var bone_end: Vector2 = bone_start + Vector2.RIGHT.rotated(bone.get_bone_angle()) * bone.get_length()
			target.global_position = bone_end
			if pending_bones.has(bone_name.to_lower()):
				pending_bones[bone_name.to_lower()]['bones'].append(bone)
			else:
				pending_bones[bone_name.to_lower()] = {'bones': [bone], 'target': target}
		
		for bone_name: String in pending_bones.keys():
			var bone_data: Dictionary = pending_bones[bone_name]
			var bones: Array = bone_data['bones']
			var target: Node = bone_data['target']
			if len(bones) == 1:
				if not has_bone_child(bones[0]):
					var modification: SkeletonModification2DLookAt = SkeletonModification2DLookAt.new()
					modification.bone2d_node = skeleton.get_path_to(bones[0])
					modification.target_nodepath = skeleton.get_path_to(target)
					modification.resource_local_to_scene = true
					modifications.add_modification(modification)
			elif len(bones) == 2:
				var modification: SkeletonModification2DTwoBoneIK = SkeletonModification2DTwoBoneIK.new()
				modification.set_joint_one_bone2d_node(skeleton.get_path_to(bones[0]))
				modification.set_joint_two_bone2d_node(skeleton.get_path_to(bones[1]))
				modification.flip_bend_direction = is_angle_greater(bones[0].get_bone_angle(), bones[1].get_bone_angle())
				modification.target_nodepath = skeleton.get_path_to(target)
				modification.resource_local_to_scene = true
				modifications.add_modification(modification)
			elif len(bones) > 2:
				var modification: SkeletonModification2DFABRIK = SkeletonModification2DFABRIK.new()
				modification.fabrik_data_chain_length = len(bones)
				for i in range(0, len(bones)):
					modification.set_fabrik_joint_bone2d_node(i, skeleton.get_path_to(bones[i]))
				modification.target_nodepath = skeleton.get_path_to(target)
				modification.resource_local_to_scene = true
				modifications.add_modification(modification)
		modifications.resource_local_to_scene = true
		
		modifications.enable_all_modifications(true)
		modifications.enabled = true
