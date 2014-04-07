local corona = {}

function corona:load(file)
	return assert(love.filesystem.load(file), "File not found: " .. file)
end

function corona.newImage(path)
	local image = love.graphics.newImage(path)
	image:setFilter("nearest", "nearest")
	
	return image
end

corona.newQuad			= love.graphics.newQuad
corona.setColor			= love.graphics.setColor
corona.draw				= love.graphics.draw
corona.polygon			= love.graphics.polygon
corona.rectangle		= love.graphics.rectangle
corona.isConvex			= love.math.isConvex
corona.triangulate		= love.math.triangulate
corona.line				= love.graphics.line
corona.newSpriteBatch	= love.graphics.newSpriteBatch
corona.getWidth			= love.graphics.getWidth
corona.getHeight		= love.graphics.getHeight

return corona