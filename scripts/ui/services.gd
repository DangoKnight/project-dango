extends "res://scripts/ui/screen.gd"

var services: SafeZoneServices
var inventory: GearInventory
var roster: Array[CharacterState] = []
var weapons: Array[WeaponDefinition] = []
var mode := ""
var player_goods: Array[GearInstance] = []
var offered_list: ItemList
var stock_list: ItemList
var feedback: Label
var exchange: Button
var ideas: ItemList
var requirements_label: Label
var accept_button: Button
var claim_button: Button


func _ready() -> void:
	$Panel.anchor_top = 0.08
	$Panel.anchor_right = 0.5
	$Panel.anchor_bottom = 0.92
	$Panel/Buttons/Subtitle.hide()
	super._ready()


func configure(service_state: SafeZoneServices, shared_inventory: GearInventory, characters: Array[CharacterState], weapon_stash: Array[WeaponDefinition], service_name: String) -> void:
	services = service_state
	inventory = shared_inventory
	roster = characters
	weapons = weapon_stash
	mode = service_name
	$Panel/Buttons/Title.text = mode
	if mode == "Barterer":
		services.talk()
		_build_barter()
	else:
		_build_tinkerer()
	$Panel/Buttons.move_child($Panel/Buttons/ReturnToHub, -1)


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = L10n.text(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.text(text)
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_barter() -> void:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$Panel/Buttons.add_child(columns)
	for title in ["Your offer", "Requested goods"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		_label(column, title)
		var list := ItemList.new()
		list.select_mode = ItemList.SELECT_MULTI
		list.gui_input.connect(_barter_input.bind(list))
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.multi_selected.connect(func(_index: int, _selected: bool): _quote())
		column.add_child(list)
		if title == "Your offer":
			offered_list = list
		else:
			stock_list = list
	feedback = _label($Panel/Buttons, L10n.text("Not acceptable"))
	exchange = _button($Panel/Buttons, "Exchange", _trade)
	_refresh_barter()


func _goods_label(item: GearInstance) -> String:
	var text := L10n.text(item.definition.display_name)
	if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
		text += L10n.text(" (%d uses)") % item.remaining_uses()
	var carrier := item.get_carrier() as CharacterState
	if carrier != null:
		text += " · " + L10n.text(carrier.definition.display_name)
	return text


func _refresh_barter() -> void:
	player_goods.clear()
	offered_list.clear()
	stock_list.clear()
	for item in inventory.get_items():
		if item.definition.kind in [GearDefinition.Kind.ARTIFACT, GearDefinition.Kind.CONSUMABLE]:
			player_goods.append(item)
			offered_list.add_item(_goods_label(item))
	for item in services.stock:
		stock_list.add_item(_goods_label(item) + (L10n.text(" · Unlimited") if item.definition.kind == GearDefinition.Kind.CONSUMABLE else ""))
	exchange.disabled = true


func _selected_goods(list: ItemList, goods: Array[GearInstance]) -> Array[GearInstance]:
	var result: Array[GearInstance] = []
	for index in list.get_selected_items():
		if index < goods.size():
			result.append(goods[index])
	return result


func _quote() -> void:
	var acceptable := services.trade_acceptable(_selected_goods(offered_list, player_goods), _selected_goods(stock_list, services.stock), inventory)
	feedback.text = L10n.text("Acceptable") if acceptable else L10n.text("Not acceptable")
	exchange.disabled = not acceptable


func _trade() -> void:
	var accepted := services.trade(_selected_goods(offered_list, player_goods), _selected_goods(stock_list, services.stock), inventory)
	_refresh_barter()
	feedback.text = L10n.text("Acceptable") if accepted else L10n.text("Not acceptable")


func _build_tinkerer() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Panel/Buttons.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_label(content, L10n.text("Equipment designs"))
	ideas = ItemList.new()
	ideas.custom_minimum_size.y = 100
	ideas.item_selected.connect(func(_index: int): _refresh_commission())
	content.add_child(ideas)
	requirements_label = _label(content, "")
	accept_button = _button(content, L10n.text("Accept commission"), _accept)
	claim_button = _button(content, L10n.text("Collect equipment"), _claim)
	feedback = _label(content, "")
	_refresh_tinkerer()


func _refresh_tinkerer() -> void:
	var selected := maxi(0, ideas.get_selected_items()[0]) if not ideas.get_selected_items().is_empty() else 0
	ideas.clear()
	for recipe in services.recipes:
		ideas.add_item(L10n.text(recipe.product_name()) + (L10n.text(" · Known design") if services.made_designs.has(recipe.product_key()) else L10n.text(" · Idea")))
	if ideas.item_count > 0:
		ideas.select(mini(selected, ideas.item_count - 1))
	_refresh_commission()


func _recipe() -> FabricationRecipe:
	var selected := ideas.get_selected_items()
	return services.recipes[selected[0]] if not selected.is_empty() else null


func _refresh_commission() -> void:
	var recipe := _recipe()
	accept_button.disabled = recipe == null
	claim_button.disabled = recipe == null or not services.commission_complete(recipe)
	if recipe == null:
		requirements_label.text = L10n.text("No designs available.")
		return
	claim_button.text = L10n.text("Collect medallion") if recipe.medallion != null else L10n.text("Collect weapon")
	var active := services.commissions.has(recipe.product_key())
	accept_button.disabled = active
	var needed: Dictionary = services.commissions[recipe.product_key()].requirements if active else services.requirements(recipe)
	var kills: Dictionary = services.commissions[recipe.product_key()].kills if active else {}
	var lines := PackedStringArray([L10n.text("Commission in progress") if active else L10n.text("Required enemies")])
	for species in needed:
		lines.append(L10n.text("%s: %d / %d") % [L10n.text(recipe.enemy_names.get(species, String(species).capitalize())), kills.get(species, 0), needed[species]])
	requirements_label.text = "\n".join(lines)


func _accept() -> void:
	if services.accept_commission(_recipe()):
		feedback.text = L10n.text("Commission accepted.")
	_refresh_commission()


func _claim() -> void:
	var recipe := _recipe()
	if recipe == null:
		return
	if recipe.medallion != null:
		if services.claim_medallion(recipe, inventory) != null:
			feedback.text = L10n.text("Medallion ready.")
	else:
		var weapon := services.claim_weapon(recipe)
		if weapon != null:
			weapons.append(weapon)
			feedback.text = L10n.text("Weapon ready.")
	_refresh_tinkerer()


func _barter_input(event: InputEvent, list: ItemList) -> void:
	# Let Godot handle Shift ranges, keyboard selection, and scrolling normally.
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.shift_pressed:
		return
	var index := list.get_item_at_position(event.position, true)
	if index < 0 or list.is_item_disabled(index) or not list.is_item_selectable(index):
		return
	var selected := not list.is_selected(index)
	var previous := list.get_selected_items()
	# A single select updates Godot's range anchor; restore the other selections.
	list.select(index)
	for old_index in previous:
		list.select(old_index, false)
	if not selected:
		list.deselect(index)
	list.multi_selected.emit(index, selected)
	list.item_clicked.emit(index, event.position, MOUSE_BUTTON_LEFT)
	list.accept_event()
