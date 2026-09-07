class_name UiKit
extends RefCounted
## The UI design system.
##
## One place that decides what a card, a button, a pill and a bar look like.
## Screens compose these rather than styling controls themselves, which is what
## keeps the Orders board, the Shop and the printer sheets feeling like parts of
## one game instead of five separate menus.
##
## Sizing is mobile-first: touch targets are at least 44 px, type never drops
## below 11 px, and nothing assumes more width than a 360 px phone.

const TAP_MIN := 46.0
const RADIUS := 16.0
const RADIUS_LG := 24.0
const RADIUS_PILL := 999.0

const FONT_CAPTION := 11
const FONT_SMALL := 13
const FONT_BODY := 15
const FONT_TITLE := 18
const FONT_HERO := 24

const GAP_XS := 4
const GAP_SM := 8
const GAP_MD := 12
const GAP_LG := 16


static func flat(
	color: Color, radius: float = RADIUS, border: Color = Color.TRANSPARENT, border_width: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


## A card: the workhorse surface for order rows, shop rows and sheet sections.
static func card(padding: int = 14, color: Color = Palette.PAPER) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := flat(color, RADIUS, Palette.LINE, 1)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	# A soft lift so cards read as objects on the sky, not as flat blocks.
	box.shadow_color = Color(0.14, 0.20, 0.29, 0.10)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func label(
	text: String, font_size: int = FONT_BODY, color: Color = Palette.INK,
	bold: bool = false, clip: bool = false
) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if bold:
		# The variable Cairo face carries its own weights; an outline reads as
		# semibold without shipping a second font file.
		node.add_theme_constant_override("outline_size", 1)
		node.add_theme_color_override("font_outline_color", color)
	# Clipping keeps one long product name from widening the entire screen.
	node.clip_text = clip
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func title(text: String, font_size: int = FONT_TITLE) -> Label:
	return label(text, font_size, Palette.INK, true)


static func caption(text: String, color: Color = Palette.INK_SOFT) -> Label:
	return label(text, FONT_SMALL, color)


## Button kinds: primary (do it), secondary (an option), ghost (a quiet one),
## danger (reject / cancel).
static func button(text: String, kind: String = "primary", full_width: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0 if full_width else 88.0, TAP_MIN)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", FONT_BODY)
	if full_width:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill: Color
	var text_color: Color
	var border := Color.TRANSPARENT
	var border_width := 0
	match kind:
		"secondary":
			fill = Palette.PAPER
			text_color = Palette.INK
			border = Palette.LINE
			border_width = 2
		"ghost":
			fill = Color(1, 1, 1, 0)
			text_color = Palette.INK_SOFT
		"danger":
			fill = Palette.PAPER
			text_color = Palette.CORAL_DEEP
			border = Color(0.94, 0.44, 0.38, 0.5)
			border_width = 2
		"warm":
			fill = Palette.ORANGE
			text_color = Palette.PAPER
		_:
			fill = Palette.TEAL
			text_color = Palette.PAPER

	node.add_theme_stylebox_override("normal", flat(fill, RADIUS, border, border_width))
	node.add_theme_stylebox_override("hover", flat(Palette.tint(fill, 0.06), RADIUS, border, border_width))
	node.add_theme_stylebox_override("pressed", flat(Palette.shade(fill, 0.10), RADIUS, border, border_width))
	node.add_theme_stylebox_override("disabled", flat(Palette.SAND, RADIUS))
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", text_color)
	node.add_theme_color_override("font_pressed_color", text_color)
	node.add_theme_color_override("font_disabled_color", Palette.INK_FAINT)
	node.pressed.connect(func(): Audio.play("tap"))
	return node


## A small status chip: order state, material, colour, urgency.
static func pill(text: String, fill: Color, text_color: Color = Palette.PAPER) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := flat(fill, RADIUS_PILL)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(label(text, FONT_CAPTION, text_color, true))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return panel


static func hbox(separation: int = GAP_SM) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func vbox(separation: int = GAP_SM) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func vspace(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## A progress bar. Used for XP, print progress, spool fill and deadlines.
static func bar(value: float, fill: Color, height: float = 8.0, background: Color = Palette.SAND) -> ProgressBar:
	var node := ProgressBar.new()
	node.min_value = 0.0
	node.max_value = 1.0
	node.value = clampf(value, 0.0, 1.0)
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, height)
	node.add_theme_stylebox_override("background", flat(background, height * 0.5))
	node.add_theme_stylebox_override("fill", flat(fill, height * 0.5))
	return node


static func icon(name_id: String, color: Color = Palette.INK, box: float = 20.0) -> Icon:
	return Icon.new(name_id, color, box)


## A horizontal strip of choices — colour swatches, the printer picker. The
## scrollbar is hidden because the row is short and obviously swipeable; a bar
## under it just adds noise.
static func strip(height: float, separation: int = GAP_SM) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, height)
	scroll.get_h_scroll_bar().modulate.a = 0.0
	scroll.get_h_scroll_bar().custom_minimum_size = Vector2(0, 0)
	var row := hbox(separation)
	scroll.add_child(row)
	return {"scroll": scroll, "row": row}


## A scrolling column with the padding every screen shares — including room at
## the bottom so the last card clears the navigation bar.
static func screen_scroll(bottom_padding: float = 108.0) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GAP_LG)
	margin.add_theme_constant_override("margin_right", GAP_LG)
	margin.add_theme_constant_override("margin_top", GAP_MD)
	margin.add_theme_constant_override("margin_bottom", int(bottom_padding))
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var column := vbox(GAP_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	return {"scroll": scroll, "column": column}


## An empty state, so a screen with nothing in it still says something useful.
static func empty_state(icon_name: String, title_text: String, hint: String) -> Control:
	var column := vbox(GAP_SM)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var glyph := icon(icon_name, Palette.INK_FAINT, 52.0)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(vspace(28.0))
	column.add_child(glyph)

	var heading := label(title_text, FONT_BODY, Palette.INK_SOFT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var sub := label(hint, FONT_SMALL, Palette.INK_FAINT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	return column


## Colour a coin figure by whether the player can actually afford it.
static func price_color(cost: int) -> Color:
	return Palette.INK if GameState.coins() >= cost else Palette.CORAL_DEEP


## Apply the current language's direction to a subtree. The farm scene never
## calls this — only UI flows in RTL, the isometric geometry never mirrors.
static func apply_direction(root: Control) -> void:
	root.layout_direction = (
		Control.LAYOUT_DIRECTION_RTL if I18n.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	)
