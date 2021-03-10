local lg       = _G.love.graphics
local graphics = { isCreated = lg and true or false }

local function noop() end
local function return_0() return 0 end

local fnlist = {"newSpriteBatch", "newCanvas", "newImage", "newQuad", "getCanvas", "setCanvas",
	"clear", "push", "origin", "scale", "translate", "pop", "draw", "rectangle", "getColor",
	"setColor", "line", "polygon", "points", "getWidth", "getHeight"}

if not graphics.isCreated then
	for i, v in ipairs(fnlist) do
		graphics[v] = noop
	end
	graphics.getWidth  = return_0
	graphics.getHeight = return_0

else
	for i, v in ipairs(fnlist) do
		graphics[v] = lg[v]
	end
end

return graphics
