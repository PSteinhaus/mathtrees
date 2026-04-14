## a class to collect Area2Ds that hold CollisionShape2Ds that can block the path of
## a growing root, such as boulders and order them for easy access (similar to RootPointMap)
## and to make collision checking infinitely scalable by only checking chunks close to the growing root
extends Object
class_name BoulderMap

## Vector2i is the chunk coordinate, Array is structured like this Array[Boulder]
## the final Array[int] contains the indices of all points relevant to the chunk
var map: Dictionary[Vector2i, Array] = {}
## Dictionary that maps Boulders to the chunk coordinates that they can be found in, so that it is
## easier to update the main map
## var reverse_map: Dictionary[Boulder, Array[Vector2i]]
var reverse_map: Dictionary[Boulder, Array]

const CHUNK_SIZE = 128.

func global_to_coordinate(global: Vector2) -> Vector2i:
	return Vector2i(global / CHUNK_SIZE)

func coordinate_to_global(coordinate: Vector2i) -> Vector2:
	return Vector2(coordinate * CHUNK_SIZE)

func close_boulders(c0: Vector2i) -> Array[Boulder]:
	# go through the chunk and all 8 surrounding ones and collect all boulders
	var c_boulders: Array[Boulder] = []
	for x: int in range(c0.x-1, c0.x+2):
		for y: int in range(c0.y-1, c0.y+2):
			var coords = Vector2i(x,y)
			if not map.has(coords): continue
			var boulders = map[coords]
			c_boulders.append_array(boulders)
			#for b: Boulder in boulders:
				#if !c_boulders.has(b):
					#c_boulders.push_back(b)
	return c_boulders

## boulders that are contained in the given area
func rect_boulders(global_rect: Rect2) -> Array[Boulder]:
	# translate the rect into coordinates
	var start: Vector2i = global_to_coordinate(global_rect.position)
	var end: Vector2i = global_to_coordinate(global_rect.end)
	# go through the chunk and all 8 surrounding ones and collect all boulders
	var c_boulders: Array[Boulder] = []
	for x: int in range(start.x-1, end.x+2):
		for y: int in range(start.y-1, end.y+2):
			var coords = Vector2i(x,y)
			if not map.has(coords): continue
			var boulders = map[coords]
			c_boulders.append_array(boulders)
			#for b: Boulder in boulders:
				#if !c_boulders.has(b):
					#c_boulders.push_back(b)
	return c_boulders

## comparison points must be in global space
## we assume that start is actually allowed
func closest_allowed_point(start: Vector2, end: Vector2) -> Vector2:
	var closest_dist: float = start.distance_to(end)
	var closest_point: Vector2 = end
	# first get the chunk, so we know which 9 chunks to check
	var c0 = global_to_coordinate(end)
	var c_boulders = close_boulders(c0)
	
	# go through all boulders and check for a collision
	for b: Boulder in c_boulders:
		var points = b.points()
		var intersect_lines := Geometry2D.intersect_polyline_with_polygon(
			PackedVector2Array([start, end]),
			points
			)
		# there should at most be 1 line in usual cases (except for weirdly shaped polygons)
		for line: PackedVector2Array in intersect_lines:
			for p: Vector2 in line:
				var dist := p.distance_to(start)
				if dist < closest_dist:
					# make sure there is a safety distance to make sure you don't get stuck inside a polygon
					var diff_normalized = (p - start).normalized()
					const SAFETY_DIST: float = 10.0
					closest_point = p - (diff_normalized * SAFETY_DIST)
					closest_dist = dist
		
	return closest_point

## pos in global coords
func generate_boulder_at(pos: Vector2, size: float = 1.5):
	var s = size
	var b = Boulder.generate_at(pos, TAU * randf(), Vector2(s, s))
	update_boulder(b)

func update_boulder(b: Boulder):
	# first delete the area from the map by checking the reverse_map:
	if reverse_map.has(b):
		for coords: Vector2i in reverse_map[b]:
			map[coords].erase(b)
			#var indices: Vector2i = map[coords][rt]	# start and end of 
	
	# go through the points of the area and check to which chunks they belong
	# then add the area to the chunks (and collect that chunk coordinates to later add all of them to the reverse map)
	var affected_chunks = [] # for the reverse map
	var points = b.points()
	if points.is_empty(): return
	for i in range(points.size()):
		var p = points[i]
		var coords = global_to_coordinate(p)
		var has_coords = map.has(coords)
		if has_coords && map[coords].has(b):
			continue
		else:
			if not has_coords:
				map[coords] = []
			map[coords].push_back(b)
		if not affected_chunks.has(coords):
			affected_chunks.push_back(coords)
	reverse_map[b] = affected_chunks
