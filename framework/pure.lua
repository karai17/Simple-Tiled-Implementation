local lua = {}

function lua:load(file)
	return assert(love.filesystem.load(file), "File not found: " .. file)
end

function lua.newImage(path)
	local image = love.graphics.newImage(path)
	image:setFilter("nearest", "nearest")
	
	return image
end

lua.newQuad			= love.graphics.newQuad
lua.setColor		= love.graphics.setColor
lua.draw			= love.graphics.draw
lua.polygon			= love.graphics.polygon
lua.rectangle		= love.graphics.rectangle
lua.isConvex		= love.math.isConvex
lua.triangulate		= love.math.triangulate
lua.line			= love.graphics.line
lua.newSpriteBatch	= love.graphics.newSpriteBatch
lua.getWidth		= love.graphics.getWidth
lua.getHeight		= love.graphics.getHeight

return lua