package = "sti"
version = "dev-1"
source = {
	url = "git+https://github.com/karai17/Simple-Tiled-Implementation.git"
}
description = {
	summary = "Tiled library for LÖVE",
	detailed = [[
      Simple Tiled Implementation (STI) is a Tiled map loader and renderer
      designed for the LÖVE framework. It supports loading Tiled maps exported
      to Lua format and provides features like animated tiles, custom layers,
      object layers, and plugins for physics engines (Box2D, bump.lua).
   ]],
	homepage = "https://github.com/karai17/Simple-Tiled-Implementation",
	license = "MIT/X11"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		["sti"] = "sti/init.lua",
		["sti.atlas"] = "sti/atlas.lua",
		["sti.graphics"] = "sti/graphics.lua",
		["sti.utils"] = "sti/utils.lua",
		["sti.plugins.box2d"] = "sti/plugins/box2d.lua",
		["sti.plugins.bump"] = "sti/plugins/bump.lua",
	},
	copy_directories = {
		"doc",
	}
}
