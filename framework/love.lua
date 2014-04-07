local framework = {}

framework.version = "LOVE"

function framework:load(file)
	return assert(love.filesystem.load(file), "File not found: " .. file)
end

function framework.newImage(path)
	local image = love.graphics.newImage(path)
	image:setFilter("nearest", "nearest")
	
	return image
end

framework.newQuad			= love.graphics.newQuad
framework.setColor			= love.graphics.setColor
framework.draw				= love.graphics.draw
framework.polygon			= love.graphics.polygon
framework.rectangle			= love.graphics.rectangle
framework.isConvex			= love.math.isConvex
framework.triangulate		= love.math.triangulate
framework.line				= love.graphics.line
framework.newSpriteBatch	= love.graphics.newSpriteBatch
framework.getWidth			= love.graphics.getWidth
framework.getHeight			= love.graphics.getHeight

return framework
