extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var camera_2d: Camera2D = $Player/Camera2D

func _ready() -> void:
	
	hand_camera_limit();
	
# 处理相机限位，防止超出当前地图范围	
func hand_camera_limit():
	
	# get_used_rect 会获取当前地图所用到的包围矩形
	var used := tile_map.get_used_rect();
	var tile_size := tile_map.tile_set.tile_size;

	# camera_2d.limit_top = used.position.y * tile_size.y;
	camera_2d.limit_right = used.end.x * tile_size.x;
	camera_2d.limit_left = used.position.x * tile_size.x;
	camera_2d.limit_bottom = used.end.y * tile_size.y;
	
	# FIXBUG：首次加载时若位置处于边缘，相机会出现比较突兀的拉伸动画
	camera_2d.reset_smoothing();
