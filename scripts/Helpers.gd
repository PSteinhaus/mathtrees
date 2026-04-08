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
