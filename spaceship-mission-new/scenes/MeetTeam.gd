## MeetTeam.gd
## Финальная сцена встречи с командой
## Порядок: красное мигание → фон → Person → смена фона → DialogPanelCap → DialogPanel → Button
extends Node2D

enum Step { INITIAL, PERSON_SHOWN, BG_CHANGED, CAP_DIALOG, TEAM_DIALOG, CAP_DIALOG2, DONE }

var step: Step = Step.INITIAL
var _flashing: bool = true   # блокирует клики пока идёт мигание

@onready var background:       TextureRect   = $Background
@onready var person:           Sprite2D      = $Person
@onready var nav_button:       TextureButton = $Button

@onready var dialog_panel_cap: Panel         = $DialogPanelCap
@onready var cap_next_btn:     TextureButton = $DialogPanelCap/NextButton
@onready var cap_label:        RichTextLabel = $DialogPanelCap/DialogLabel

@onready var dialog_panel:     Panel         = $DialogPanel
@onready var team_next_btn:    TextureButton = $DialogPanel/NextButton
@onready var team_label:       RichTextLabel = $DialogPanel/DialogLabel

var tex_bg2 := preload("res://ImagesBackground/result_finalroomhappy.png") as Texture2D

func _ready() -> void:
	person.visible           = false
	nav_button.visible       = false
	dialog_panel_cap.visible = false
	dialog_panel.visible     = false

	# Дочерние ноды панелей могут быть скрыты в редакторе — показываем принудительно
	cap_label.visible    = true
	cap_next_btn.visible = true
	team_label.visible   = true
	team_next_btn.visible = true

	cap_label.text  = "Мы уже потеряли всю надежду! Кислорода оставалось на считанные минуты!"
	team_label.text = "Я устранил поломку - мы спасены."

	cap_next_btn.pressed.connect(_on_cap_next_pressed)
	team_next_btn.pressed.connect(_on_team_next_pressed)

	_start_red_flash()


func _start_red_flash() -> void:
	var vp   := get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var rect := ColorRect.new()
	rect.color    = Color(1.0, 0.0, 0.0, 0.0)
	rect.position = Vector2.ZERO
	rect.size     = vp
	layer.add_child(rect)

	var tw := create_tween()
	# 3 вспышки подряд (set_loops не используем — 0 = бесконечно в Godot 4)
	for _i in range(3):
		tw.tween_property(rect, "color:a", 0.45, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(rect, "color:a", 0.0,  0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tw.finished
	layer.queue_free()
	_flashing = false

# ── Клик по экрану продвигает сюжет на шагах 0-2 ─────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if step >= Step.CAP_DIALOG:
		return   # после открытия панели экранные клики уже не нужны

	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true

	if tapped:
		if _flashing:
			get_viewport().set_input_as_handled()
			return
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	match step:
		Step.INITIAL:
			person.visible = true
			step = Step.PERSON_SHOWN

		Step.PERSON_SHOWN:
			background.texture = tex_bg2
			step = Step.BG_CHANGED

		Step.BG_CHANGED:
			dialog_panel_cap.visible = true
			step = Step.CAP_DIALOG

# ── Стрелочка в панели капитана ───────────────────────────────────────────────
func _on_cap_next_pressed() -> void:
	dialog_panel_cap.visible = false
	if step == Step.CAP_DIALOG:
		# Первое сообщение капитана → открываем панель команды
		dialog_panel.visible = true
		step = Step.TEAM_DIALOG
	elif step == Step.CAP_DIALOG2:
		# Второе сообщение капитана → всё прочитано, показываем кнопку
		nav_button.visible = true
		step = Step.DONE

# ── Стрелочка в панели команды ────────────────────────────────────────────────
func _on_team_next_pressed() -> void:
	dialog_panel.visible = false
	# Снова открываем панель капитана с финальным сообщением
	cap_label.text           = "Теперь мы можем продолжить нашу миссию по исследованию глубокого космоса и поиску новых цивилизаций"
	dialog_panel_cap.visible = true
	step = Step.CAP_DIALOG2

# ── Кнопка перехода на следующую сцену (подключить позже) ─────────────────────
func _on_nav_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/FinalScene.tscn")
