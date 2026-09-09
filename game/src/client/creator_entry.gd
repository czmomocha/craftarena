class_name CreatorEntry
extends Node

## 玩家包里的创作入口（可玩性深化 轨 3「编辑调试」；M-Export 的 **Web 轻量 Edit**）。
##
## 存在的理由是分发链路上的一个洞：M2 之后编辑外壳一直只有两条路能打开——
## Godot 编辑器里的 `EditorPlugin`，或 `editor_sandbox.tscn` 的 F6。两条都要求
## 对方装了引擎、拉了仓库。于是「把链接发给外人」这件事只覆盖了游玩，**创作
## 一次也没被外人碰过**（CD-61 把它记为最大一块产品缺口）。本文件把同一个
## `AuthoringEditorShell` 挂进已导出的客户端主场景，浏览器里就能摆放 / 移动 /
## 调参 / Preview 试玩。
##
## **不是新的编辑器。** 写路径仍是 `AuthoringSession` + 三个已有 EDIT op，数据
## 仍是同一份 `AuthoringDocument`（CD-32 §1：桌面完整与 Web 轻量共用数据模型）。
## 本文件只决定「谁能打开它、用哪个 surface、窗口怎么摆、草稿存哪」。
##
## Surface 由平台决定，不由调用方挑：
##
## * Web ⇒ `web_light`——批量生成与验证器详情按 CD-32 关掉（`AuthoringSurfaceNames`
##   早就声明了这两条能力差，但在本刀之前没有任何一处真的执行）；
## * 其它已导出平台 ⇒ `desktop_full`；
## * `internal_dev` **不从这里给**。它是引擎内插件的 surface，带高级调试与批量
##   生成；玩家包里给出来等于把内部工具当产品发。
##
## 草稿走 `user://`（Web 上是浏览器存储）。刷新页面丢掉半小时的摆放是外人放弃
## 试用的最短路径，所以入口默认挂 `AuthoringDraftStore`。不上传、不签名——
## 云端草稿与发布属 M4b。

const AuthoringDraftStoreGd := preload("res://src/creator/authoring_draft_store.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")

## 玩家包里的草稿落点。与内部开发插件的 `user://authoring_draft.json` 分开：
## 同一台开发机上两条入口互相覆盖草稿，是没人能复现的丢失。
const DRAFT_PATH: String = "user://creator_draft.json"

var editor: AuthoringEditorShellGd = null
var draft_path: String = DRAFT_PATH
## 打开创作时把大厅窗口收起来。并排的 Editor + Preview 已经占满主视口，
## 底下再压一个最大化的大厅窗只会抢输入焦点。
var lobby_window: Window = null


## 已导出包能给出的 surface。`internal_dev` 不在候选里，理由见文件头。
static func surface_for_platform(web: bool) -> String:
	return AuthoringSurfaceNamesGd.WEB_LIGHT if web else AuthoringSurfaceNamesGd.DESKTOP_FULL


static func create(web: bool) -> CreatorEntry:
	var entry := new()
	entry.editor = AuthoringEditorShellGd.create(surface_for_platform(web))
	if entry.editor == null:
		return null
	return entry


## 懒建并挂到大厅壳下。绝大多数会话只游玩不创作，编辑外壳与 Preview 各带一个
## 3D 世界，不该在开局就建出来。已存在就原样返回。
static func ensure(shell: MatchLobbyShell, existing: CreatorEntry) -> CreatorEntry:
	if existing != null:
		return existing
	var entry: CreatorEntry = create(shell.web_platform)
	if entry == null:
		return null
	entry.lobby_window = shell.window
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return editor != null and editor.is_window_visible()


## 打开创作并立刻把 Preview 并排开出来。**Preview 不是可选项**：本入口服务的人
## 没有第二块屏、也没有引擎，摆完一格却不知道能不能走过去，等于没得编。
func try_open() -> bool:
	if editor == null:
		return false
	if not editor.is_inside_tree():
		if editor.draft_store == null:
			editor.draft_store = AuthoringDraftStoreGd.new(draft_path)
		add_child(editor)
	_bind_editor_closed()
	var opened: bool = editor.open() if not editor.is_window_visible() else editor.show_window()
	if not opened:
		return false
	editor.open_preview()
	_set_lobby_visible(false)
	return true


func try_close() -> bool:
	if editor == null:
		return false
	var lobby_hidden: bool = (
		lobby_window != null and is_instance_valid(lobby_window) and not lobby_window.visible
	)
	if not editor.is_window_visible() and not lobby_hidden:
		return false
	if editor.preview != null:
		editor.preview.hide_window()
	editor.hide_window()
	_set_lobby_visible(true)
	return true


func status_view() -> Dictionary:
	if editor == null:
		return {"surface": "", "open": false}
	var view: Dictionary = editor.status_view()
	view["open"] = is_open()
	return view


func _set_lobby_visible(visible: bool) -> void:
	if lobby_window == null or not is_instance_valid(lobby_window):
		return
	lobby_window.visible = visible


func _bind_editor_closed() -> void:
	if editor == null:
		return
	if not editor.window_closed.is_connected(_on_editor_window_closed):
		editor.window_closed.connect(_on_editor_window_closed)


func _on_editor_window_closed() -> void:
	if editor != null and editor.preview != null:
		editor.preview.hide_window()
	_set_lobby_visible(true)
