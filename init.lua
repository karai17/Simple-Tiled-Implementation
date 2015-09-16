-- @author Landon Manning
-- @copyright 2015
-- @license MIT/X11

local STI = {
	_LICENSE     = "STI is distributed under the terms of the MIT license. See LICENSE.md.",
	_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	_VERSION     = "0.13.1.1",
	_DESCRIPTION = "Simple Tiled Implementation is a Tiled Map Editor library designed for the *awesome* LÖVE framework."
}

local path = (...):gsub('%.init$', '') .. "."
local Map  = require(path .. "map")
local framework

if love then
	framework = require(path .. "framework.love")
else
	framework = require(path .. "framework.lua")
end

--- Instance a new map.
-- @param path Path to the map file.
-- @param plugins A list of plugins to load.
-- @return table The loaded Map.
function STI.new(map, plugins)
	-- Check for valid map type
	local ext = map:sub(-4, -1)
	assert(ext == ".lua", string.format(
		"Invalid file type: %s. File must be of type: lua.",
		ext
	))

	-- Get path to map
	local path = map:reverse():find("[/\\]") or ""
	if path ~= "" then
		path = map:sub(1, 1 + (#map - path))
	end

	-- Load map
	map = framework.load(map)
	setfenv(map, {})
	map = setmetatable(map(), {__index = Map})

	map:init(path, framework, plugins)

	return map
end

return STI
