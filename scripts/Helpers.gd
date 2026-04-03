extends Object
class_name Helpers

## (see: https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line)
static func dist_to_line_squared(p0: Vector2, p1: Vector2, p2: Vector2) -> float:
	var delta_y: float = p2.y-p0.y
	var delta_x: float = p2.x-p0.x
	return (abs(delta_y*p1.x - delta_x*p1.y + p2.x*p0.y - p2.y*p0.x) ** 2)/(delta_y*delta_y + delta_x*delta_x)
