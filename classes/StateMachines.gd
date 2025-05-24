class_name StateMachines
extends Node

# 有限状态机

# 当前状态
var current_state: int = -1: 
	set(v):
		owner.transition_state(current_state, v);
		current_state = v;
		state_time = 0; # 重置

# 状态持续时间
var state_time := 0.0;

# 初始化
func _ready() -> void:
	await owner.ready;
	current_state = 0;


func _physics_process(delta: float) -> void:
	# 时刻监听状态变化
	while true:
		# 状态变化通过父节点上的 get_next_state() 决定
		var next := owner.get_next_state(current_state) as int;
		if current_state == next: # 与上轮相同，无视
			break;
		current_state = next; # 与上轮不同，更新
	
	# 将获取的新状态更新到父节点， 让父节点进行对应画面处理。	
	owner.tick_physics(current_state, delta);
	state_time += delta;
