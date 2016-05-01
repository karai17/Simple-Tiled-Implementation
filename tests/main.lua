local sti = require "sti"

function love.load()
	-- Load map
	map = sti.new("sti/tests/ortho.lua", { "box2d" })
	--map = sti.new("sti/tests/iso.lua",   { "box2d" })
	--map = sti.new("sti/tests/stag.lua",  { "box2d" })
	--map = sti.new("sti/tests/hex.lua",   { "box2d" })
	
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
	love.graphics.translate(-tx, -ty)
	map:draw()
	
	-- Draw physics objects
	love.graphics.setColor(255, 0, 255, 255)
	map:box2d_draw()
end

function love.resize(w, h)
	map:resize(w, h)
end
