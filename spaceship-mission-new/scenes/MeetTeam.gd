## MeetTeam.gd
## Финальная сцена встречи с командой.
## Грузится как инстанс внутри MainGame ($MiniGameLayer.add_child) — НЕ через
## change_scene_to_file (на AuroraOS-сборке после смены сцены ломался инпут).
##
## Порядок:
##   - сцена появляется → запускается красное мигание (~1.4с)
##   - после мигания первый тап → появляется Person
##   - тап → меняется фон
##   - тап → появляется панель капитана, TapCatcher выключается
##   - дальше управление через стрелочки в диалоговых панелях
##
## Анимация альфы оверлея и таймер мигания крутятся в _process(delta), без Tween
## и SceneTreeTimer — так надёжнее всего на этой сборке.
extends Node2D

enum Step { INITIAL, PERSON_SHOWN, BG_CHANGED, CAP_DIALOG, TEAM_DIALOG, CAP_DIALOG2, DONE }

var step: Step = Step.INITIAL

# ── Параметры мигания ──
const FLASH_UP:     float = 0.18
const FLASH_DOWN:   float = 0.28
const FLASH_CYCLES: int   = 3
const FLASH_PEAK_A: float = 0.45
const FLASH_TOTAL:  float = FLASH_CYCLES * (FLASH_UP + FLASH_DOWN)

var _flashing: bool = true                 # блокирует тапы пока крутится мигание
var _flash_elapsed: float = 0.0
var _flash_layer: CanvasLayer = null
var _flash_rect:  ColorRect   = null
var _last_tap_frame: int = -1               # дедуп тапов от двойного срабатывания

@onready var background:       TextureRect   = $Background
@onready var tap_catcher:      ColorRect     = $TapCatcher
@onready var person:           Sprite2D      = $Person
@onready var nav_button:       TextureButton = $Button

@onready var dialog_panel_cap: Panel         = $DialogPanelCap
@onready var cap_next_btn:     TextureButton = $DialogPanelCap/NextButton
@onready var cap_label:        RichTextLabel = $DialogPanelCap/DialogLabel

@onready var dialog_panel:     Panel         = $DialogPanel
@onready var team_next_btn:    TextureButton = $DialogPanel/NextButton
@onready var team_label:       RichTextLabel = $DialogPanel/DialogLabel

## Использовали `result_finalroomhappy.png` — но этот файл физически удалён,
## остался только сиротский .import (compress/mode=0 без etc2_astc-варианта).
## На десктопе работало по закешированному .ctex, на Android при экспорте
## ассет либо терялся, либо приходил в формате, несовместимом с GLES Compatibility,
## и `preload` возвращал null → подмена фона на втором тапе ломалась тихо.
## Актуальная версия — `_1`, импортирована корректно (s3tc_bptc + etc2_astc).
var tex_bg2 := preload("res://ImagesBackground/result_finalroomhappy_1.png") as Texture2D


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

	if not cap_next_btn.pressed.is_connected(_on_cap_next_pressed):
		cap_next_btn.pressed.connect(_on_cap_next_pressed)
	if not team_next_btn.pressed.is_connected(_on_team_next_pressed):
		team_next_btn.pressed.connect(_on_team_next_pressed)
	# TapCatcher — обычный ColorRect с прозрачным цветом и mouse_filter=STOP.
	# Это самый базовый Control, который гарантированно ловит инпут — у него нет
	# никаких внутренних стейтбоксов/фокус-логики, как у Button. Тапы по экрану
	# ловим через gui_input.
	if not tap_catcher.gui_input.is_connected(_on_tap_catcher_input):
		tap_catcher.gui_input.connect(_on_tap_catcher_input)

	_setup_flash_overlay()


func _setup_flash_overlay() -> void:
	var vp := get_viewport_rect().size
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 10
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.color    = Color(1.0, 0.0, 0.0, 0.0)
	_flash_rect.position = Vector2.ZERO
	_flash_rect.size     = vp
	# Обязательно IGNORE — иначе ColorRect перехватывает тапы.
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)


# Считаем альфу мигания вручную, без Tween. Цикл = FLASH_UP + FLASH_DOWN:
# 0..FLASH_UP — растим до FLASH_PEAK_A, FLASH_UP..(FLASH_UP+FLASH_DOWN) — гасим к 0.
# После FLASH_TOTAL секунд оверлей удаляется, тапы разблокируются.
func _process(delta: float) -> void:
	if not _flashing:
		return

	_flash_elapsed += delta
	if _flash_elapsed >= FLASH_TOTAL:
		if is_instance_valid(_flash_layer):
			_flash_layer.queue_free()
		_flash_layer = null
		_flash_rect = null
		_flashing = false
		return

	var cycle_len := FLASH_UP + FLASH_DOWN
	var t := fmod(_flash_elapsed, cycle_len)
	var a: float
	if t < FLASH_UP:
		a = lerp(0.0, FLASH_PEAK_A, t / FLASH_UP)
	else:
		a = lerp(FLASH_PEAK_A, 0.0, (t - FLASH_UP) / FLASH_DOWN)
	if is_instance_valid(_flash_rect):
		_flash_rect.color = Color(1.0, 0.0, 0.0, a)


# ── Один тап = один шаг вперёд (шаги 0–2). После CAP_DIALOG TapCatcher скрыт. ──
# Ловим через gui_input ColorRect'а — событие приходит обоими типами:
# и InputEventMouseButton, и InputEventScreenTouch (из-за emulate_*_from_*).
# Дедупим по кадру, иначе один тап продвинет сразу 2 шага.
func _on_tap_catcher_input(event: InputEvent) -> void:
	if _flashing:
		return
	if step >= Step.CAP_DIALOG:
		return

	var tapped := false
	if event is InputEventMouseButton:
		tapped = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tapped = event.pressed
	if not tapped:
		return

	var frame := Engine.get_process_frames()
	if frame == _last_tap_frame:
		return
	_last_tap_frame = frame

	tap_catcher.accept_event()
	_advance()


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
			tap_catcher.visible = false
			step = Step.CAP_DIALOG


# ── Стрелочка в панели капитана ───────────────────────────────────────────────
func _on_cap_next_pressed() -> void:
	dialog_panel_cap.visible = false
	if step == Step.CAP_DIALOG:
		dialog_panel.visible = true
		step = Step.TEAM_DIALOG
	elif step == Step.CAP_DIALOG2:
		nav_button.visible = true
		step = Step.DONE


# ── Стрелочка в панели команды ────────────────────────────────────────────────
func _on_team_next_pressed() -> void:
	dialog_panel.visible = false
	cap_label.text = "Теперь мы можем продолжить нашу миссию по исследованию глубокого космоса и поиску новых цивилизаций"
	dialog_panel_cap.visible = true
	step = Step.CAP_DIALOG2


# ── Кнопка перехода на следующую сцену ────────────────────────────────────────
func _on_nav_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/FinalScene.tscn")
