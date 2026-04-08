extends Object
class_name RootPointMap

## Vector2i is the chunk coordinate, Dictionary is structured like this Dictionary[RT_Tree, Array[int]]
## the final Array[int] contains the indices of all points relevant to the chunk
var map: Dictionary[Vector2i, Dictionary] = {}
## Dictionary that maps RT_Trees to the chunk coordinates that they can be found in, so that it is
## easier to update the main map for that RT_Tree
## var reverse_map: Dictionary[RT_Tree, Array[Vector2i]]
var reverse_map: Dictionary[RT_Tree, Array]

const CHUNK_SIZE = 128.

func global_to_coordinate(global: Vector2) -> Vector2i:
	return Vector2i(global / CHUNK_SIZE)

func coordinate_to_global(coordinate: Vector2i) -> Vector2:
	return Vector2(coordinate * CHUNK_SIZE)

## returns all points of a chunk (except the ones from ignore_root) as global
func points_at_coordinate(coordinate: Vector2i, ignore_root: RT_Tree = null) -> Array[Vector2]:
	if not map.has(coordinate): return []
	var chunk = map[coordinate]
	var chunk_points: Array[Vector2] = []
	for rt: RT_Tree in chunk.keys():
		if rt == ignore_root: continue
		var indices = chunk[rt]
		var points = rt.points()
		for i in indices:
			var point = points[i]
			chunk_points.push_back(rt.to_global(point))
	return chunk_points

## comparison point must be in global space
## returns Vector2.INF if there is no closest point
func closest_point(comparison_point: Vector2, ignore_root: RT_Tree = null) -> Vector2:
	var closest_dist: float = INF
	var c_point: Vector2 = Vector2.INF
	# first get the chunk, so we know which 9 chunks to check
	var c0 = global_to_coordinate(comparison_point)
	# go through the chunk and all 8 surrounding ones and check each point until you have the closest one
	for x: int in range(c0.x-1, c0.x+2):
		for y: int in range(c0.y-1, c0.y+2):
			var chunk_points = points_at_coordinate(Vector2i(x,y), ignore_root)
			for p in chunk_points:
				var dist = comparison_point.distance_squared_to(p)
				if dist < closest_dist:
					closest_dist = dist
					c_point = p
	return c_point

## comparison point must be in global space
func dist_to_closest_line_squared(comparison_point: Vector2, ignore_root: RT_Tree = null) -> float:
	var closest_dist: float = INF
	# first get the chunk, so we know which 9 chunks to check
	var c0 = global_to_coordinate(comparison_point)
	# go through the chunk and all 8 surrounding ones and collect all trees and their indices
	var trees_and_indices: Dictionary[RT_Tree, Array]
	for x: int in range(c0.x-1, c0.x+2):
		for y: int in range(c0.y-1, c0.y+2):
			var coords = Vector2i(x,y)
			if not map.has(coords): continue
			var chunk = map[coords]
			for rt: RT_Tree in chunk.keys():
				if rt == ignore_root: continue
				var indices: Array = chunk[rt]
				if trees_and_indices.has(rt):
					trees_and_indices[rt].append_array(indices)
				else:
					trees_and_indices[rt] = indices.duplicate()
	
	# sort all indices lists, so that they can be used for edge iteration
	for rt: RT_Tree in trees_and_indices.keys():
		var point_in_local = rt.to_local(comparison_point)
		var points = rt.points()
		var indices: Array = trees_and_indices[rt]
		indices.sort()
		# finally, go through all edges and check the distance to the point
		if indices.size() == 1:
			var i0 = indices[0]
			var dist = points[i0].distance_squared_to(point_in_local)
			if dist < closest_dist:
				closest_dist = dist
				continue
		for i in range(indices.size() - 1):
			var i0 = indices[i]
			var i1 = indices[i+1]
			if i1 == i0+1:
				var p0 = points[i0]
				var p1 = points[i1]
				var dist = Helpers.dist_to_line_squared(p0, point_in_local, p1)
				if dist < closest_dist:
					# check whether it is not just a false positive (close to the linear function, but away from an edge)
					var edge_vec = p1-p0
					var middle = p0 + ((p1-p0) / 2)
					var dist_to_middle = p0.distance_squared_to(middle)
					var edge_perpendicular = edge_vec.rotated(PI/2.)
					var dist_from_middle_line_to_local_point = Helpers.dist_to_line_squared(middle, point_in_local, middle + edge_perpendicular)
					if dist_from_middle_line_to_local_point <= dist_to_middle * 4.:
						closest_dist = dist
				for j in range(0, 2):
					var dist_j = points[i0 + j].distance_squared_to(point_in_local)
					if dist_j < closest_dist:
						closest_dist = dist_j
	return closest_dist

func update_root(rt: RT_Tree):
	# first delete the rt from the map by checking the reverse_map:
	if reverse_map.has(rt):
		for coords: Vector2i in reverse_map[rt]:
			map[coords].erase(rt)
			#var indices: Vector2i = map[coords][rt]	# start and end of 
	
	# go through the points of the root and check to which chunks they belong
	# then add them to the chunk (and collect that chunk coordinate to later add all of them to the reverse map)
	var affected_chunks = [] # for the reverse map
	var points = rt.points()
	if points.is_empty(): return
	for i in range(points.size()):
		var p = points[i]
		var coords = global_to_coordinate(rt.to_global(p))
		var has_coords = map.has(coords)
		if has_coords && map[coords].has(rt):
			var indices: Array[int] = map[coords][rt]
			indices.push_back(i)
		else:
			if not has_coords:
				map[coords] = {}
			var a: Array[int] = [i]
			map[coords][rt] = a
		if not affected_chunks.has(coords):
			affected_chunks.push_back(coords)
	reverse_map[rt] = affected_chunks

func update_root_when_optimized(rt: RT_Tree):
	if rt.is_optimized:
		update_root(rt)
	else:
		rt.optimize_finished.connect(update_root.bind(rt))
