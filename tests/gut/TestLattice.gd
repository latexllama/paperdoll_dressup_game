extends GutTest


func test_identity_lattice_keeps_control_points_stable() -> void:
	var bounds = {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0}
	var variation = {
		"rows": 2,
		"columns": 2,
		"bounds": bounds,
		"points": Lattice.create_identity_points(bounds, 2, 2),
	}

	assert_eq(Lattice.deform_lattice_point({"x": 5.0, "y": 5.0}, variation), {"x": 5.0, "y": 5.0})


func test_lattice_shape_validation_rejects_bad_point_count() -> void:
	var variation = {
		"rows": 2,
		"columns": 2,
		"bounds": {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
		"points": [{"x": 0.0, "y": 0.0}],
	}

	assert_gt(Lattice.validate_variation_shape(variation).size(), 0)


func test_lattice_path_deformation_moves_known_fixture_point() -> void:
	var variation = {
		"rows": 2,
		"columns": 2,
		"bounds": {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0},
		"points": [
			{"x": 0.0, "y": 0.0},
			{"x": 20.0, "y": 0.0},
			{"x": 0.0, "y": 10.0},
			{"x": 20.0, "y": 10.0},
		],
	}

	assert_eq(Lattice.deform_path_data("M 5 5 L 10 10", variation), "M10 5 L20 10")


func test_lattice_clamps_identity_divisions_and_keeps_malformed_path_unchanged() -> void:
	var bounds = {"x": 0.0, "y": 0.0, "width": 10.0, "height": 10.0}
	var points = Lattice.create_identity_points(bounds, 99, 99)
	assert_eq(points.size(), Lattice.MAX_DIVISIONS * Lattice.MAX_DIVISIONS)
	var variation = {
		"rows": 2,
		"columns": 2,
		"bounds": bounds,
		"points": Lattice.create_identity_points(bounds, 2, 2),
	}
	var malformed := "M0 0 L10"
	assert_eq(Lattice.deform_path_data(malformed, variation), malformed)
