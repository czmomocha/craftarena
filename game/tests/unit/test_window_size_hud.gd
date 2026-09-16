extends GutTest

## Smoke: the overlay can be built and prints digits. No color/layout asserts.

const WindowSizeHudGd := preload("res://src/client/window_size_hud.gd")


func test_attach_writes_host_window_size() -> void:
	var host: Window = Window.new()
	host.size = Vector2i(1280, 720)
	add_child_autofree(host)
	var hud: Label = WindowSizeHudGd.attach(host)
	assert_not_null(hud)
	if hud == null:
		return
	assert_true(hud.visible)
	assert_false(hud.text.is_empty())
	assert_true(hud.text.contains("×"))


func test_attach_is_idempotent() -> void:
	var host: Window = Window.new()
	add_child_autofree(host)
	var first: Label = WindowSizeHudGd.attach(host)
	var second: Label = WindowSizeHudGd.attach(host)
	assert_eq(first, second)
	assert_eq(host.get_child_count(), 1)
