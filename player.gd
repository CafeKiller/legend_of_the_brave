extends CharacterBody2D

enum State {
	IDEL, 			# 静置（默认）
	RUNNING,		# 跑动
	JUMP,			# 跳跃
	FALL,			# 下落
	LANDING,		# 完全下落，蹲下
	WALL_SLIDING,	# 蹬墙滑动
	WALL_JUMP,		# 蹬墙跳
}

# 位于地面的状态
const GROUND_STATES := [State.IDEL, State.RUNNING, State.LANDING];
# 移动速度
const RUN_SPEED := 160.0;
# 地面移动加速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.2;
# 空中移动加速度
const AIR_ACCELERATION := RUN_SPEED / 0.1;
# 跳跃加速度
const JUMP_VELOCITY := -320.0;
# 蹬墙跳加速度（向量）
const WALL_JUMP_VELOCITY := Vector2(380, -300);


# 重力 (此处读取项目设置中的默认值)
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float;
# 第一帧判断符
var is_first_tick := false;

@onready var graphice: Node2D = $Graphice
@onready var animation_player: AnimationPlayer = $AnimationPlayer;
@onready var coyote_timer: Timer = $CoyotTimer;
@onready var jump_request_timer: Timer = $JumpRequestTimer;
@onready var hand_checker: RayCast2D = $Graphice/HandChecker;
@onready var foot_checker: RayCast2D = $Graphice/FootChecker;
@onready var state_machines: Node = $StateMachines;

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
			hand_stand(delta, default_gravity);
			
		State.WALL_SLIDING:
			hand_move(default_gravity / 4, delta);
			# 在贴墙滑动时，获取当前墙面的法线向量，根据向量值来处理贴墙翻转
			graphice.scale.x = get_wall_normal().x;
			
		State.WALL_JUMP:
			if state_machines.state_time < 0.1:
				hand_stand(delta, 0.0 if is_first_tick else default_gravity);
				graphice.scale.x = get_wall_normal().x;
			else:
				hand_move(default_gravity, delta);
			pass
			
	is_first_tick = false;
	
# 获取最新状态
func get_next_state(state: State) -> State:
	
	var direction := Input.get_axis("move_left", "move_right");	
	# 判断玩家是否是静止的
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x);
	
	# 处理跳跃，并且获取当前跳跃状态： 是否为主动跳跃
	# var should_jump := (state == State.WALL_JUMP) if hand_jump() else hand_wall_jump();
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
			# 处于贴墙时，且手部碰撞检查器和脚部碰撞检查器同时触发	
			if can_wall_slide():
				return State.WALL_SLIDING;
				
		State.LANDING:
			if not is_still:
				return State.RUNNING;
			if not animation_player.is_playing():
				return State.IDEL;
				
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP;
			if is_on_floor():
				return State.IDEL;
			if not is_on_wall():
				return State.FALL;
				
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING;
			if velocity.y >= 0:
				return State.FALL;
				
	return state;
	
	
# 状态变化
func transition_state(from: State, to: State) -> void:
	
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	]);
	
	
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
			
		State.WALL_SLIDING:
			animation_player.play("wall_sliding");
		
		State.WALL_JUMP:
			animation_player.play("jump");
			velocity = WALL_JUMP_VELOCITY;
			velocity.x *= get_wall_normal().x;
			
	
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
		graphice.scale.x = -1 if direction < 0 else +1;
	
	move_and_slide();


func hand_stand(delta: float, gravity: float = default_gravity) -> void:
	velocity.x = move_toward(velocity.x, 0.0, current_use_acceleration() * delta);
	velocity.y += gravity * delta;
	
	move_and_slide();
	

# 处理跳跃
func hand_jump() -> bool:
	# 跳跃条件
	var can_jump := is_on_floor() or coyote_timer.time_left > 0;
	
	# 判断起跳条件
	if can_jump and jump_request_timer.time_left > 0:
		velocity.y = JUMP_VELOCITY;
		print("11111111")
		# 跳跃完毕后关闭定时器
		coyote_timer.stop();
		jump_request_timer.stop();
		return true; # true 表示主动跳跃
		
	return false;
	
# 处理蹬墙跳跃
func hand_wall_jump() -> bool:
	# 跳跃条件
	var can_jump := is_on_floor() or coyote_timer.time_left > 0;
	
	# 判断起跳条件
	if can_jump and jump_request_timer.time_left > 0:
		velocity = WALL_JUMP_VELOCITY;
		velocity.x *= get_wall_normal().x;
		# 跳跃完毕后关闭定时器
		jump_request_timer.stop();
		return true; # true 表示主动跳跃
		
	return false;

# 当前的使用的加速度	
func current_use_acceleration() -> float:
	if is_on_floor():
		return FLOOR_ACCELERATION;
	else:
		return AIR_ACCELERATION;
		
# 判断： 处于贴墙时，且手部碰撞检查器和脚部碰撞检查器同时触发	
func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding();


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
