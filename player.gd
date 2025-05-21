extends CharacterBody2D

enum State {
	IDEL,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
}

# 位于地面的状态
const GROUND_STATES := [State.IDEL, State.RUNNING, State.LANDING];
# 移动速度
const RUN_SPEED := 160.0;
# 地面移动加速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.2;
# 空中移动加速度
const AIR_ACCELERATION := RUN_SPEED / 0.02;
# 跳跃加速速度
const JUMP_VELOCITY := -320.0;


# 重力 (此处读取项目设置中的默认值)
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float;
# 第一帧判断符
var is_first_tick := false;

@onready var sprite_2d: Sprite2D = $Sprite2D;
@onready var animation_player: AnimationPlayer = $AnimationPlayer;
@onready var coyote_timer: Timer = $CoyotTimer;
@onready var jump_request_timer: Timer = $JumpRequestTimer;

# 输入监听
func _unhandled_input(event: InputEvent) -> void:
	# 是否跳跃
	if event.is_action_pressed("jump"):
		jump_request_timer.start();
	
	# 松开跳跃时，若当前起跳过高度没有达到最高的 2/1 则加速下落（存在小跳 / 大跳）
	if event.is_action_released("jump"):
		jump_request_timer.stop();	
		if velocity.y < JUMP_VELOCITY /2:
			velocity.y = JUMP_VELOCITY / 2;


func _physics_process(delta: float) -> void:
	
	# Input.get_axis 会返回一个介于 -1 - 1 之间的数值
	# 我们可以采用这个数值来做方向
	# var direction := Input.get_axis("move_left", "move_right");
	
	# 位置移动
	# velocity.x = move_toward(velocity.x, direction * RUN_SPEED, current_use_acceleration() * delta);
	# velocity.y += gravity * delta;
	
	# 处理跳跃，并且获取当前跳跃状态： 是否为主动跳跃
	# var should_jump := hand_jump();
	
	# play_ani(direction);
	
	# 是否离开地面
	# var was_on_floor := is_on_floor();
	# move_and_slide();
	
	# 移动完毕后，对郊狼时间进行处理。
	# hand_coyot_timer(was_on_floor, should_jump);
	pass;
	

# 自定义 更新函数	
func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDEL:
			hand_move(default_gravity, delta);
			
		State.RUNNING:
			hand_move(default_gravity, delta);
			
		State.JUMP:
			if(is_first_tick):
				hand_move(0.0, delta); # 第一帧时无视重力影响
			else:
				hand_move(default_gravity, delta);
			
		State.FALL:
			hand_move(default_gravity, delta);
			
		State.LANDING:
			hand_stand(delta);
			
	is_first_tick = false;
	
# 获取最新状态
func get_next_state(state: State) -> State:
	
	var direction := Input.get_axis("move_left", "move_right");	
	# 判断玩家是否是静止的
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x);
	
	# 处理跳跃，并且获取当前跳跃状态： 是否为主动跳跃
	var should_jump := hand_jump();
	if should_jump:
		return State.JUMP;
	
	match state:
		State.IDEL:
			if not is_on_floor(): # 不在地面
				return State.FALL;
			if not is_still: # 非静止不动
				return State.RUNNING;
			
		State.RUNNING:
			if not is_on_floor(): # 不在地面
				return State.FALL;
			if is_still: # 静止不动了
				return State.IDEL;
			
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL;
			
		State.FALL:
			# 处于地面时
			if is_on_floor(): 
				return State.LANDING if is_still else State.RUNNING;
				
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDEL;
				
	return state;
	
	
# 状态变化
func transition_state(from: State, to: State) -> void:
	
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop();
	
	match to:
		State.IDEL:
			animation_player.play("idle");
			
		State.RUNNING:
			animation_player.play("running");
			
		State.JUMP:
			animation_player.play("jump");
			
		State.FALL:
			animation_player.play("fall");
			if from in GROUND_STATES:
				coyote_timer.start();
				
		State.LANDING:
			animation_player.play("landing");
	
	is_first_tick = true;


# 处理移动
func hand_move(gravity: float, delta: float) -> void:	
	# Input.get_axis 会返回一个介于 -1 - 1 之间的数值
	# 我们可以采用这个数值来做方向
	var direction := Input.get_axis("move_left", "move_right");
	
	# 位置移动
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, current_use_acceleration() * delta);
	velocity.y += gravity * delta;
	
	if not is_zero_approx(direction):
		# 判断 direction 是否翻转镜像角色贴图
		sprite_2d.flip_h = direction < 0;
	
	move_and_slide();


func hand_stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, current_use_acceleration() * delta);
	velocity.y += default_gravity * delta;
	
	move_and_slide();
	

# 处理跳跃
func hand_jump() -> bool:
	# 跳跃条件
	var can_jump := is_on_floor() or coyote_timer.time_left > 0;
	
	# 判断起跳条件
	if can_jump and jump_request_timer.time_left > 0:
		velocity.y = JUMP_VELOCITY;
		
		# 跳跃完毕后关闭定时器
		coyote_timer.stop();
		jump_request_timer.stop();
		
		return true; # true 表示主动跳跃
	return false;

# 当前的使用的加速度	
func current_use_acceleration() -> float:
	if is_on_floor():
		return FLOOR_ACCELERATION;
	else:
		return AIR_ACCELERATION;


# 处理郊狼时间（郊狼时间即指：脱离地面边缘依旧存在跳跃时机）
#func hand_coyot_timer(was_on_floor, should_jump):
	## 判断还是否在地面
	#if was_on_floor and not should_jump:
		#coyot_timer.start();
	#else:
		#coyot_timer.stop();

		
# 播放动画
#func play_ani(direction: float):
	#if is_on_floor():
		## is_zero_approx 可以校验数值是否为零，且修正float的精度问题
		#if is_zero_approx(direction) and is_zero_approx(velocity.x):
			#animation_player.play("idle");
		#else:
			#animation_player.play("running");
	## 跳跃时 y 大于0 播放 jump 动画		
	#elif velocity.y < 0:
		#animation_player.play("jump");
	#else:
		## 否则默然播放下落动画
		#animation_player.play("fall");
	#
	#if not is_zero_approx(direction):
		## 判断 direction 是否翻转镜像角色贴图
		#sprite_2d.flip_h = direction < 0;
