io.stdout:setvbuf("no")
local sti = require "sti"
local map
local world
local tx, ty
local points

function love.load()
	-- Load map
	map = sti("tests/ortho.lua", { "box2d" })
	--map = sti("tests/iso.lua",   { "box2d" })
	--map = sti("tests/stag.lua",  { "box2d" })
	--map = sti("tests/hex.lua",   { "box2d" })
	--map = sti("tests/bench.lua", { "box2d" }) -- this might crash your system!

	-- Print versions
	print("STI: " .. sti._VERSION)
	print("Map: " .. map.tiledversion)
	print("ESCAPE TO QUIT")
	print("SPACE TO RESET TRANSLATION")

	-- Prepare translations
	tx, ty = 0, 0

	-- Prepare physics world
	love.physics.setMeter(32)
	world = love.physics.newWorld(0, 0)
	map:box2d_init(world)

	-- Drop points on clicked areas
	points = {
		mouse = {},
		pixel = {}
	}
	love.graphics.setPointSize(5)
end

function love.keypressed(key)
	-- Exit test
	if key == "escape" then
		love.event.quit()
	end

	-- Reset translation
	if key == "space" then
		tx, ty = 0, 0
	end
end

function love.update(dt)
	world:update(dt)
	map:update(dt)

	-- Move map
	local kd = love.keyboard.isDown
	local l  = kd("left")  or kd("a")
	local r  = kd("right") or kd("d")
	local u  = kd("up")    or kd("w")
	local d  = kd("down")  or kd("s")

	tx = l and tx - 128 * dt or tx
	tx = r and tx + 128 * dt or tx
	ty = u and ty - 128 * dt or ty
	ty = d and ty + 128 * dt or ty
end

function love.draw()
	-- Draw map
	love.graphics.setColor(255, 255, 255)
	map:draw(-tx, -ty)

	-- Draw physics objects
	love.graphics.setColor(255, 0, 255)
	map:box2d_draw(-tx, -ty)

	-- Draw points
	love.graphics.translate(-tx, -ty)

	love.graphics.setColor(255, 0, 255)
	for _, point in ipairs(points.mouse) do
		love.graphics.points(point.x, point.y)
	end

	love.graphics.setColor(255, 255, 0)
	for _, point in ipairs(points.pixel) do
		love.graphics.points(point.x, point.y)
	end
end

function love.mousepressed(x, y, button)
	if button == 1 then
		x = x + tx
		y = y + ty

		local tilex, tiley   = map:convertPixelToTile(x, y)
		local pixelx, pixely = map:convertTileToPixel(tilex, tiley)

		table.insert(points.pixel, { x=pixelx, y=pixely })
		table.insert(points.mouse, { x=x, y=y })

		print(x, tilex, pixelx)
		print(y, tiley, pixely)
	end
end

function love.resize(w, h)
	map:resize(w, h)
end
