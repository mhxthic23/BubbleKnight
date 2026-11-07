
extends Area2D

# ==========================================
# PROJECTILE CONFIGURATION
# ==========================================

const LAUNCH_SPEED: float = 460.0
const LAUNCH_ACCELERATION: float = 1500.0
const MAX_DISTANCE: float = 850.0

const EMERGE_DURATION: float = 0.30
const EMERGE_DISTANCE: float = 20.0

const INITIAL_SPEED: float = 70.0

const INITIAL_SCALE: float = 0.14
const FINAL_SCALE: float = 0.32
const CAPTURE_SCALE: float = 0.78

# Reward sementara untuk musuh biasa
const ENERGY_REWARD: int = 10
const COIN_REWARD: int = 20


enum ProjectileState {
	EMERGING,
	LAUNCHING,
	CAPTURING
}

var state: int = ProjectileState.EMERGING

var direction: Vector2 = Vector2.RIGHT
var spawn_position: Vector2 = Vector2.ZERO

var shooter: Node2D = null
var trapped_enemy: Node2D = null

var emerge_timer: float = 0.0
var current_speed: float = INITIAL_SPEED
var distance_travelled: float = 0.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	global_position = spawn_position

	monitoring = false
	collision_shape.disabled = true

	if visual.sprite_frames == null:

		push_error("SpriteFrames projectile belum dipasang!")
		return

	if visual.sprite_frames.has_animation("bubble_projectile"):

		visual.sprite_frames.set_animation_loop(
			"bubble_projectile",
			true
		)

		visual.sprite_frames.set_animation_speed(
			"bubble_projectile",
			8.0
		)

		visual.play("bubble_projectile")

	visual.scale = Vector2(
		INITIAL_SCALE,
		INITIAL_SCALE
	)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# ==========================================
# PHYSICS PROCESS
# ==========================================

func _physics_process(delta: float) -> void:

	if state == ProjectileState.EMERGING:

		handle_emergence(delta)

	elif state == ProjectileState.LAUNCHING:

		handle_launch(delta)


# ==========================================
# BUBBLE EMERGENCE
# ==========================================

func handle_emergence(delta: float) -> void:

	emerge_timer += delta

	var progress := clampf(
		emerge_timer / EMERGE_DURATION,
		0.0,
		1.0
	)

	var smooth_progress := (
		progress
		* progress
		* (3.0 - 2.0 * progress)
	)

	global_position = (
		spawn_position
		+ direction.normalized()
		* EMERGE_DISTANCE
		* smooth_progress
	)

	var bubble_scale := lerpf(
		INITIAL_SCALE,
		FINAL_SCALE,
		smooth_progress
	)

	visual.scale = Vector2(
		bubble_scale,
		bubble_scale
	)

	if progress >= 1.0:

		start_launch()


# ==========================================
# START LAUNCH
# ==========================================

func start_launch() -> void:

	state = ProjectileState.LAUNCHING

	current_speed = INITIAL_SPEED

	collision_shape.set_deferred(
		"disabled",
		false
	)

	set_deferred(
		"monitoring",
		true
	)


# ==========================================
# PROJECTILE MOVEMENT
# ==========================================

func handle_launch(delta: float) -> void:

	current_speed = move_toward(
		current_speed,
		LAUNCH_SPEED,
		LAUNCH_ACCELERATION * delta
	)

	var movement := (
		direction.normalized()
		* current_speed
		* delta
	)

	global_position += movement

	distance_travelled += movement.length()

	if distance_travelled >= MAX_DISTANCE:

		queue_free()


# ==========================================
# CHECK SHOOTER COLLISION
# ==========================================

func is_shooter_collision(node: Node) -> bool:

	if not is_instance_valid(shooter):
		return false

	if node == shooter:
		return true

	if shooter.is_ancestor_of(node):
		return true

	return false


# ==========================================
# CAPTURE ENEMY
# ==========================================

func capture_enemy(enemy: Node2D) -> void:

	if state != ProjectileState.LAUNCHING:
		return

	if not is_instance_valid(enemy):
		return

	if not enemy.has_method("trap_by_bubble"):

		queue_free()
		return

	var success = enemy.call("trap_by_bubble")

	if not success:
		return

	state = ProjectileState.CAPTURING

	trapped_enemy = enemy

	global_position = enemy.global_position

	collision_shape.set_deferred(
		"disabled",
		true
	)

	set_deferred(
		"monitoring",
		false
	)

	# Membesarkan bubble
	var tween := create_tween()

	tween.tween_property(
		visual,
		"scale",
		Vector2(CAPTURE_SCALE, CAPTURE_SCALE),
		0.35
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	# Menahan bubble sebentar
	tween.tween_interval(0.15)

	# Bubble pecah
	tween.tween_property(
		visual,
		"scale",
		Vector2(0.05, 0.05),
		0.12
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_IN
	)

	tween.tween_callback(_finish_capture)


# ==========================================
# FINISH CAPTURE & GIVE REWARD
# ==========================================

func _finish_capture() -> void:

	# Berikan reward kepada Player
	if is_instance_valid(shooter):

		if shooter.has_method("add_energy"):

			shooter.call(
				"add_energy",
				ENERGY_REWARD
			)

		if shooter.has_method("add_coins"):

			shooter.call(
				"add_coins",
				COIN_REWARD
			)

	# Kalahkan musuh
	if is_instance_valid(trapped_enemy):

		if trapped_enemy.has_method("defeat_enemy"):

			trapped_enemy.call("defeat_enemy")

	queue_free()


# ==========================================
# COLLISION WITH BODY
# ==========================================

func _on_body_entered(body: Node2D) -> void:

	if state != ProjectileState.LAUNCHING:
		return

	if is_shooter_collision(body):
		return

	capture_enemy(body)


# ==========================================
# COLLISION WITH AREA
# ==========================================

func _on_area_entered(area: Area2D) -> void:

	if state != ProjectileState.LAUNCHING:
		return

	if is_shooter_collision(area):
		return

	# Area dapat menjadi child dari musuh
	if area.has_method("trap_by_bubble"):

		capture_enemy(area)
		return

	var enemy_parent := area.get_parent()

	if enemy_parent is Node2D:

		if enemy_parent.has_method("trap_by_bubble"):

			capture_enemy(enemy_parent)
