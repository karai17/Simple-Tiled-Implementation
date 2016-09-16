package = "Simple-Tiled-Implementation"
version = "v0.16.0.3-1"
source = {
   url = "https://github.com/karai17/Simple-Tiled-Implementation"
}
description = {
   homepage = "git+https://github.com/karai17/Simple-Tiled-Implementation",
   license = "MIT/X11"
}
dependencies = {
  "lua = 5.1" -- löve rely on luajit and thus on lua 5.1
}
build = {
   type = "builtin",
   modules = {
      ["sti.init"] = "sti/init.lua",
      ["sti.utils"] = "sti/utils.lua",
      ["sti.plugins.box2d"] = "sti/plugins/box2d.lua",
      ["sti.plugins.bump"] = "sti/plugins/bump.lua"
   },
   copy_directories = {"doc", "tests"}
}
