class_name CWMapOverlay
extends Control

## Affichage de la carte du monde (jalon 1.10).
##
## Le dessin seulement : l'image, les marqueurs et le curseur sont calculés par
## `CWWorldMap`, sur un fil du pool, et déposés ici. Ce nœud ne consulte jamais
## le champ de terrain.
##
## Le curseur de 4 × 4 est celui de l'original, construit à la main dans
## `cube::WorldMap::ctor_1` : bordure `(10, 10, 10)`, centre blanc. C'est le seul
## visuel de la carte d'origine qui soit du code et non un asset, donc le seul
## qui se porte.

const CURSOR_BORDER: Color = Color8(10, 10, 10)
const CURSOR_FILL: Color = Color(1, 1, 1)

## Part de la hauteur de fenêtre occupée par la carte.
const FILL_RATIO: float = 0.82

var texture: ImageTexture = null
## Marqueurs rendus par `CWWorldMap.render_markers`, en pixels de l'image.
var markers: Array = []
## Position du joueur, en pixels de l'image (fractionnaire).
var player_pixel: Vector2 = Vector2.ZERO
var title: String = ""
var subtitle: String = ""

var _font: Font = null


func _ready() -> void:
	# Ancres **et** marges : poser les seules ancres laisse un noeud de taille
	# nulle sous un `CanvasLayer`, et tout le dessin part alors d'une origine
	# negative — la carte sort par le coin superieur gauche. Vu en jeu, pas dans
	# un test : un `Control` invisible ne fait echouer aucune verification.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_follow_viewport)
	_follow_viewport()


## La fenetre peut changer de taille ; la carte se recentre.
func _follow_viewport() -> void:
	size = get_viewport_rect().size
	queue_redraw()


## Dépose une vue calculée. À appeler sur le fil principal.
func show_view(image: Image, marks: Array, player: Vector2,
		head: String, sub: String) -> void:
	texture = ImageTexture.create_from_image(image)
	markers = marks
	player_pixel = player
	title = head
	subtitle = sub
	queue_redraw()


func _draw() -> void:
	var win: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, win), Color(0.04, 0.05, 0.07, 0.86))
	if texture == null:
		_draw_text(Vector2(win.x * 0.5 - 60.0, win.y * 0.5), "carte en cours...", 14,
				Color(1, 1, 1, 0.8))
		return

	var src: Vector2 = Vector2(texture.get_size())
	var scale: float = floorf(maxf(win.y * FILL_RATIO / src.y, 1.0))
	var span: Vector2 = src * scale
	var origin: Vector2 = ((win - span) * 0.5).floor()

	draw_texture_rect(texture, Rect2(origin, span), false)
	draw_rect(Rect2(origin, span), Color(1, 1, 1, 0.15), false, 2.0)

	for m: Dictionary in markers:
		_draw_marker(origin, scale, m)

	_draw_cursor(origin + player_pixel * scale, scale)

	_draw_text(Vector2(origin.x, origin.y - 26.0), title, 18, Color(1, 1, 1, 0.95))
	_draw_text(Vector2(origin.x, origin.y + span.y + 20.0), subtitle, 13,
			Color(1, 1, 1, 0.75))


## Le curseur du joueur : quatre cases, bordure sombre, centre blanc.
func _draw_cursor(at: Vector2, scale: float) -> void:
	var s: float = maxf(scale, 3.0) * 2.0
	var r := Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s))
	draw_rect(r, CURSOR_FILL)
	draw_rect(r, CURSOR_BORDER, false, maxf(scale * 0.5, 1.0))


func _draw_marker(origin: Vector2, scale: float, m: Dictionary) -> void:
	var p: Vector2 = origin + (Vector2(m["pixel"]) + Vector2(0.5, 0.5)) * scale
	var icon: int = m["icon"]
	var s: float = maxf(scale * 2.0, 5.0)
	match icon:
		CWWorldMap.ICON_VILLAGE:
			# Un carré plein, coiffé d'un toit : c'est le seul marqueur que le
			# joueur doit repérer d'un coup d'oeil.
			draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)),
					Color(0.96, 0.86, 0.55))
			draw_colored_polygon(PackedVector2Array([
					p + Vector2(-s * 0.7, -s * 0.5),
					p + Vector2(s * 0.7, -s * 0.5),
					p + Vector2(0.0, -s * 1.2)]), Color(0.78, 0.35, 0.28))
		CWWorldMap.ICON_SKULL:
			# Le crâne des donjons : un losange rouge, teinté par la difficulté.
			var d: float = clampf(float(m.get("difficulty", 0)) / 6.0, 0.0, 1.0)
			draw_colored_polygon(PackedVector2Array([
					p + Vector2(0.0, -s * 0.8), p + Vector2(s * 0.7, 0.0),
					p + Vector2(0.0, s * 0.8), p + Vector2(-s * 0.7, 0.0)]),
					Color(0.85, 0.25 + d * 0.35, 0.25))
		CWWorldMap.ICON_MOUNTAINS:
			draw_colored_polygon(PackedVector2Array([
					p + Vector2(-s * 0.8, s * 0.5), p + Vector2(0.0, -s * 0.8),
					p + Vector2(s * 0.8, s * 0.5)]), Color(0.9, 0.92, 0.96, 0.85))
		CWWorldMap.ICON_HILLS:
			draw_colored_polygon(PackedVector2Array([
					p + Vector2(-s * 0.8, s * 0.4), p + Vector2(0.0, -s * 0.35),
					p + Vector2(s * 0.8, s * 0.4)]), Color(0.85, 0.8, 0.6, 0.8))
		CWWorldMap.ICON_FOREST:
			draw_circle(p, s * 0.4, Color(0.2, 0.45, 0.25, 0.9))
		CWWorldMap.ICON_PLAINS:
			draw_circle(p, s * 0.22, Color(1, 1, 1, 0.35))

	if m.has("name") and scale >= 2.0:
		_draw_text(p + Vector2(-28.0, -s * 1.4), m["name"], 11,
				Color(1, 1, 1, 0.72))


func _draw_text(at: Vector2, text: String, px: int, color: Color) -> void:
	if _font == null or text == "":
		return
	# Un liseré sombre : la carte porte des teintes claires, et un texte blanc
	# posé dessus sans contour devient illisible sur la neige ou le sable.
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(_font, at + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
				Color(0, 0, 0, color.a * 0.8))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, color)
