io.stdout:setvbuf("no")
local love = _G.love
local sti  = require "sti"
local map, world, tx, ty, points

function love.load()
	-- Load map
	map = sti("tests/ortho.lua",     { "box2d" })
	--map = sti("tests/ortho-inf.lua", { "box2d" })
	--map = sti("tests/iso.lua",       { "box2d" })
	--map = sti("tests/stag.lua",      { "box2d" })
	--map = sti("tests/hex.lua",       { "box2d" })
	--map = sti("tests/objects.lua",   { "box2d" })

	-- Print versions
	print("STI: " .. sti._VERSION)
	print("Map: " .. map.tiledversion)

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

function love.update(dt)
	world:update(dt)
	map:update(dt)

	-- Move map
	local kd = love.keyboard.isDown
	tx = kd("a", "left")  and tx - 128 * dt or tx
	tx = kd("d", "right") and tx + 128 * dt or tx
	ty = kd("w", "up")    and ty - 128 * dt or ty
	ty = kd("s", "down")  and ty + 128 * dt or ty
end

function love.draw()
	-- Draw map
	love.graphics.setColor(1, 1, 1)
	map:draw(-tx, -ty)

	-- Draw physics objects
	love.graphics.setColor(1, 0, 1)
	map:box2d_draw(-tx, -ty)

	-- Draw points
	love.graphics.translate(-tx, -ty)

	love.graphics.setColor(0, 1, 1)
	for _, point in ipairs(points.mouse) do
		love.graphics.points(point.x, point.y)
	end

	love.graphics.setColor(1, 1, 0)
	for _, point in ipairs(points.pixel) do
		love.graphics.points(point.x, point.y)
	end
end

function love.mousepressed(x, y, button)
	if button == 1 then
		x = x + tx
		y = y + ty

		local tilex,  tiley  = map:convertPixelToTile(x, y)
		local pixelx, pixely = map:convertTileToPixel(tilex, tiley)

		table.insert(points.pixel, { x=pixelx, y=pixely })
		table.insert(points.mouse, { x=x,      y=y      })

		print(x, tilex, pixelx)
		print(y, tiley, pixely)
	end
end

function love.resize(w, h)
	map:resize(w, h)
end
