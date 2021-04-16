extends KinematicBody2D

const DustEffect = preload("res://Effects/DustEffect.tscn")
const PlayerBullet = preload("res://Player/PlayerBullet.tscn")
const JumpEffect = preload("res://Effects/JumpEffect.tscn")

var PlayerStats = ResourceLoader.PlayerStats

export var ACCELERATION = 512 #加速度
export var MAX_SPEED = 64 #速度
export var FRICTION = 0.25 #摩擦力
export var GRAVITY = 200 #重力
export var JUMP_FORCE = 128 #跳跃力
export var MAX_SLOPE_ANGLE = 46  #倾斜角度
export var BULLET_SPEED = 250

var invincible = false setget set_invincible
var motion = Vector2.ZERO #初始速度0
var snap_vector = Vector2.ZERO
var just_jumped = false


onready var sprite = $Sprite
onready var spriteAnimator = $SpriteAnimator
onready var blinkAnimator = $BlinkAnimator
onready var coyoteJumpTimer = $CoyoteJumpTimer
onready var fireBulletTimer = $FireBulletTimer
onready var gun = $Sprite/PlayerGun
onready var muzzle = $Sprite/PlayerGun/Sprite/Muzzle

func set_invincible(value):
	invincible = value

func _ready():
	PlayerStats.connect("player_died", self, "_on_died")

#引用创建好的输入函数，保持简单的代码
func _physics_process(delta): 
	just_jumped = false
	var input_vector = get_input_vector()
	apply_horizontal_force(input_vector, delta) 
	apply_friction(input_vector)
	update_animations(input_vector)
	update_snap_vector()
	jump_check()
	move()
	apply_gravity(delta)
	
	if Input.is_action_just_pressed("fire") and fireBulletTimer.time_left == 0: #子弹冷却时间
		fire_bullet()

func fire_bullet():
	var bullet = Utils.instance_scene_on_main(PlayerBullet, muzzle.global_position)
	bullet.velocity = Vector2.RIGHT.rotated(gun.rotation) * BULLET_SPEED
	bullet.velocity.x *= sprite.scale.x
	bullet.rotation = bullet.velocity.angle()
	fireBulletTimer.start()

func create_dust_effect():
	var dust_position = global_position
	dust_position.x += rand_range(-4, 4)
	Utils.instance_scene_on_main(DustEffect, dust_position)


func get_input_vector():
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	return input_vector

func apply_horizontal_force(input_vector, delta):
	if input_vector.x != 0:
		motion.x += input_vector.x * ACCELERATION * delta
		motion.x = clamp(motion.x, -MAX_SPEED, MAX_SPEED)

func apply_friction(input_vector):
	if input_vector.x == 0 and is_on_floor():
		motion.x = lerp(motion.x, 0, FRICTION)

func update_snap_vector():
	if is_on_floor():
		snap_vector = Vector2.DOWN

func jump_check():
	if is_on_floor() or coyoteJumpTimer.time_left > 0:
		if Input.is_action_just_pressed("ui_up"):
			Utils.instance_scene_on_main(JumpEffect, global_position)
			motion.y = -JUMP_FORCE
			just_jumped = true
			snap_vector = Vector2.ZERO
	else:#小跳的设定
		if Input.is_action_just_released("ui_up")and motion.y < -JUMP_FORCE/2:#防止出现多余的跳
			motion.y = -JUMP_FORCE/2

func apply_gravity(delta):
	if not is_on_floor():
		motion.y += GRAVITY * delta
		motion.y = min(motion.y, JUMP_FORCE)
		
func update_animations(input_vector):
	sprite.scale.x = sign(get_local_mouse_position().x)
	if input_vector.x != 0:
		spriteAnimator.play("Run")
		spriteAnimator.playback_speed = input_vector.x * sprite.scale.x
	else:
		spriteAnimator.playback_speed = 1
		spriteAnimator.play("Idle")
		
	if not is_on_floor():
		spriteAnimator.play("Jump")

func move():
	var was_in_air = not is_on_floor()
	var was_on_floor = is_on_floor()
# warning-ignore:unused_variable
	var last_motion = motion
	var last_position = position
	
	motion = move_and_slide_with_snap(motion,snap_vector *4, Vector2.UP,true, 4, deg2rad(MAX_SLOPE_ANGLE))

	if was_on_floor and not is_on_floor()and not just_jumped:
		#着陆
		if was_in_air and is_on_floor():
			motion.x = last_position.x
			Utils.instance_scene_on_main(JumpEffect, global_position)
			
		
		#刚刚离开地面
		motion.y = 0
		position.y = last_position.y
		coyoteJumpTimer.start()
		
		#防止下滑
	if is_on_floor() and get_floor_velocity().length() == 0 and abs(motion.x) < 1:
		position.x = last_position.x


func _on_Hurtbox_hit(damage):
	if not invincible:
		PlayerStats.health -= damage
		blinkAnimator.play("Blink")

func _on_died():
	queue_free()
