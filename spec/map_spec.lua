package.cpath = package.cpath .. ";/usr/lib/lib?.so;/usr/lib64/lib?.so"

require "love"
require "love.window"
require "love.graphics"
require "love.image"
require "love.filesystem"

local function get_low(a)
	local m = math.huge
	for k,v in pairs(a) do
		if k < m then m = k end
	end
	return a[m]
end

love.filesystem.init(get_low(arg))
love.filesystem.setSource(love.filesystem.getWorkingDirectory())
love.window.setMode(1, 1)

local sti = require "sti.init"

describe("STI Map Data:", function()
	local function verify_conversion_to_pixel(map, ix, iy, ox, oy)
		local x, y = map:convertTileToPixel(ix, iy)
		assert.is.equal(x, ox)
		assert.is.equal(y, oy)
	end

	local function verify_conversion_to_tile(map, ix, iy, ox, oy)
		local x, y = map:convertPixelToTile(ix, iy)
		assert.is.equal(x, ox)
		assert.is.equal(y, oy)
	end

	it("converts between ortho and world space", function()
		local map = sti("tests/ortho.lua")

		verify_conversion_to_pixel(map, 3, 4, 96, 128)
		verify_conversion_to_pixel(map, 3.5, 4.5, 112, 144)
		verify_conversion_to_pixel(map, 4, 5, 128, 160)

		verify_conversion_to_tile(map, 96, 128, 3, 4)
		verify_conversion_to_tile(map, 112, 144, 3.5, 4.5)
		verify_conversion_to_tile(map, 128, 160, 4, 5)
	end)

	it("converts between iso and world space", function()
		local map = sti("tests/iso.lua")

		verify_conversion_to_pixel(map, 3, 4, 460, 644)
		verify_conversion_to_pixel(map, 3.5, 4.5, 460, 736)
		verify_conversion_to_pixel(map, 4, 5, 460, 828)

		verify_conversion_to_tile(map, 460, 644, 3, 4)
		verify_conversion_to_tile(map, 460, 736, 3.5, 4.5)
		verify_conversion_to_tile(map, 460, 828, 4, 5)
	end)

	it("converts between stag and world space", function()
		local map = sti("tests/stag.lua")

		verify_conversion_to_pixel(map, 3, 4, 552, 460)
		verify_conversion_to_pixel(map, 3.5, 4.5, 644, 506)
		verify_conversion_to_pixel(map, 4, 5, 736, 552)

		verify_conversion_to_tile(map, 552, 460, 3, 4)
		verify_conversion_to_tile(map, 644, 506, 3.5, 4.5)
		verify_conversion_to_tile(map, 736, 552, 4, 5)
	end)

	it("converts between hex and world space", function()
		local map = sti("tests/hex.lua")

		verify_conversion_to_pixel(map, 3, 4, 96, 128)
		verify_conversion_to_pixel(map, 3.5, 4.5, 112, 144)
		verify_conversion_to_pixel(map, 4, 5, 128, 160)

		verify_conversion_to_tile(map, 96, 128, 3, 4)
		verify_conversion_to_tile(map, 112, 144, 3.5, 4.5)
		verify_conversion_to_tile(map, 128, 160, 4, 5)
	end)
end)