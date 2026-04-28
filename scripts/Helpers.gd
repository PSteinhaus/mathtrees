extends Object
class_name Helpers

## (see: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line) NOTE: probably superseeded by something in Geometry2D
static func dist_to_line_squared(p0: Vector2, p1: Vector2, p2: Vector2) -> float:
	var delta_y: float = p2.y-p0.y
	var delta_x: float = p2.x-p0.x
	return (abs(delta_y*p1.x - delta_x*p1.y + p2.x*p0.y - p2.y*p0.x) ** 2)/(delta_y*delta_y + delta_x*delta_x)

static func push_back_instance_in_multimesh(mm: MultiMesh, transform: Transform2D):
	var old_count := mm.instance_count
	var new_count := old_count + 1

	# Backup existing data
	var transforms := []
	transforms.resize(old_count)
	for i in old_count:
		transforms[i] = mm.get_instance_transform_2d(i)

	# Resize (this clears buffers internally)
	mm.instance_count = new_count

	# Restore old data
	for i in old_count:
		mm.set_instance_transform_2d(i, transforms[i])

	# Add new instance at the end
	mm.set_instance_transform_2d(old_count, transform)

## DOESN'T SET THE instance_count! It is your responsibility to make sure that the space fits!
static func set_multimesh_transforms_2d(multimesh: MultiMesh, transforms: Array[Transform2D], t_count: int) -> void:
#	var count = multimesh.instance_count
	# 8 floats per Transform2D
	#var data := PackedFloat32Array()
	#data.resize(count * 8)

	for i in t_count:
		var t: Transform2D = transforms[i]
		multimesh.set_instance_transform_2d(i, t)
		#var base := i * 8
#
		## Godot Transform2D structure:
		## [ x.x, x.y, y.x, y.y, origin.x, origin.y, 0, 0 ]
#
		#data[base + 0] = t.x.x
		#data[base + 1] = t.x.y
		#data[base + 2] = t.y.x
		#data[base + 3] = t.y.y
#
		#data[base + 4] = t.origin.x
		#data[base + 5] = t.origin.y

		# Padding
		#data[base + 6] = 0.0
		#data[base + 7] = 0.0

#	multimesh.buffer = data

static func get_path_length(points: PackedVector2Array) -> float:
	var total_length: float = 0.
	if points.size() < 2:
		return 0.
	for i in range(points.size()-1):
		var from := points[i]
		var to := points[i + 1]
		total_length += from.distance_to(to)
	return total_length

static func move_along_points(node: Node2D, points: PackedVector2Array, speed: float) -> Tween:
	if points.size() < 2:
		return

	var tween := node.create_tween()
	var segment_count := points.size() - 1

	for i in range(segment_count):
		var from := points[i]
		var to := points[i + 1]
		var length: float = from.distance_to(to)
		var segment_time = length / speed
		move_to_point(node, tween, from, to, segment_time)
	return tween

static func move_to_point(node: Node2D, tween: Tween, from: Vector2, to: Vector2, time: float) -> Tween:
	tween.tween_method(
			func(t: float) -> void:
				node.position = from.lerp(to, t),
			0.0,
			1.0,
			time
		)
	return tween

static func get_node_leaves(node: Node) -> Array[Node]:
	var leaves: Array[Node] = []
	
	# If the node has no children, it is a leaf
	if node.get_child_count() == 0:
		leaves.push_back(node)
	else:
		# Otherwise, recursively search through all children
		for child in node.get_children():
			leaves.append_array(get_node_leaves(child))
			
	return leaves

static func create_convex_polygon_mesh_2d(poly_points: PackedVector2Array) -> ArrayMesh:
	if poly_points.size() < 3:
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var verts := PackedVector3Array()
	var indices := PackedInt32Array()

	# Convert 2D points to 3D vertices on the XY plane.
	for p in poly_points:
		verts.append(Vector3(p.x, p.y, 0.0))

	# Triangulate as a fan: (0, i, i+1)
	for i in range(1, poly_points.size() - 1):
		indices.append(0)
		indices.append(i)
		indices.append(i + 1)

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func create_line_mesh_2d(line_points: PackedVector2Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()

	if line_points.size() < 2:
		return mesh
	
	if line_points.size() % 2 != 0:
		push_error("create_line_mesh_2d called with uneven point number!")

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_points

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

static func create_line_mesh_from_lines(
	lines: PackedVector2Array,
	vertex_start_width: float = 10.0,
	vertex_end_width: float = 6.0
) -> Mesh:
	if lines.size() < 2:
		return null

	var mesh = ArrayMesh.new()

	var vertices : PackedVector2Array
	var uvs : PackedVector2Array
	var normals : PackedVector2Array
	var colors : PackedColorArray

	# Temp arrays for building
	var verts = []
	var uvs_lst = []
	var normals_lst = []
	var colors_lst = []

	var total_segments: int = lines.size() / 2
	for i in range(total_segments):
		var j: int = i * 2
		var p0 = lines[j]
		var p1 = lines[j+1]

		var segment_uv = float(i) / float(total_segments)
		#var width0 = vertex_start_width
		#var width1 = vertex_end_width
		var width0 = lerp(vertex_start_width, vertex_end_width, segment_uv)
		var width1 = lerp(vertex_start_width, vertex_end_width, (i + 1.0) / total_segments)

		# Segment direction and normal
		var dir = (p1 - p0).normalized()
		var normal = Vector2(-dir.y, dir.x)

		# Build quad: 4 vertices, CCW
		var v0 = p0 + normal * width0
		var v1 = p0 - normal * width0
		var v2 = p1 + normal * width1
		var v3 = p1 - normal * width1

		# FIXME: the order of these vertices is probably somewhat wrong, as I
		# 		 developed it through trial and error, but this will likely only
		#		 come up once meshes created here will get textured
		verts.append(v0)
		verts.append(v1)
		verts.append(v3)
		verts.append(v3)
		verts.append(v2)
		verts.append(v0)

		# UVs: 0…1 along the segment
		uvs_lst.append(Vector2(1, 0))   # v0
		uvs_lst.append(Vector2(0, 0))   # v1
		uvs_lst.append(Vector2(0, 1))   # v3
		uvs_lst.append(Vector2(0, 1))   # v3
		uvs_lst.append(Vector2(1, 1))   # v2
		uvs_lst.append(Vector2(1, 0))   # v0

		# Normals (if needed by shader) (WARNGING: probably broken)
		#normals_lst.append(normal)
		#normals_lst.append(normal)
		#normals_lst.append(normal)
		#normals_lst.append(normal)

		# Color: you can later pass via uniform; here just white
		for _i in range(6):
			colors_lst.append(Color(1, 1, 1))

	# Convert to packed arrays
	vertices = PackedVector2Array(verts)
	uvs = PackedVector2Array(uvs_lst)
	#normals = PackedVector2Array(normals_lst)
	colors = PackedColorArray(colors_lst)

	# Fill mesh array
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	#surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_COLOR] = colors

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

	return mesh
