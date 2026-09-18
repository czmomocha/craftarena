class_name AuthoringEditorShellPointerCamera
extends RefCounted

## Editor 3D view: wheel zoom, right-drag orbit, Ctrl+left pan.
## Does not change D4 default distance / FOV; only the live view.

const MatchCameraViewGd := preload("res://src/client/match_camera_view.gd")


static func handle_button(
	chrome: AuthoringEditorShellChrome, mouse: InputEventMouseButton
) -> bool:
	if chrome == null or chrome.map == null:
		return false
	if _hits_gui(chrome, mouse.position):
		return false
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not mouse.pressed:
			return true
		var steps: int = 1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		return MatchCameraViewGd.try_zoom(chrome.map, steps)
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		return mouse.pressed
	if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and mouse.ctrl_pressed:
		chrome.camera_panning = true
		return true
	if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		chrome.camera_panning = false
	return false


static func handle_motion(
	chrome: AuthoringEditorShellChrome, motion: InputEventMouseMotion
) -> bool:
	if chrome == null or chrome.map == null:
		return false
	if (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		return MatchCameraViewGd.try_orbit(chrome.map, motion.relative)
	if chrome.camera_panning or (
		(motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and motion.ctrl_pressed
	):
		return MatchCameraViewGd.try_pan(chrome.map, motion.relative)
	return false


static func _hits_gui(chrome: AuthoringEditorShellChrome, _point: Vector2) -> bool:
	if chrome.window == null or not is_instance_valid(chrome.window):
		return false
	var hovered: Control = chrome.window.gui_get_hovered_control()
	if hovered == null:
		return false
	return hovered is BaseButton or hovered is SpinBox or hovered is OptionButton or hovered is ItemList
