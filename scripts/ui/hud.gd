extends CanvasLayer

var player_node: Node = null


# HUD PLAYER
@onready var health_label: Label = $HealthPanel/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $HealthPanel/VBoxContainer/HealthBar

@onready var energy_label: Label = $HealthPanel/VBoxContainer/EnergyLabel
@onready var energy_bar: ProgressBar = $HealthPanel/VBoxContainer/EnergyBar

@onready var coins_label: Label = $HealthPanel/VBoxContainer/CoinsLabel


# GAME OVER
@onready var game_over_overlay: Control = $GameOverOverlay

@onready var game_over_label: Label = $GameOverOverlay/CenterContainer/GameOverPanel/VBoxContainer/GameOverLabel

@onready var retry_button: Button = $GameOverOverlay/CenterContainer/GameOverPanel/VBoxContainer/RetryButton


func _ready() -> void:
	# HUD tetap aktif meskipun game sedang pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Sembunyikan Game Over saat permainan dimulai
	game_over_overlay.hide()

	# Atur tulisan
	game_over_label.text = "GAME OVER"
	retry_button.text = "PLAY AGAIN"

	# Hubungkan tombol Retry
	retry_button.pressed.connect(_on_retry_pressed)

	# Hubungkan Player
	call_deferred("_connect_player")


func _connect_player() -> void:
	var players = get_tree().get_nodes_in_group("player")

	if players.is_empty():
		push_warning("Player tidak ditemukan dalam group 'player'.")
		return

	player_node = players[0]

	# Hubungkan signal Health
	if player_node.has_signal("health_changed"):
		if not player_node.is_connected(
			"health_changed",
			Callable(self, "_on_health_changed")
		):
			player_node.connect(
				"health_changed",
				Callable(self, "_on_health_changed")
			)

	# Hubungkan signal Energy
	if player_node.has_signal("energy_changed"):
		if not player_node.is_connected(
			"energy_changed",
			Callable(self, "_on_energy_changed")
		):
			player_node.connect(
				"energy_changed",
				Callable(self, "_on_energy_changed")
			)

	# Hubungkan signal Coins
	if player_node.has_signal("coins_changed"):
		if not player_node.is_connected(
			"coins_changed",
			Callable(self, "_on_coins_changed")
		):
			player_node.connect(
				"coins_changed",
				Callable(self, "_on_coins_changed")
			)

	# Hubungkan signal Player Death
	if player_node.has_signal("player_died"):
		if not player_node.is_connected(
			"player_died",
			Callable(self, "_on_player_died")
		):
			player_node.connect(
				"player_died",
				Callable(self, "_on_player_died")
			)

	# Tampilkan status awal Player
	_update_initial_hud()


func _update_initial_hud() -> void:
	if player_node == null:
		return

	var current_health = int(player_node.get("health"))
	var max_health = int(player_node.call("get_max_health"))

	var current_energy = int(player_node.get("energy"))
	var max_energy = int(player_node.call("get_max_energy"))

	var total_coins = int(player_node.call("get_coins"))

	_on_health_changed(current_health, max_health)
	_on_energy_changed(current_energy, max_energy)
	_on_coins_changed(total_coins)


# =====================================
# HEALTH
# =====================================

func _on_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "HEALTH: %d / %d" % [
		current_health,
		max_health
	]

	health_bar.max_value = max_health
	health_bar.value = current_health


# =====================================
# ENERGY
# =====================================

func _on_energy_changed(current_energy: int, max_energy: int) -> void:
	energy_label.text = "ENERGY: %d / %d" % [
		current_energy,
		max_energy
	]

	energy_bar.max_value = max_energy
	energy_bar.value = current_energy


# =====================================
# COINS
# =====================================

func _on_coins_changed(total_coins: int) -> void:
	coins_label.text = "COINS: %d" % total_coins


# =====================================
# GAME OVER
# =====================================

func _on_player_died() -> void:
	game_over_overlay.show()

	# Hentikan permainan
	get_tree().paused = true

	print("GAME OVER")


# =====================================
# RETRY
# =====================================

func _on_retry_pressed() -> void:
	# Aktifkan kembali permainan
	get_tree().paused = false

	# Muat ulang Main Scene
	get_tree().reload_current_scene()
