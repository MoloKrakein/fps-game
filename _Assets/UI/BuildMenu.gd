extends Control

const SLOT_NAMES: Array[String] = ["SLOT I", "SLOT II", "SLOT III"]
const BRANCH_NAMES: Array[String] = ["SWIFTNESS & AGILITY", "ARMOR & STAGGER", "FIELDCRAFT"]

var resolver: PlayerBuildResolver
var _selected_slot: int = 0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _slot_buttons: Array[Button] = []
var _deck_buttons: Array[Button] = []
var _skill_buttons: Dictionary = {}
var _slot_summary: Label
var _gadget_summary: Label
var _points_summary: Label
var _stats_summary: Label
var _feedback: Label
var _player_stats: PlayerStats
var _was_tree_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resolver = $BuildResolver
	_build_ui()
	hide()


func toggle() -> void:
	if visible:
		close_menu()
		return
	if not _ensure_player_stats():
		return

	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	get_tree().paused = _was_tree_paused
	Input.mouse_mode = _previous_mouse_mode
	hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()


func _ensure_player_stats() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("Build menu could not find a player in the 'player' group.")
		return false
	var stats := player.get_node_or_null("PlayerStats") as PlayerStats
	if stats == null:
		push_warning("Build menu could not find PlayerStats on the player.")
		return false

	if _player_stats != stats:
		_player_stats = stats
		resolver.bind_player_stats(stats)
	if not resolver.build_changed.is_connected(_refresh):
		resolver.build_changed.connect(_refresh)
	return true


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.02, 0.03, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36.0
	panel.offset_top = 28.0
	panel.offset_right = -36.0
	panel.offset_bottom = -28.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#111820")
	panel_style.border_color = Color("#385263")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	_build_header(content)
	content.add_child(HSeparator.new())
	_build_columns(content)
	content.add_child(HSeparator.new())
	_build_preview(content)


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	parent.add_child(header)

	var title := Label.new()
	title.text = "FIELD OPERATIVE  /  BUILD CONFIGURATION"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#d8eaf2"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_points_summary = Label.new()
	_points_summary.add_theme_font_size_override("font_size", 18)
	_points_summary.add_theme_color_override("font_color", Color("#8ee0c1"))
	header.add_child(_points_summary)

	var reset_button := Button.new()
	reset_button.text = "RESET BUILD"
	reset_button.pressed.connect(_on_reset_pressed)
	header.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "RESUME  [ESC]"
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)


func _build_columns(parent: VBoxContainer) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(columns)

	var perk_column := VBoxContainer.new()
	perk_column.custom_minimum_size.x = 390.0
	perk_column.add_theme_constant_override("separation", 10)
	columns.add_child(perk_column)
	_add_section_title(perk_column, "PERK DECK  /  THREE-SLOT RESOLVER")

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	perk_column.add_child(slot_row)
	for slot: int in range(SLOT_NAMES.size()):
		var slot_button := Button.new()
		slot_button.toggle_mode = true
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.pressed.connect(_on_slot_selected.bind(slot))
		_slot_buttons.append(slot_button)
		slot_row.add_child(slot_button)

	_slot_summary = Label.new()
	_slot_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_summary.custom_minimum_size.y = 48.0
	_slot_summary.add_theme_color_override("font_color", Color("#b6c8d2"))
	perk_column.add_child(_slot_summary)

	var deck_title := Label.new()
	deck_title.text = "SELECT A DECK FOR THE ACTIVE SLOT"
	deck_title.add_theme_color_override("font_color", Color("#8ee0c1"))
	perk_column.add_child(deck_title)
	for deck: PerkDeckData in resolver.perk_decks:
		var deck_button := Button.new()
		deck_button.custom_minimum_size.y = 48.0
		deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_button.pressed.connect(_on_deck_selected.bind(deck.deck_id))
		_deck_buttons.append(deck_button)
		perk_column.add_child(deck_button)

	var clear_slot_button := Button.new()
	clear_slot_button.text = "CLEAR ACTIVE SLOT"
	clear_slot_button.pressed.connect(_on_clear_slot_pressed)
	perk_column.add_child(clear_slot_button)

	_gadget_summary = Label.new()
	_gadget_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gadget_summary.add_theme_color_override("font_color", Color("#f0c879"))
	perk_column.add_child(_gadget_summary)

	var skill_column := VBoxContainer.new()
	skill_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_column.add_theme_constant_override("separation", 8)
	columns.add_child(VSeparator.new())
	columns.add_child(skill_column)
	_add_section_title(skill_column, "NORMAL SKILL TREE  /  PREREQUISITES")

	var skill_scroll := ScrollContainer.new()
	skill_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_column.add_child(skill_scroll)

	var branches := HBoxContainer.new()
	branches.add_theme_constant_override("separation", 12)
	skill_scroll.add_child(branches)
	for branch: int in range(BRANCH_NAMES.size()):
		var branch_column := VBoxContainer.new()
		branch_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch_column.custom_minimum_size.x = 190.0
		branch_column.add_theme_constant_override("separation", 8)
		branches.add_child(branch_column)
		_add_section_title(branch_column, BRANCH_NAMES[branch])
		for skill: SkillNodeData in resolver.skill_nodes:
			if skill.branch != branch:
				continue
			var skill_button := Button.new()
			skill_button.custom_minimum_size.y = 58.0
			skill_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			skill_button.tooltip_text = skill.description
			skill_button.pressed.connect(_on_skill_pressed.bind(skill.node_id))
			_skill_buttons[skill.node_id] = skill_button
			branch_column.add_child(skill_button)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_color_override("font_color", Color("#e6a58e"))
	skill_column.add_child(_feedback)


func _build_preview(parent: VBoxContainer) -> void:
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 4)
	parent.add_child(preview_column)
	_add_section_title(preview_column, "LIVE PLAYER STAT PREVIEW")
	_stats_summary = Label.new()
	_stats_summary.add_theme_color_override("font_color", Color("#c1d5df"))
	_stats_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_column.add_child(_stats_summary)


func _add_section_title(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#74c9b0"))
	parent.add_child(label)


func _on_slot_selected(slot: int) -> void:
	_selected_slot = slot
	_feedback.text = ""
	_refresh()


func _on_deck_selected(deck_id: StringName) -> void:
	if not resolver.select_perk(_selected_slot, deck_id):
		_feedback.text = "Choose the previous slot first; slots resolve in order."
	_refresh()


func _on_clear_slot_pressed() -> void:
	resolver.clear_perk_slot(_selected_slot)
	_feedback.text = ""
	_refresh()


func _on_skill_pressed(node_id: StringName) -> void:
	if not resolver.purchase_skill(node_id):
		_feedback.text = "This node is locked, already owned, or you need more skill points."
	else:
		_feedback.text = ""
	_refresh()


func _on_reset_pressed() -> void:
	resolver.reset_build()
	_selected_slot = 0
	_feedback.text = "Build reset."
	_refresh()


func _refresh() -> void:
	if resolver == null:
		return
	for slot: int in range(_slot_buttons.size()):
		var deck := resolver.get_slot_deck(slot)
		var slot_text := SLOT_NAMES[slot]
		if deck == null:
			slot_text += "\n-- EMPTY --"
		else:
			slot_text += "\n%s  T%d" % [deck.display_name, resolver.get_slot_tier(slot)]
		_slot_buttons[slot].text = slot_text
		_slot_buttons[slot].button_pressed = slot == _selected_slot

	var active_deck := resolver.get_slot_deck(_selected_slot)
	if active_deck == null:
		_slot_summary.text = "%s is empty. Select a deck below." % SLOT_NAMES[_selected_slot]
	else:
		var tier := resolver.get_slot_tier(_selected_slot)
		_slot_summary.text = (
			"%s  /  %s\nT%d - %s"
			% [
				active_deck.display_name,
				active_deck.archetype_tag,
				tier,
				active_deck.get_tier_summary(tier),
			]
		)

	for index: int in range(_deck_buttons.size()):
		var deck := resolver.perk_decks[index]
		var deck_tier := resolver.get_deck_tier(deck.deck_id)
		var suffix := "  |  ACTIVE T%d" % deck_tier if deck_tier > 0 else ""
		_deck_buttons[index].text = (
			"%s  [%s]%s"
			% [
				deck.display_name,
				deck.signature_gadget_name,
				suffix,
			]
		)
	_gadget_summary.text = "ROLE GADGET  /  %s" % resolver.get_active_gadget_name()

	_points_summary.text = (
		"SKILL POINTS  %d / %d"
		% [
			resolver.get_unspent_skill_points(),
			resolver.starting_skill_points,
		]
	)
	for skill_id: StringName in _skill_buttons:
		var skill := resolver.get_skill_node(skill_id)
		if skill == null:
			continue
		var button: Button = _skill_buttons[skill_id]
		var purchased := resolver.is_skill_purchased(skill_id)
		var can_purchase := resolver.can_purchase_skill(skill_id)
		var state := "OWNED" if purchased else "AVAILABLE" if can_purchase else "LOCKED"
		button.text = "%s  |  %d SP  |  %s" % [skill.display_name, skill.point_cost, state]
		button.disabled = purchased or not can_purchase

	if _player_stats != null:
		_stats_summary.text = (
			(
				"ARMOR  %.0f     SWIFTNESS  %.0f     DODGE (MOVE)  %.0f%%     CRIT  %.0f%%"
				+ "\nIMPACT  %.2f     RELOAD  %.2f     DAMAGE  %.2f     ACTIVE SKILLS  %d"
			)
			% [
				_player_stats.get_stat("max_armor", 0.0),
				_player_stats.get_stat("swiftness", 0.0),
				_player_stats.get_stat("dodge_chance_moving", 0.0) * 100.0,
				_player_stats.get_stat("crit_chance", 0.0) * 100.0,
				_player_stats.get_stat("impact_multiplier", 1.0),
				_player_stats.get_stat("reload_speed", 1.0),
				_player_stats.get_stat("damage_modifier", 1.0),
				resolver.purchased_skill_ids.size(),
			]
		)
