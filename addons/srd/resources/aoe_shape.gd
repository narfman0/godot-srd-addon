class_name AoEShape
extends Resource

@export var shape: SRD.AoEShape = SRD.AoEShape.SPHERE
@export var primary_size: int = 10   # radius for sphere/cylinder; length for cone/line/cube
@export var secondary_size: int = 0  # height for cylinder; width for line (default 5 ft)

static func make_sphere(radius: int) -> AoEShape:
	var s := AoEShape.new()
	s.shape = SRD.AoEShape.SPHERE
	s.primary_size = radius
	return s

static func make_cone(length: int) -> AoEShape:
	var s := AoEShape.new()
	s.shape = SRD.AoEShape.CONE
	s.primary_size = length
	return s

static func make_line(length: int, width: int = 5) -> AoEShape:
	var s := AoEShape.new()
	s.shape = SRD.AoEShape.LINE
	s.primary_size = length
	s.secondary_size = width
	return s

static func make_cube(side: int) -> AoEShape:
	var s := AoEShape.new()
	s.shape = SRD.AoEShape.CUBE
	s.primary_size = side
	return s

static func make_cylinder(radius: int, height: int) -> AoEShape:
	var s := AoEShape.new()
	s.shape = SRD.AoEShape.CYLINDER
	s.primary_size = radius
	s.secondary_size = height
	return s

## Approximate area in square feet (for GM reference / encounter balance tools).
func area_sq_ft() -> float:
	match shape:
		SRD.AoEShape.SPHERE:
			return PI * primary_size * primary_size
		SRD.AoEShape.CONE:
			return 0.5 * primary_size * primary_size  # 60° cone approximation
		SRD.AoEShape.LINE:
			return float(primary_size * (secondary_size if secondary_size > 0 else 5))
		SRD.AoEShape.CUBE:
			return float(primary_size * primary_size)
		SRD.AoEShape.CYLINDER:
			return PI * primary_size * primary_size
	return 0.0
