extends Object
class_name Boulder

static var multimesh_instances: Array[MultiMeshInstance2D]
static var multimesh_instance_poly_points: Array[PackedVector2Array]
var mm_index: int
## these have to be here because these infos are only represented as a transform of an instance
## inside an mm when the boulder is actually visible, so we need to store them here as well to be
## able to restore them
var position: Vector2
var rotation: float
var scale: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func multimesh():
	return multimesh_instances[mm_index].multimesh

func transform2D() -> Transform2D:
	return Transform2D(rotation, scale, 0., position)

## get the points making up this boulder (its mesh) oriented the way it is in global coordinates
## this means rotation, position and possibly scaling is already factored in
func points() -> PackedVector2Array:
	var poly_points = multimesh_instance_poly_points[mm_index]
	var result := PackedVector2Array()
	result.resize(poly_points.size())

	for i in poly_points.size():
		result[i] = transform2D() * poly_points[i]
	return result

## adds a boulder at the specified position and rotation
## Warning: this clears a multimesh buffer, so at high boulder counts generating necessary boulders
## at once (if multiple additional are required) would be faster
static func generate_at(pos: Vector2, rot: float, s: Vector2) -> Boulder:
	# pick one of the boulder types (represented by the multimesh_instances) at random
	var b = Boulder.new()
	b.mm_index = randi() % multimesh_instances.size()
	b.position = pos
	b.scale = s
	b.rotation = rot
	return b

## makes the given boulders actually visible, by updating the multimesh buffers
static func set_visible_boulders(boulders: Array[Boulder]):
	# create the transform for each boulder and collect them, sorted for each multimesh
	var transforms_indices = []
	var transforms = []
	for i in range(0, multimesh_instances.size()):
		var a: Array[Transform2D] = []
		a.resize(boulders.size()) # reserve space to optimize
		transforms.push_back(a)
		transforms_indices.push_back(0)
	for b: Boulder in boulders:
		transforms[b.mm_index][transforms_indices[b.mm_index]] = Transform2D(b.rotation, b.scale, 0., b.position)
		transforms_indices[b.mm_index] += 1
	for i in range(0, multimesh_instances.size()):
		var mm_boulder_count = transforms_indices[i]
		var mm: MultiMesh = multimesh_instances[i].multimesh
		if mm.instance_count < mm_boulder_count:
			print("resized "+str(i)+" to: "+str(mm_boulder_count))
			mm.instance_count = mm_boulder_count
		# update visible instance count for each multimesh so that only those are drawn
		mm.visible_instance_count = mm_boulder_count
		# actually calc and push the new buffer
		Helpers.set_multimesh_transforms_2d(mm, transforms[i], mm_boulder_count)

static func init_boulders(parent: Node2D):
	# Create shader material for solid black color
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;

		void fragment() {
			COLOR = vec4(0.0, 0.0, 0.2, 1.0); // solid black
		}
	"""

	var black_material := ShaderMaterial.new()
	black_material.shader = shader
	
	multimesh_instances = []
	multimesh_instance_poly_points = []
	for i in range(4):
		var multimesh_instance := MultiMeshInstance2D.new()
		multimesh_instance.material = black_material
		var new_multimesh = MultiMesh.new()
		new_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		var mesh_points = generate_poly_points()
		var mesh = create_convex_polygon_mesh_2d(mesh_points)
		new_multimesh.mesh = mesh
		multimesh_instance.multimesh = new_multimesh
		multimesh_instances.push_back(multimesh_instance)
		# cache the poly points in this array, as we will use them extensively
		# and re-calculating them from the generated mesh is awkward
		multimesh_instance_poly_points.push_back(mesh_points)
		parent.add_child(multimesh_instance)

static func generate_poly_points(radius: float = 50.0) -> PackedVector2Array:
	# Choose number of sides randomly
	var sides_options = [5, 6, 7, 8] # pentagon, hexagon, septagon, octagon
	var sides = sides_options[randi() % sides_options.size()]
	
	var new_points: PackedVector2Array = []
	
	# Generate points in a circle with slight randomness
	for i in range(sides):
		var angle = (TAU / sides) * i
		
		# Add some randomness to radius and angle
		var random_radius = radius * randf_range(0.8, 1.2)
		var random_angle = angle + randf_range(-0.1, 0.1)
		
		var x = cos(random_angle) * random_radius
		var y = sin(random_angle) * random_radius
		
		new_points.append(Vector2(x, y))
	
	return new_points

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
