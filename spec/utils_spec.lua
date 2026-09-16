local utils = require "sti.utils"

describe("STI utils", function()
	describe("hex_to_color", function()
		it("converts 6-digit hex string with # prefix to normalized RGB", function()
			local c = utils.hex_to_color("#ff00e6")
			assert.is.equal(c.r, 1)
			assert.is.equal(c.g, 0)
			assert.is.equal(c.b, 230 / 255)
		end)

		it("converts 6-digit hex string without # prefix to normalized RGB", function()
			local c = utils.hex_to_color("ff00ff")
			assert.is.equal(c.r, 1)
			assert.is.equal(c.g, 0)
			assert.is.equal(c.b, 1)
		end)
	end)

	describe("pixel_function", function()
		it("masks exact matches to alpha 0", function()
			utils._TC = utils.hex_to_color("#ff00ff")
			local r, g, b, a = utils.pixel_function(0, 0, 1.0, 0.0, 1.0, 1.0)
			assert.is.equal(r, 1.0)
			assert.is.equal(g, 0.0)
			assert.is.equal(b, 1.0)
			assert.is.equal(a, 0)
		end)

		it("masks float32 LÖVE ImageData precision differences to alpha 0", function()
			utils._TC = utils.hex_to_color("#ff00e6")

			-- In LÖVE 11+, 230 / 255.0f is passed as a 32-bit single-precision float
			-- promoted to double: 0.90196079015731812.
			-- Lua calculates 230 / 255 in double precision: 0.90196078431372551.
			local love_float32_b = 0.90196079015731812
			local _, _, _, a = utils.pixel_function(0, 0, 1.0, 0.0, love_float32_b, 1.0)
			assert.is.equal(a, 0)
		end)

		it("masks #ff99cc with single-to-double precision rounding to alpha 0", function()
			utils._TC = utils.hex_to_color("#ff99cc")

			-- 153 / 255 as float32: 0.60000002384185791
			-- 204 / 255 as float32: 0.80000001192092896
			local love_float32_g = 0.60000002384185791
			local love_float32_b = 0.80000001192092896
			local _, _, _, a = utils.pixel_function(0, 0, 1.0, love_float32_g, love_float32_b, 1.0)
			assert.is.equal(a, 0)
		end)

		it("does not mask adjacent non-matching color channels", function()
			utils._TC = utils.hex_to_color("#ff00e6")

			-- Channel 229 / 255 (~0.8980) should NOT match mask for 230 / 255 (~0.9019)
			local adjacent_b = 229 / 255
			local _, _, _, a = utils.pixel_function(0, 0, 1.0, 0.0, adjacent_b, 1.0)
			assert.is.equal(a, 1.0)
		end)

		it("does not mask non-matching colors", function()
			utils._TC = utils.hex_to_color("#ff00e6")
			local _, _, _, a = utils.pixel_function(0, 0, 0.5, 0.5, 0.5, 1.0)
			assert.is.equal(a, 1.0)
		end)
	end)
end)
