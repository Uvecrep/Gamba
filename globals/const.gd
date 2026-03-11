extends Node
# autoload singleton to hold miscellaneous const values

enum COLLISION_LAYERS {
	WORLD = 1 << 0, 
	PLAYER = 1 << 1, 
	ENEMY = 1 << 2, 
	SUMMON = 1 << 3, 
	PICKUP = 1 << 4
}
