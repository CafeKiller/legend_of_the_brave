extends CharacterBody2D

# 移动速度
const RUN_SPEED := 160.0;
# 地面移动加速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.2;
# 空中移动加速度
const AIR_ACCELERATION := RUN_SPEED / 0.02;
# 跳跃加速速度
const JUMP_VELOCITY := -320.0;


# 重力 (此处读取项目设置中的默认值)
var gravity := ProjectSettings.get("physics/2d/default_gravity") as float;

@onready var sprite_2d: Sprite2D = $Sprite2D;
@onready var animation_player: AnimationPlayer = $AnimationPlayer;
@onready var coyot_timer: Timer = $CoyotTimer;
@onready var jump_request_timer: Timer = $JumpRequestTimer;

# 输入监听
func _unhandled_input(event: InputEvent) -> void:
	# 是否跳跃
	if event.is_action_pressed("jump"):
		jump_request_timer.start();
	
	# 松开跳跃时，若当前起跳过高度没有达到最高的 2/1 则加速下落（存在小跳 / 大跳）
	if event.is_action_released("jump")	and velocity.y < JUMP_VELOCITY /2:
		velocity.y = JUMP_VELOCITY / 2;


func _physics_process(delta: float) -> void:
	
	# Input.get_axis 会返回一个介于 -1 - 1 之间的数值
	# 我们可以采用这个数值来做方向
	var direction := Input.get_axis("move_left", "move_right");
	
	# 位置移动
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, current_use_acceleration() * delta);
	velocity.y += gravity * delta;
	
	# 处理跳跃，并且获取当前跳跃状态： 是否为主动跳跃
	var should_jump := hand_jump();
	
	play_ani(direction);
	
	# 是否离开地面
	var was_on_floor := is_on_floor();
	move_and_slide();
	
	# 移动完毕后，对郊狼时间进行处理。
	hand_coyot_timer(was_on_floor, should_jump);


# 处理跳跃
func hand_jump() -> bool:
	# 跳跃条件
	var can_jump := is_on_floor() or coyot_timer.time_left > 0;
	
	# 判断起跳条件
	if can_jump and jump_request_timer.time_left > 0:
		velocity.y = JUMP_VELOCITY;
		
		# 跳跃完毕后关闭定时器
		coyot_timer.stop();
		jump_request_timer.stop();
		
		return true; # true 表示主动跳跃
	return false;


# 播放动画
func play_ani(direction: float):
	if is_on_floor():
		# is_zero_approx 可以校验数值是否为零，且修正float的精度问题
		if is_zero_approx(direction) and is_zero_approx(velocity.x):
			animation_player.play("idle");
		else:
			animation_player.play("running");
	else:
		animation_player.play("jump");
	
	if not is_zero_approx(direction):
		# 判断 direction 是否翻转镜像角色贴图
		sprite_2d.flip_h = direction < 0;


# 处理郊狼时间（郊狼时间即指：脱离地面边缘依旧存在跳跃时机）
func hand_coyot_timer(was_on_floor, should_jump):
	# 判断还是否在地面
	if was_on_floor and not should_jump:
		coyot_timer.start();
	else:
		coyot_timer.stop();


# 当前的使用的加速度	
func current_use_acceleration() -> float:
	if is_on_floor():
		return FLOOR_ACCELERATION;
	else:
		return AIR_ACCELERATION;
