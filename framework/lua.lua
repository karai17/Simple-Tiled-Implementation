local lf = love.filesystem
local lg = love.graphics
local lm = love.math
local lp = love.physics
local framework = {}

framework.version = "Lua"

function framework.load(file)
	return assert(lf.load(file), "File not found: " .. file)
end

function framework.newImage(path)
	local image = lg.newImage(path)
	image:setFilter("nearest", "nearest")

	return image
end

function framework:newCanvas(w, h)
	w = w or self.getWidth()
	h = h or self.getHeight()
	local canvas = lg.newCanvas(w, h)
	canvas:setFilter("nearest", "nearest")

	return canvas
end

-- Filesystem Calls
framework.isFile = lf.isFile

-- Graphics Calls
framework.draw           = lg.draw
framework.getCanvas      = lg.getCanvas
framework.getHeight      = lg.getHeight
framework.getWidth       = lg.getWidth
framework.line           = lg.line
framework.newSpriteBatch = lg.newSpriteBatch
framework.newQuad        = lg.newQuad
framework.polygon        = lg.polygon
framework.rectangle      = lg.rectangle
framework.setColor       = lg.setColor
framework.setCanvas      = lg.setCanvas
framework.origin         = lg.origin
framework.pop            = lg.pop
framework.push           = lg.push

-- Math Calls
framework.isConvex    = lm.isConvex
framework.triangulate = lm.triangulate

-- Physics Calls
if lp then
	framework.getMeter        = lp.getMeter
	framework.newBody         = lp.newBody
	framework.newChainShape   = lp.newChainShape
	framework.newFixture      = lp.newFixture
	framework.newPolygonShape = lp.newPolygonShape
end

return framework
