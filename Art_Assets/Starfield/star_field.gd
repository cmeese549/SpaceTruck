extends Node3D

@onready var star_sphere: MeshInstance3D

func _ready():
	setup_starfield()

func setup_starfield():
	# Create a large sphere with stars on the inside surface
	star_sphere = MeshInstance3D.new()
	add_child(star_sphere)
	
	# Create large sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 5000.0  # Very large radius
	sphere_mesh.height = 10000.0
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	star_sphere.mesh = sphere_mesh
	
	# Create material for starfield
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.cull_mode = BaseMaterial3D.CULL_FRONT  # Show inside of sphere
	material.emission_enabled = true
	
	# Create star texture procedurally
	var star_texture = create_star_texture()
	material.albedo_texture = star_texture
	material.emission_texture = star_texture
	material.emission_energy = 0.8
	
	star_sphere.material_override = material

func create_star_texture() -> ImageTexture:
	# Create a procedural star texture
	var image = Image.create(1024, 512, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	
	# Add random stars
	var rng = RandomNumberGenerator.new()
	rng.seed = 42  # Fixed seed for consistent stars
	
	# Generate stars with different sizes and colors
	for i in range(800):  # Number of stars
		var x = rng.randi_range(0, 1023)
		var y = rng.randi_range(0, 511)
		
		# Star color variation
		var star_color: Color
		var color_type = rng.randf()
		if color_type < 0.6:
			star_color = Color.WHITE  # Most stars are white
		elif color_type < 0.8:
			star_color = Color(0.9, 0.9, 1.0)  # Blue-white
		else:
			star_color = Color(1.0, 0.95, 0.8)  # Yellow-white
		
		# Star size (most are single pixels, some are slightly larger)
		var size = 1
		if rng.randf() < 0.1:  # 10% chance of larger star
			size = 2
		if rng.randf() < 0.02:  # 2% chance of even larger star
			size = 3
		
		# Draw star
		for sx in range(size):
			for sy in range(size):
				var px = min(x + sx, 1023)
				var py = min(y + sy, 511)
				image.set_pixel(px, py, star_color)
	
	# Create texture from image
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func simulate_movement(ship_velocity: Vector3):
	# Slowly rotate the star sphere to show movement through space
	# Stars are so far away that they barely move, just subtle rotation
	if star_sphere:
		star_sphere.rotation += ship_velocity * 0.00001  # Very subtle rotation
