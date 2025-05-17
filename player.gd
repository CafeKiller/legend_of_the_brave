extends CharacterBody2D

const RUN_SPEED := 200.0;
const JUMP_VELOCITY := -300.0;

# 重力 (此处读取项目设置中的默认值)
var gravity := ProjectSettings.get("physics/2d/default_gravity") as float;

@onready var sprite_2d: Sprite2D = $Sprite2D;
@onready var animation_player: AnimationPlayer = $AnimationPlayer;

func _physics_process(delta: float) -> void:
	
	# Input.get_axis 会返回一个介于 -1 - 1 之间的数值
	# 我们可以采用这个数值来做方向
	var direction := Input.get_axis("move_left", "move_right");
	
	velocity.x = direction * RUN_SPEED;
	velocity.y += gravity * delta;
	
	hand_jump();
	
	play_ani(direction);
	
	move_and_slide();

# 处理跳跃
func hand_jump():
	# 判断起跳条件
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY;

# 播放动画
func play_ani(direction: float):
	if is_on_floor():
		if is_zero_approx(direction):
			animation_player.play("idle");
		else:
			animation_player.play("running");
	else:
		animation_player.play("jump");
	
	if not is_zero_approx(direction):
		# 判断 direction 是否翻转镜像角色贴图
		sprite_2d.flip_h = direction < 0;
