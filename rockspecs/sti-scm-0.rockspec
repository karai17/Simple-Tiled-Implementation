package = 'sti'
version = 'scm-0'
source = {
	url = 'git+https://github.com/karai17/Simple-Tiled-Implementation/',
}
description = {
	summary = 'Simple Tiled Implementation is a Tiled map loader and renderer designed for the awesome LÖVE framework.',
	homepage = 'https://github.com/karai17/Simple-Tiled-Implementation',
	license = 'MIT',
}
dependencies = {
	'lua ~> 5.1',
}
build = {
	type = 'builtin',
	modules = {
		['sti'] = 'sti/init.lua',
		['sti.graphics'] = 'sti/graphics.lua',
		['sti.plugins.box2d'] = 'sti/plugins/box2d.lua',
		['sti.plugins.bump'] = 'sti/plugins/bump.lua',
		['sti.utils'] = 'sti/utils.lua',
	}
}
