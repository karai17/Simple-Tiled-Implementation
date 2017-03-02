local lg = love.graphics
local isCreated = lg.isCreated
local graphics = {isCreated = isCreated}

function graphics.newSpriteBatch(...)
	if isCreated() then
		return lg.newSpriteBatch(...)
	end
end

function graphics.newCanvas(...)
	if isCreated() then
		return lg.newCanvas(...)
	end
end

function graphics.newQuad(...)
	if isCreated() then
		return lg.newQuad(...)
	end
end

function graphics.getCanvas(...)
	if isCreated() then
		return lg.getCanvas(...)
	end
end

function graphics.setCanvas(...)
	if isCreated() then
		return lg.setCanvas(...)
	end
end

function graphics.clear(...)
	if isCreated() then
		return lg.clear(...)
	end
end

function graphics.push(...)
	if isCreated() then
		return lg.push(...)
	end
end

function graphics.origin(...)
	if isCreated() then
		return lg.origin(...)
	end
end

function graphics.pop(...)
	if isCreated() then
		return lg.pop(...)
	end
end

function graphics.draw(...)
	if isCreated() then
		return lg.draw(...)
	end
end

function graphics.getColor(...)
	if isCreated() then
		return lg.getColor(...)
	end
end

function graphics.setColor(...)
	if isCreated() then
		return lg.setColor(...)
	end
end

function graphics.line(...)
	if isCreated() then
		return lg.line(...)
	end
end

function graphics.polygon(...)
	if isCreated() then
		return lg.polygon(...)
	end
end

function graphics.getWidth()
	if isCreated() then
		return lg.getWidth()
	end
	return 0
end

function graphics.getHeight()
	if isCreated() then
		return lg.getHeight()
	end
	return 0
end

return graphics