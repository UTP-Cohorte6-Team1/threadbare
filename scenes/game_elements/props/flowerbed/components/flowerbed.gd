# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0

extends Area2D

# https://www.jasondavies.com/poisson-disc/
# https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf

@export var flowers: Array[Texture2D]

var minimum_separation: float = 24

#@export_tool_button("Refill") var _refill: Callable = fill

var _shape_transform: Transform2D
var _sampler := PoissonDiscSampler.new()


func _ready() -> void:
	fill()


func _clear() -> void:
	for child: Node2D in get_children():
		if child is Sprite2D:
			child.queue_free()


func fill() -> void:
	var trials = 10
	var t0 = Time.get_ticks_usec()
	_clear()

	for owner_id: int in get_shape_owners():
		_shape_transform = shape_owner_get_transform(owner_id)
		for i: int in range(shape_owner_get_shape_count(owner_id)):
			var shape := shape_owner_get_shape(owner_id, i)
			for _trial in range(trials):
				_sampler.initialise(shape, minimum_separation)
				_sampler.fill()

	var t1 = Time.get_ticks_usec()
	var delta_ms = (t1 - t0) / (trials * 1000.)
	print(
		"Generating points took avg %.1fms (%d frames)" % [delta_ms, ceili(delta_ms / (1000. / 60))]
	)


var i = 0


func _process(delta: float) -> void:
	if i >= _sampler.points.size():
		return

	_add_flower(_sampler.points[i])
	i += 1


func _add_flower(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = flowers.pick_random()
	sprite.position = _shape_transform * pos
	add_child(sprite)
