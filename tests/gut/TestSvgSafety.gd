extends GutTest


func test_svg_safety_accepts_local_vector_markup() -> void:
	assert_true(SvgSafety.is_safe_markup("<svg><g><path d=\"M0 0 L10 10\" fill=\"#fff\"/></g></svg>"))


func test_svg_safety_blocks_script_and_event_handlers() -> void:
	assert_false(SvgSafety.is_safe_markup("<svg><script>alert(1)</script></svg>"))
	assert_false(SvgSafety.is_safe_markup("<svg><path onclick=\"alert(1)\" d=\"M0 0\"/></svg>"))


func test_svg_safety_blocks_external_and_embedded_references() -> void:
	assert_false(SvgSafety.is_safe_markup("<svg><use href=\"https://example.test/a.svg#x\"/></svg>"))
	assert_false(SvgSafety.is_safe_markup("<svg><image href=\"data:image/png;base64,abc\"/></svg>"))


func test_svg_safety_blocks_spaced_protocol_references_and_css_urls() -> void:
	assert_false(SvgSafety.is_safe_markup("<svg><use href = \"  https://example.test/a.svg#x\"/></svg>"))
	assert_false(SvgSafety.is_safe_markup("<svg><path style=\"fill:url( //example.test/pattern.svg#x )\"/></svg>"))
