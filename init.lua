--[[
------------------------------------------------------------------------------
Simple Tiled Implementation is licensed under the MIT Open Source License.
(http://www.opensource.org/licenses/mit-license.html)
------------------------------------------------------------------------------

Copyright (c) 2014 Landon Manning - LManning17@gmail.com - LandonManning.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local STI = {
	_LICENSE = "STI is distributed under the terms of the MIT license. See LICENSE.md.",
	_URL = "https://github.com/karai17/Simple-Tiled-Implementation",
	_VERSION = "0.9.8",
	_DESCRIPTION = "Simple Tiled Implementation is a Tiled Map Editor library designed for the *awesome* LÖVE framework."
}

local path = ... .. "." -- lol
local Map = require(path .. "map")
local framework

if love then
	framework = require(path .. "framework.love")
elseif corona then -- I don't think this works
	framework = require(path .. "framework.corona")
else
	framework = require(path .. "framework.pure")
end

function STI.new(map)
	map = map .. ".lua"

	-- Get path to map
	local path = map:reverse():find("[/\\]") or ""
	if path ~= "" then
		path = map:sub(1, 1 + (#map - path))
	end

	-- Load map
	map = framework.load(map)
	setfenv(map, {})
	map = setmetatable(map(), {__index = Map})

	map:init(path, framework)

	return map
end

-- http://wiki.interfaceware.com/534.html
function string.split(s, d)
	local magic = { "(", ")", ".", "%", "+", "-", "*", "?", "[", "^", "$" }

	for _, v in ipairs(magic) do
		if d == v then
			d = "%"..d
			break
		end
	end

	local t = {}
	local i = 0
	local f
	local match = '(.-)' .. d .. '()'

	if string.find(s, d) == nil then
		return {s}
	end

	for sub, j in string.gmatch(s, match) do
		i = i + 1
		t[i] = sub
		f = j
	end

	if i ~= 0 then
		t[i+1] = string.sub(s, f)
	end

	return t
end

return STI
