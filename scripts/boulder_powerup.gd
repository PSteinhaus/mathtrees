extends Boulder
class_name BoulderPowerup

var powerup_node: PowerupNode

func init_powerup(powerup_variant: PowerupNode.PowerupVariant):
	var world = Global.get_world()
	powerup_node = PowerupNode.new(powerup_variant)
	powerup_node.position = position
	powerup_node.rotation = rotation
	powerup_node.scale = Vector2(0.8, 0.8)
	world.add_child(powerup_node)

static func mmi_index_range() -> Vector2i:
	return Vector2i(VARIANT_COUNT, 2 * VARIANT_COUNT - 1)

static func generate_at(pos: Vector2, rot: float, s: Vector2) -> BoulderPowerup:
	var b = BoulderPowerup.new()
	# pick one of the boulder types (represented by the multimesh_instances) at random
	# BUT: 0 to VARIANT_COUNT - 1 are regular boulders, VARIANT_COUNT to 2 * VARIANT_COUNT - 1 are powerup
	var i_range = mmi_index_range()
	var mm_i = randi_range(i_range[0], i_range[1])
	b.set_props(pos, rot, s, mm_i)
	return b
