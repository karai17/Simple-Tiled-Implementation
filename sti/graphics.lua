local lg       = _G.love.graphics
local graphics = { isCreated = lg and true or false }

function graphics.newSpriteBatch(...)
	if graphics.isCreated then
		return lg.newSpriteBatch(...)
	end
end

function graphics.newCanvas(...)
	if graphics.isCreated then
		return lg.newCanvas(...)
	end
end

function graphics.newImage(...)
	if graphics.isCreated then
		return lg.newImage(...)
	end
end

function graphics.newQuad(...)
	if graphics.isCreated then
		return lg.newQuad(...)
	end
end

function graphics.getCanvas(...)
	if graphics.isCreated then
		return lg.getCanvas(...)
	end
end

function graphics.setCanvas(...)
	if graphics.isCreated then
		return lg.setCanvas(...)
	end
end

function graphics.clear(...)
	if graphics.isCreated then
		return lg.clear(...)
	end
end

function graphics.push(...)
	if graphics.isCreated then
		return lg.push(...)
	end
end

function graphics.origin(...)
	if graphics.isCreated then
		return lg.origin(...)
	end
end

function graphics.scale(...)
	if graphics.isCreated then
		return lg.scale(...)
	end
end

function graphics.translate(...)
	if graphics.isCreated then
		return lg.translate(...)
	end
end

function graphics.pop(...)
	if graphics.isCreated then
		return lg.pop(...)
	end
end

function graphics.draw(...)
	if graphics.isCreated then
		return lg.draw(...)
	end
end

function graphics.rectangle(...)
	if graphics.isCreated then
		return lg.rectangle(...)
	end
end

function graphics.getColor(...)
	if graphics.isCreated then
		return lg.getColor(...)
	end
end

function graphics.setColor(...)
	if graphics.isCreated then
		return lg.setColor(...)
	end
end

function graphics.line(...)
	if graphics.isCreated then
		return lg.line(...)
	end
end

function graphics.polygon(...)
	if graphics.isCreated then
		return lg.polygon(...)
	end
end

function graphics.points(...)
	if graphics.isCreated then
		return lg.points(...)
	end
end

function graphics.getWidth()
	if graphics.isCreated then
		return lg.getWidth()
	end
	return 0
end

function graphics.getHeight()
	if graphics.isCreated then
		return lg.getHeight()
	end
	return 0
end

return graphics
