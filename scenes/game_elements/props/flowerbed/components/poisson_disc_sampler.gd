# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0

class_name PoissonDiscSampler
extends Object

# https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
# https://www.jasondavies.com/poisson-disc/

# Number of attempts to make around each queued point
const K := 30

var rect: Rect2

## Generated points
var points: PackedVector2Array

## Radius: minimum distance between generated points
var _r: float
## [member _r] squared – this is needed frequently so cache it for a potential
## modest performance improvement.
var _r_squared: float

## A grid covering the area to be filled. Each element is an index into [member
## points] or [code]-1[/code] if the cell is unfilled. Cells are conceptually
## square, with side [member _cell_size].
var _grid: PackedInt32Array

## Size of sides of cells in [member _grid], derived from [member _r].
var _cell_size: float

## Points in [member _grid] are relative to this origin, so that all coordinates
## are positive.
var _grid_origin: Vector2

## Dimensions of [member _grid]
var _grid_size: Vector2i

## Elements of [member _points] that we will look to place further points near.
## When we fail to place a new point near an element of this array, it is removed.
## Generation is complete when this is empty.
var _active: PackedVector2Array


func initialise(shape: Shape2D, minimum_separation: float = 64) -> void:
	rect = shape.get_rect()
	_r = minimum_separation
	_r_squared = _r * _r

	# Pick the cell size to be bounded by r/sqrt(2), so that each grid cell
	# contains at most one sample. sin(45°) = sqrt(0.5)
	_cell_size = _r * sqrt(0.5)
	_grid_origin = rect.position
	_grid_size = Vector2i(
		ceili(rect.size.x / _cell_size),
		ceili(rect.size.y / _cell_size),
	)
	_grid.resize(_grid_size.x * _grid_size.y)
	assert(_grid.size() < ((1 << 31) - 1), "Grid is too large for int32 indices")
	_grid.fill(-1)

	points.clear()
	_active.clear()


## Runs generate until no more points can be discovered
func fill() -> void:
	while generate():
		pass


## Generates a single point and appends it to [member points].
## Returns [code]false[/code] when no more points can be generated.
func generate() -> bool:
	if not points:
		var start := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y),
		)
		_add_sample(start)
		return true

	while _active:
		# While the active list is not empty, choose a random index
		# from it (say i).
		var n := _active.size() - 1
		var i := randi_range(0, n)
		var p := _active[i]

		for j in range(K):
			var q := _generate_around(p)
			if _within_extent(q) and not _has_nearby_point(q):
				_add_sample(q)
				return true

		# No suitable candidate found near p; remove it from the queue
		_active[i] = _active[n]
		_active.remove_at(n)

	# No further points to search around
	return false


func finished() -> bool:
	return _active.is_empty()


func _to_grid_coords(point: Vector2) -> Vector2i:
	var transformed := point - _grid_origin
	return Vector2i(
		floori(transformed.x / _cell_size),
		floori(transformed.y / _cell_size),
	)


func _add_sample(point: Vector2) -> void:
	points.push_back(point)
	_active.push_back(point)

	var gc := _to_grid_coords(point)
	var grid_index := _grid_size.x * gc.y + gc.x
	var existing_ix := _grid[grid_index]
	assert(
		existing_ix == -1,
		(
			"Existing point %s at grid coord %s when inserting %s"
			% [
				points[existing_ix],
				gc,
				point,
			]
		)
	)
	_grid[grid_index] = points.size() - 1


## Generates a point between r and 2r away from p, uniformly distributed.
func _generate_around(p: Vector2) -> Vector2:
	var theta := randf_range(0, TAU)
	# https://stackoverflow.com/a/9048443 via https://www.jasondavies.com/poisson-disc/
	var distance := sqrt(randf_range(_r_squared, 4 * _r_squared))
	var q := p + (distance * Vector2.from_angle(theta))
	return q


## Searches [member _grid] to check if an existing point is within a distance of r from p.
func _has_nearby_point(p: Vector2) -> bool:
	var n := 2
	var gc := _to_grid_coords(p)
	var x0 := maxi(gc.x - n, 0)
	var y0 := maxi(gc.y - n, 0)
	var x1 := mini(gc.x + n + 1, _grid_size.x)
	var y1 := mini(gc.y + n + 1, _grid_size.y)
	for y in range(y0, y1):
		var gy := y * _grid_size.x
		for x in range(x0, x1):
			var existing_ix := _grid[gy + x]
			if existing_ix != -1:
				var existing := points[existing_ix]
				if existing.distance_squared_to(p) < _r_squared:
					return true
	return false


func _within_extent(p: Vector2) -> bool:
	return rect.has_point(p)
