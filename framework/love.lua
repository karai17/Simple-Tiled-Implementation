local luv = {}

function luv:load(file)
	return assert(love.filesystem.load(file), "File not found: " .. file)
end

function luv.newImage(path)
	local image = love.graphics.newImage(path)
	image:setFilter("nearest", "nearest")
	
	return image
end

luv.newQuad			= love.graphics.newQuad
luv.setColor		= love.graphics.setColor
luv.draw			= love.graphics.draw
luv.polygon			= love.graphics.polygon
luv.rectangle		= love.graphics.rectangle
luv.isConvex		= love.math.isConvex
luv.triangulate		= love.math.triangulate
luv.line			= love.graphics.line
luv.newSpriteBatch	= love.graphics.newSpriteBatch
luv.getWidth		= love.graphics.getWidth
luv.getHeight		= love.graphics.getHeight

return luv