
extends CharacterBody2D

# =====================================
# PENGATURAN MUSUH
# =====================================

const PATROL_SPEED: float = 45.0
const CHASE_SPEED: float = 85.0
const ACCELERATION: float = 500.0

const PATROL_DISTANCE: float = 100.0
const DETECTION_RANGE: float = 260.0
const ATTACK_RANGE: float = 48.0
const ATTACK_HEIGHT: float = 55.0

const ATTACK_DAMAGE: int = 1
const ATTACK_COOLDOWN: float = 1.25

# Waktu musuh berada di dalam gelembung sebelum menghilang
const CAPTURE_DURATION: float = 0.85

const BODY_COLOR := Color(0.38, 0.12, 0.58, 1.0)
const EYE_COLOR := Color(0.1, 1.0, 1.0, 1.0)
const CAPTURE_COLOR := Color(0.4, 1.0, 1.0, 1.0)


# =====================================
# VARIABEL
# =====================================

var health: int = 1

var is_trapped: bool = false
var is_defeated: bool = false

var patrol_direction: int = 1
var home_x: float = 0.0

var attack_timer: float = 0.0

var gravity: float = float(
	ProjectSettings.get_setting("physics/2d/default_gravity")
)

var player_node: Node2D = null

var original_visual_scale: Vector2 = Vector2.ONE
var visual_tween: Tween = null


# =====================================
# NODE
# =====================================

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)

@onready var visual_node: Node2D = (
	get_node_or_null("Visual") as Node2D
)

@onready var eyes_node: Polygon2D = (
	get_node_or_null("Visual/Eyes") as Polygon2D
)


# =====================================
# READY
# =====================================

func _ready() -> void:
	home_x = global_position.x

	_setup_visual()

	if visual_node:
		original_visual_scale = visual_node.scale

	_find_player()

	print("Hollow Crawler berhasil muncul!")


# =====================================
# VISUAL MUSUH
# =====================================

func _setup_visual() -> void:
	if visual_node == null:
		push_warning("Node Visual tidak ditemukan!")
		return

	visual_node.visible = true

	var body := visual_node as Polygon2D

	if body == null:
		push_warning("Visual harus berupa Polygon2D!")
		return

	body.visible = true
	body.color = BODY_COLOR

	if body.polygon.is_empty():
		body.polygon = PackedVector2Array([
			Vector2(-18, 4),
			Vector2(-15, -7),
			Vector2(-9, -12),
			Vector2(-3, -10),
			Vector2(3, -15),
			Vector2(10, -11),
			Vector2(16, -6),
			Vector2(19, 3),
			Vector2(14, 10),
			Vector2(7, 14),
			Vector2(-4, 13),
			Vector2(-13, 10)
		])

	if eyes_node:
		eyes_node.visible = true
		eyes_node.color = EYE_COLOR

		if eyes_node.polygon.is_empty():
			eyes_node.polygon = PackedVector2Array([
				Vector2(-11, -5),
				Vector2(-6, -8),
				Vector2(-2, -4),
				Vector2(2, -4),
				Vector2(7, -8),
				Vector2(11, -5),
				Vector2(8, -1),
				Vector2(3, -2),
				Vector2(-3, -2),
				Vector2(-8, -1)
			])


# =====================================
# MENCARI PLAYER
# =====================================

func _find_player() -> void:
	var found_player = get_tree().get_first_node_in_group("player")

	if found_player is Node2D:
		player_node = found_player


# =====================================
# AI MUSUH
# =====================================

func _physics_process(delta: float) -> void:
	if is_trapped or is_defeated:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if not is_instance_valid(player_node):
		_find_player()

	if attack_timer > 0.0:
		attack_timer = maxf(attack_timer - delta, 0.0)

	if is_instance_valid(player_node):
		_update_player_detection(delta)
	else:
		_patrol(delta)

	move_and_slide()


# =====================================
# DETEKSI PLAYER
# =====================================

func _update_player_detection(delta: float) -> void:
	var distance_x: float = absf(
		player_node.global_position.x - global_position.x
	)

	var distance_y: float = absf(
		player_node.global_position.y - global_position.y
	)

	if distance_x <= DETECTION_RANGE and distance_y <= ATTACK_HEIGHT:

		if distance_x <= ATTACK_RANGE:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				ACCELERATION * delta
			)

			_attack_player()

		else:
			var direction: float = signf(
				player_node.global_position.x - global_position.x
			)

			velocity.x = direction * CHASE_SPEED

	else:
		_patrol(delta)


# =====================================
# PATROLI
# =====================================

func _patrol(delta: float) -> void:
	if global_position.x >= home_x + PATROL_DISTANCE:
		patrol_direction = -1

	elif global_position.x <= home_x - PATROL_DISTANCE:
		patrol_direction = 1

	velocity.x = move_toward(
		velocity.x,
		float(patrol_direction) * PATROL_SPEED,
		ACCELERATION * delta
	)


# =====================================
# SERANG PLAYER
# =====================================

func _attack_player() -> void:
	if attack_timer > 0.0:
		return

	if not is_instance_valid(player_node):
		return

	if not player_node.has_method("take_damage"):
		return

	attack_timer = ATTACK_COOLDOWN

	player_node.call("take_damage", ATTACK_DAMAGE, self)

	print("Hollow Crawler menyerang Player!")


# =====================================
# TERTANGKAP GELEMBUNG
# =====================================

func trap_by_bubble() -> void:
	if is_trapped or is_defeated:
		return

	is_trapped = true
	velocity = Vector2.ZERO

	# Matikan collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Hentikan AI
	set_physics_process(false)

	# Efek visual tertangkap
	if visual_node:
		if visual_tween and visual_tween.is_running():
			visual_tween.kill()

		visual_tween = create_tween()
		visual_tween.set_parallel(true)
		visual_tween.set_trans(Tween.TRANS_BACK)
		visual_tween.set_ease(Tween.EASE_OUT)

		visual_tween.tween_property(
			visual_node,
			"modulate",
			CAPTURE_COLOR,
			0.2
		)

		visual_tween.tween_property(
			visual_node,
			"scale",
			original_visual_scale * 1.2,
			0.2
		)

	print("Hollow Crawler tertangkap gelembung!")

	# Otomatis kalahkan musuh setelah durasi gelembung
	get_tree().create_timer(CAPTURE_DURATION).timeout.connect(
		_on_capture_timeout
	)


func _on_capture_timeout() -> void:
	if not is_inside_tree():
		return

	if is_trapped and not is_defeated:
		defeat_enemy()


# =====================================
# MUSUH DIKALAHKAN
# =====================================

func defeat_enemy() -> void:
	if is_defeated:
		return

	is_defeated = true
	is_trapped = true
	velocity = Vector2.ZERO

	set_physics_process(false)

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if visual_node:
		if visual_tween and visual_tween.is_running():
			visual_tween.kill()

		visual_tween = create_tween()
		visual_tween.set_parallel(true)
		visual_tween.set_trans(Tween.TRANS_BACK)
		visual_tween.set_ease(Tween.EASE_IN)

		visual_tween.tween_property(
			visual_node,
			"scale",
			Vector2.ZERO,
			0.25
		)

		visual_tween.tween_property(
			visual_node,
			"modulate:a",
			0.0,
			0.25
		)

		visual_tween.chain().tween_callback(
			Callable(self, "queue_free")
		)

	else:
		queue_free()

	print("Hollow Crawler berhasil dikalahkan!")
