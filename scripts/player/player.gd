
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal energy_changed(current_energy: int, max_energy: int)
signal coins_changed(total_coins: int)
signal player_died


# ==========================================
# MOVEMENT CONFIGURATION
# ==========================================

const WALK_SPEED: float = 180.0
const RUN_SPEED: float = 270.0

const ACCELERATION: float = 900.0
const FRICTION: float = 1100.0

const JUMP_VELOCITY: float = -420.0

const VISUAL_SCALE: float = 0.55
const VISUAL_OFFSET: Vector2 = Vector2(0, -13)


# ==========================================
# HEALTH CONFIGURATION
# ==========================================

const MAX_HEALTH: int = 5

const INVULNERABILITY_DURATION: float = 0.9
const KNOCKBACK_FORCE: float = 180.0

var health: int = MAX_HEALTH
var invulnerability_timer: float = 0.0
var damage_flash_timer: float = 0.0

var is_dead: bool = false
var game_over_emitted: bool = false


# ==========================================
# ENERGY CONFIGURATION
# ==========================================

const MAX_ENERGY: int = 100

var energy: int = 0


# ==========================================
# COINS CONFIGURATION
# ==========================================

var coins: int = 0


# ==========================================
# BUBBLE SHOOT CONFIGURATION
# ==========================================

const PROJECTILE_SCENE: PackedScene = preload(
    "res://scenes/projectiles/bubble_projectile.tscn"
)

const SHOOT_COOLDOWN: float = 0.85
const SHOOT_RELEASE_FRAME: int = 5

const SHOOT_OFFSET: Vector2 = Vector2(20, -8)

var shoot_cooldown_timer: float = 0.0
var shoot_pending: bool = false


# ==========================================
# CHARACTER STATE
# ==========================================

var gravity: float = ProjectSettings.get_setting(
    "physics/2d/default_gravity"
)

var facing_direction: int = 1
var locked_animation: String = ""

var sprite: AnimatedSprite2D = null

@onready var visual_root: Node2D = $Visual
@onready var shoot_point: Marker2D = $Visual/ShootPoint


# ==========================================
# FIND CHARACTER SPRITE
# ==========================================

func find_animated_sprite(node: Node) -> AnimatedSprite2D:

	for child in node.get_children():

		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D

		var found := find_animated_sprite(child)

		if found != null:
			return found

	return null


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	add_to_group("player")

	sprite = find_animated_sprite(self)

	if sprite == null:

		push_error("AnimatedSprite2D tidak ditemukan!")
		set_physics_process(false)
		return

	if sprite.sprite_frames == null:

		push_error("SpriteFrames belum dipasang!")
		set_physics_process(false)
		return

	sprite.scale = Vector2(
		VISUAL_SCALE,
		VISUAL_SCALE
	)

	sprite.position = VISUAL_OFFSET
	sprite.speed_scale = 1.0

	setup_animations()

	sprite.animation_finished.connect(
		_on_animation_finished
	)

	play_animation("idle")

	health_changed.emit(health, MAX_HEALTH)
	energy_changed.emit(energy, MAX_ENERGY)
	coins_changed.emit(coins)


# ==========================================
# PUBLIC DATA ACCESS
# ==========================================

func get_max_health() -> int:
	return MAX_HEALTH


func get_max_energy() -> int:
	return MAX_ENERGY


func get_coins() -> int:
	return coins


# ==========================================
# ENERGY SYSTEM
# ==========================================

func add_energy(amount: int) -> void:

	if is_dead or amount <= 0:
		return

	energy = mini(
		energy + amount,
		MAX_ENERGY
	)

	energy_changed.emit(
		energy,
		MAX_ENERGY
	)

	print("Player Energy: ", energy, "/", MAX_ENERGY)


# ==========================================
# COIN SYSTEM
# ==========================================

func add_coins(amount: int) -> void:

	if is_dead or amount <= 0:
		return

	coins += amount

	coins_changed.emit(coins)

	print("Player Coins: ", coins)


# ==========================================
# ANIMATION SETUP
# ==========================================

func setup_animations() -> void:

	var frames := sprite.sprite_frames

	var looping_animations := [
		"idle",
		"walk",
		"run",
        "shield"
	]

	var one_shot_animations := [
		"jump",
		"fall",
		"land",
		"shoot",
		"ultimate",
		"hurt",
		"death",
        "victory"
	]

	for anim in looping_animations:

		if frames.has_animation(anim):
			frames.set_animation_loop(anim, true)

	for anim in one_shot_animations:

		if frames.has_animation(anim):
			frames.set_animation_loop(anim, false)

	var animation_speeds := {
		"idle": 7.0,
		"walk": 7.0,
		"run": 9.0,
		"jump": 12.0,
		"fall": 8.0,
		"land": 10.0,
		"shoot": 9.0,
		"ultimate": 12.0,
		"shield": 10.0,
		"hurt": 10.0,
		"death": 8.0,
		"victory": 8.0
	}

	for anim in animation_speeds:

		if frames.has_animation(anim):

			frames.set_animation_speed(
				anim,
				animation_speeds[anim]
			)


# ==========================================
# PHYSICS PROCESS
# ==========================================

func _physics_process(delta: float) -> void:

	if is_dead:
		return

	var was_on_floor := is_on_floor()

	invulnerability_timer = maxf(
		invulnerability_timer - delta,
		0.0
	)

	shoot_cooldown_timer = maxf(
		shoot_cooldown_timer - delta,
		0.0
	)

	handle_gravity(delta)
	handle_movement(delta)
	handle_jump()
	handle_shoot()

	move_and_slide()

	if not was_on_floor and is_on_floor():

		velocity.x = 0.0

		play_locked_animation("land")

	update_shoot_release()
	update_animation()


# ==========================================
# DAMAGE FLASH
# ==========================================

func _process(delta: float) -> void:

	if sprite == null:
		return

	damage_flash_timer = maxf(
		damage_flash_timer - delta,
		0.0
	)

	if damage_flash_timer > 0.0:

		sprite.modulate = Color(
			1.0,
			0.4,
			0.4,
			1.0
		)

	else:

		sprite.modulate = Color.WHITE


# ==========================================
# HEALTH SYSTEM
# ==========================================

func take_damage(
	amount: int,
	attacker: Node2D = null
) -> void:

	if is_dead:
		return

	if invulnerability_timer > 0.0:
		return

	if amount <= 0:
		return

	health = maxi(
		health - amount,
		0
	)

	invulnerability_timer = INVULNERABILITY_DURATION
	damage_flash_timer = 0.18

	shoot_pending = false
	locked_animation = ""

	var knockback_direction: float = -float(facing_direction)

	if is_instance_valid(attacker):

		if attacker.global_position.x < global_position.x:
			knockback_direction = 1.0
		else:
			knockback_direction = -1.0

	velocity.x = knockback_direction * KNOCKBACK_FORCE

	health_changed.emit(health, MAX_HEALTH)

	print("Player Health: ", health, "/", MAX_HEALTH)

	if health > 0:

		play_locked_animation("hurt")

	else:

		die()


# ==========================================
# PLAYER DEATH
# ==========================================

func die() -> void:

	if is_dead:
		return

	is_dead = true

	shoot_pending = false
	locked_animation = ""

	velocity = Vector2.ZERO

	print("PLAYER DEFEATED - GAME OVER")

	set_physics_process(false)

	if sprite != null:

		if (
			sprite.sprite_frames.has_animation("death")
			and sprite.sprite_frames.get_frame_count("death") > 0
		):

			sprite.play("death")

		else:

			emit_player_died()

	else:

		emit_player_died()


# ==========================================
# EMIT GAME OVER SIGNAL
# ==========================================

func emit_player_died() -> void:

	if game_over_emitted:
		return

	game_over_emitted = true

	player_died.emit()


# ==========================================
# GRAVITY
# ==========================================

func handle_gravity(delta: float) -> void:

	if not is_on_floor():
		velocity.y += gravity * delta


# ==========================================
# MOVEMENT
# ==========================================

func handle_movement(delta: float) -> void:

	if locked_animation == "land":

		velocity.x = 0.0
		return

	if locked_animation == "hurt":

		velocity.x = move_toward(
			velocity.x,
			0.0,
			FRICTION * 0.35 * delta
		)

		return

	var direction := Input.get_axis(
		"move_left",
        "move_right"
	)

	var current_speed: float = WALK_SPEED

	if Input.is_action_pressed("run"):
		current_speed = RUN_SPEED

	if direction != 0:

		velocity.x = move_toward(
			velocity.x,
			direction * current_speed,
			ACCELERATION * delta
		)

		facing_direction = 1 if direction > 0 else -1

		sprite.flip_h = facing_direction < 0

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			FRICTION * delta
		)


# ==========================================
# JUMP
# ==========================================

func handle_jump() -> void:

	if locked_animation == "land":
		return

	if locked_animation == "hurt":
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():

		locked_animation = ""

		velocity.y = JUMP_VELOCITY

		play_animation("jump")


# ==========================================
# SHOOT INPUT
# ==========================================

func handle_shoot() -> void:

	if not Input.is_action_just_pressed("shoot"):
		return

	if locked_animation != "":
		return

	if shoot_cooldown_timer > 0.0:
		return

	if shoot_point == null:

		push_error("ShootPoint tidak ditemukan!")
		return

	shoot_pending = true

	shoot_cooldown_timer = SHOOT_COOLDOWN

	play_locked_animation("shoot")


# ==========================================
# SHOOT RELEASE TIMING
# ==========================================

func update_shoot_release() -> void:

	if not shoot_pending:
		return

	if sprite.animation != "shoot":
		return

	if sprite.frame >= SHOOT_RELEASE_FRAME:

		spawn_projectile()

		shoot_pending = false


# ==========================================
# SPAWN PROJECTILE FROM HAND
# ==========================================

func spawn_projectile() -> void:

	var projectile := PROJECTILE_SCENE.instantiate()

	if projectile == null:
		return

	var local_origin := shoot_point.position

	local_origin.x = (
		absf(local_origin.x)
		* float(facing_direction)
	)

	var hand_position := visual_root.to_global(
		local_origin
	)

	projectile.set(
		"direction",
		Vector2(facing_direction, 0)
	)

	projectile.set(
		"spawn_position",
		hand_position
	)

	projectile.set(
		"shooter",
		self
	)

	var scene_root := get_tree().current_scene

	if scene_root == null:

		projectile.free()
		return

	scene_root.add_child(projectile)


# ==========================================
# ANIMATION CONTROLLER
# ==========================================

func update_animation() -> void:

	if sprite == null:
		return

	if locked_animation != "":

		if sprite.animation == locked_animation and sprite.is_playing():
			return

		locked_animation = ""

	var target_animation := "idle"

	if not is_on_floor():

		if velocity.y < 0:
			target_animation = "jump"
		else:
			target_animation = "fall"

	else:

		if abs(velocity.x) > 15.0:

			if Input.is_action_pressed("run"):
				target_animation = "run"
			else:
				target_animation = "walk"

		else:

			target_animation = "idle"

	play_animation(target_animation)


# ==========================================
# PLAY ANIMATION
# ==========================================

func play_animation(animation_name: String) -> void:

	if sprite == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name:
		sprite.play(animation_name)


# ==========================================
# LOCKED ANIMATION
# ==========================================

func play_locked_animation(animation_name: String) -> void:

	if sprite == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	locked_animation = animation_name

	sprite.play(animation_name)


# ==========================================
# ANIMATION FINISHED
# ==========================================

func _on_animation_finished() -> void:

	# Tampilkan Game Over setelah animasi Death selesai
	if is_dead and sprite.animation == "death":

		emit_player_died()
		return

	if locked_animation == "":
		return

	if sprite.animation == locked_animation:

		locked_animation = ""
