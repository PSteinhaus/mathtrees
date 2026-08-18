extends Object
class_name Boulder

static var multimesh_instances: Array[MultiMeshInstance2D]
static var multimesh_instance_poly_points: Array[PackedVector2Array]

## One shared material for every boulder MultiMesh.
static var boulder_material: ShaderMaterial

## Default colors for newly created boulders.
static var default_color: Color = Color(0.0, 0.0, 0.2, 1.0)
static var powerup_color: Color = Color(0.1, 0.1, 0.3, 1.0)

## All boulders that currently exist logically.
##
## This is separate from the MultiMesh instances because a Boulder only
## becomes associated with a GPU instance when it is visible.
static var all_boulders: Array[Boulder] = []
static var visible_boulders: Array[Boulder] = []

var mm_index: int
var transform_index: int = -1

## These have to be here because this information is only represented
## as a transform of an instance inside an MM when the boulder is actually
## visible, so we need to store it here as well to be able to restore it.
var position: Vector2
var rotation: float
var scale: Vector2

## Actual color of this boulder.
##
## Normally this is one of default_color / powerup_color, but an individual
## boulder can have its own color.
var color: Color

const VARIANT_COUNT: int = 4

func multimesh() -> MultiMesh:
	return multimesh_instances[mm_index].multimesh


func transform2D() -> Transform2D:
	return Transform2D(rotation, scale, 0.0, position)


## Get the points making up this boulder oriented in global coordinates.
func points() -> PackedVector2Array:
	var poly_points := multimesh_instance_poly_points[mm_index]
	var result := PackedVector2Array()
	result.resize(poly_points.size())

	for i in poly_points.size():
		result[i] = transform2D() * poly_points[i]

	return result


## p is the collision position in global coordinates.
func react_to_collision(_p: Vector2):
	pass


static func mmi_index_range() -> Vector2i:
	return Vector2i(0, VARIANT_COUNT - 1)


## Creates a boulder at the specified position, rotation and scale.
static func generate_at(
	pos: Vector2,
	rot: float,
	s: Vector2
) -> Boulder:
	var b := Boulder.new()

	# 0 .. VARIANT_COUNT - 1:
	#     regular boulders
	#
	# VARIANT_COUNT .. 2 * VARIANT_COUNT - 1:
	#     powerup boulders
	var i_range := mmi_index_range()
	var mm_i := randi_range(i_range[0], i_range[1])

	b.set_props(pos, rot, s, mm_i)

	return b


func set_props(
	pos: Vector2,
	rot: float,
	s: Vector2,
	mm_i: int
) -> void:
	self.mm_index = mm_i
	self.position = pos
	self.scale = s
	self.rotation = rot

	if mm_i < VARIANT_COUNT:
		self.color = default_color
	else:
		self.color = powerup_color

	all_boulders.push_back(self)


func set_color(new_color: Color) -> void:
	color = new_color
	# If the boulder is currently visible, update only its GPU instance.
	if transform_index >= 0 and mm_index >= 0:
		var mm := multimesh()
		mm.set_instance_color(transform_index, color)

## Reset this boulder to its palette-defined default color.
func reset_color() -> void:
	if mm_index < VARIANT_COUNT:
		color = default_color
	else:
		color = powerup_color


func move_visually(new_pos: Vector2) -> void:
	position = new_pos

	var mm := multimesh()
	mm.set_instance_transform_2d(
		transform_index,
		transform2D()
	)


## Apply new palette colors to all existing boulders.
##
## Boulders with an explicit custom color keep that color.
static func apply_palette(
	normal_color: Color,
	powerup_boulder_color: Color,
	background_color: Color,
	highlight_color: Color
) -> void:
	default_color = normal_color
	powerup_color = powerup_boulder_color

	for b: Boulder in all_boulders:
		if b.mm_index < VARIANT_COUNT:
			b.set_color(default_color)
		else:
			b.set_color(powerup_color)
			b.powerup_node.set_colors(powerup_color, background_color, highlight_color)

	upload_visible_colors()


## Apply new palette colors to all existing boulders and overwrite
## individual custom colors as well.
static func apply_palette_to_all(
	normal_color: Color,
	powerup_boulder_color: Color
) -> void:
	default_color = normal_color
	powerup_color = powerup_boulder_color

	for b: Boulder in all_boulders:
		if b.mm_index < VARIANT_COUNT:
			b.color = default_color
		else:
			b.color = powerup_color

	upload_visible_colors()


## Re-upload colors for all currently visible boulders in bulk.
static func upload_visible_colors() -> void:
	if visible_boulders.is_empty():
		return

	var colors: Array = []
	var counts: Array[int] = []

	# Create one typed color array for every MultiMesh.
	for i in range(multimesh_instances.size()):
		var color_array: Array[Color] = []
		colors.append(color_array)
		counts.append(0)

	# Put each boulder's color at the exact instance index that was
	# assigned to it by set_visible_boulders().
	for b: Boulder in visible_boulders:
		var mm_i := b.mm_index
		var instance_i := b.transform_index

		# Make sure the array is large enough to contain this instance.
		var color_array: Array[Color] = colors[mm_i]

		if color_array.size() <= instance_i:
			color_array.resize(instance_i + 1)

		color_array[instance_i] = b.color
		colors[mm_i] = color_array

		counts[mm_i] = max(counts[mm_i], instance_i + 1)

	# Upload the colors using exactly the same instance counts as the
	# corresponding MultiMeshes.
	for i in range(multimesh_instances.size()):
		var count := counts[i]

		if count == 0:
			continue

		var mm: MultiMesh = multimesh_instances[i].multimesh
		var color_array: Array[Color] = colors[i]

		Helpers.set_multimesh_colors(
			mm,
			color_array,
			count
		)


## Makes the given boulders actually visible by updating the MultiMesh
## buffers.
static func set_visible_boulders(
	boulders: Array[Boulder]
) -> void:
	# Remember exactly which boulders correspond to the current
	# MultiMesh instance layout.
	visible_boulders = boulders

	var transforms: Array = []
	var colors: Array = []
	var transforms_indices: Array[int] = []

	for i in range(multimesh_instances.size()):
		var transform_array: Array[Transform2D] = []
		var color_array: Array[Color] = []

		transform_array.resize(boulders.size())
		color_array.resize(boulders.size())

		transforms.push_back(transform_array)
		colors.push_back(color_array)
		transforms_indices.push_back(0)

	# Group the boulders by MultiMesh.
	for b: Boulder in boulders:
		var index: int = transforms_indices[b.mm_index]

		transforms[b.mm_index][index] = b.transform2D()
		colors[b.mm_index][index] = b.color

		b.transform_index = index

		transforms_indices[b.mm_index] += 1

	# Upload all data.
	for i in range(multimesh_instances.size()):
		var mm_boulder_count: int = transforms_indices[i]
		var mm: MultiMesh = multimesh_instances[i].multimesh

		if mm.instance_count < mm_boulder_count:
			mm.instance_count = mm_boulder_count

		mm.visible_instance_count = mm_boulder_count

		Helpers.set_multimesh_transforms_2d(
			mm,
			transforms[i],
			mm_boulder_count
		)

		Helpers.set_multimesh_colors(
			mm,
			colors[i],
			mm_boulder_count
		)


static func init_boulders(parent: Node2D) -> void:
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;

		void fragment() {
			COLOR = INSTANCE_COLOR;
		}
	"""

	boulder_material = ShaderMaterial.new()
	boulder_material.shader = shader

	multimesh_instances = []
	multimesh_instance_poly_points = []
	all_boulders = []
	visible_boulders = []

	for i in range(VARIANT_COUNT):
		generate_boulder_multimesh(boulder_material, parent)

	for i in range(VARIANT_COUNT):
		generate_boulder_multimesh(boulder_material, parent)


static func generate_boulder_multimesh(
	mat: Material,
	parent: Node2D
) -> void:
	var multimesh_instance := MultiMeshInstance2D.new()

	if mat != null:
		multimesh_instance.material = mat

	var new_multimesh := MultiMesh.new()

	new_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	new_multimesh.use_colors = true

	var mesh_points := generate_poly_points()
	var mesh := Helpers.create_convex_polygon_mesh_2d(mesh_points)

	new_multimesh.mesh = mesh
	multimesh_instance.multimesh = new_multimesh

	multimesh_instances.push_back(multimesh_instance)
	multimesh_instance_poly_points.push_back(mesh_points)

	parent.add_child(multimesh_instance)


static func generate_poly_points(
	radius: float = 50.0
) -> PackedVector2Array:
	var sides_options = [5, 6, 7, 8]
	var sides = sides_options[randi() % sides_options.size()]

	var new_points := PackedVector2Array()

	for i in range(sides):
		var angle = (TAU / sides) * i

		var random_radius = radius * randf_range(0.8, 1.2)
		var random_angle = angle + randf_range(-0.1, 0.1)

		var x = cos(random_angle) * random_radius
		var y = sin(random_angle) * random_radius

		new_points.append(Vector2(x, y))

	return new_points
