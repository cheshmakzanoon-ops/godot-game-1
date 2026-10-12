class_name NBPrintCache
extends RefCounted

# Rasterize static ink once per palette; keep all collision marks and pins live.
# Five palettes bound the cache to ten textures (~12 MB at logical resolution).
var textures: Dictionary = {}

func _circle(x: float, y: float, radius: float, color: Color, opacity: float = 1.0) -> String:
	return '<circle cx="%s" cy="%s" r="%s" fill="#%s" opacity="%s"/>' % [x, y, radius, color.to_html(false), opacity]

func _ring(radius: float, color: Color, width: float, opacity: float = 1.0) -> String:
	return '<circle cx="200" cy="200" r="%s" fill="none" stroke="#%s" stroke-width="%s" opacity="%s"/>' % [radius, color.to_html(false), width, opacity]

func texture(palette: Array, disc: bool) -> Texture2D:
	var key: String = str(disc) + palette[0].to_html()
	if textures.has(key):
		return textures[key]
	var base: Color = palette[0]
	var paper: Color = palette[1]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">' % [400 if disc else 480, 400 if disc else 854]
	if disc:
		svg += _circle(202, 211, 177, Color.BLACK, 0.30)
		svg += _circle(200, 200, 170, base.lightened(0.21))
		svg += _circle(200, 200, 166, paper.darkened(0.62))
		svg += _circle(200, 200, 161, base.darkened(0.35))
		svg += _ring(167, palette[2], 2.3)
		for groove in 15:
			svg += _ring(45 + float(groove) * 7.6, paper, 1.0, 0.035 if groove % 2 == 0 else 0.065)
		svg += _circle(200, 200, 44, palette[3]) + _circle(201, 202, 37, base.darkened(0.15))
		svg += _circle(200, 200, 32, paper) + _ring(38, palette[4], 2)
	else:
		svg += '<rect width="480" height="854" fill="#%s"/>' % base.to_html(false)
		for col in 9:
			var x := 24 + col * 54
			svg += '<path d="M%d 0V854" stroke="#%s" opacity=".025"/>' % [x, paper.to_html(false)]
		for row in 16:
			var y := 28 + row * 53
			svg += '<path d="M0 %dH480" stroke="#%s" opacity=".026"/>' % [y, paper.to_html(false)]
		for speck in 140:
			svg += _circle((speck * 137 + 41) % 479, (speck * 311 + 71) % 853, 0.55, paper, 0.09)
		svg += '<rect x="16" y="16" width="448" height="822" fill="none" stroke="#%s" opacity=".12"/>' % paper.to_html(false)
	var image := Image.new()
	if image.load_svg_from_string(svg + '</svg>') != OK:
		return null
	var result := ImageTexture.create_from_image(image)
	textures[key] = result
	return result
