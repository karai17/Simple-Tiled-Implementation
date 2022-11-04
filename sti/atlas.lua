---- Texture atlas complement for the Simple Tiled Implementation
-- @copyright 2022
-- @author Eduardo Hernández coz.eduardo.hernandez@gmail.com
-- @license MIT/X11

local module = {}

--- Create a texture atlas
-- @param files Array with filenames
-- @param sort If "size" will sort by size, or if "id" will sort by id
-- @param ids Array with ids of each file
-- @param pow2 If true, will force a power of 2 size
function module.Atlas( files, sort, ids, pow2 )

    local function Node(x, y, w, h)
        return {x = x, y = y, w = w, h = h}
    end

    local function nextpow2( n )
        local res = 1
        while res <= n do
            res = res * 2
        end
        return res
    end

    local function loadImgs()
        local images = {}
        for i = 1, #files do
            images[i] = {}
            --images[i].name = files[i]
            if ids then images[i].id = ids[i] end
            images[i].img = love.graphics.newImage( files[i] )
            images[i].w = images[i].img:getWidth()
            images[i].h = images[i].img:getHeight()
            images[i].area = images[i].w * images[i].h
        end
        if sort == "size" or sort == "id" then
            table.sort( images, function( a, b ) return ( a.area > b.area ) end )
        end
        return images
    end

    --TODO: understand this func
    local function add(root, id, w, h)
        if root.left or root.right then
            if root.left then
                local node = add(root.left, id, w, h)
                if node then return node end
            end
            if root.right then
                local node = add(root.right, id, w, h)
                if node then return node end
            end
            return nil
        end

        if w > root.w or h > root.h then return nil end

        local _w, _h = root.w - w, root.h - h

        if _w <= _h then
            root.left = Node(root.x + w, root.y, _w, h)
            root.right = Node(root.x, root.y + h, root.w, _h)
        else
            root.left = Node(root.x, root.y + h, w, _h)
            root.right = Node(root.x + w, root.y, _w, root.h)
        end

        root.w = w
        root.h = h
        root.id = id

        return root
    end

    local function unmap(root)
        if not root then return {} end

        local tree = {}
        if root.id then
            tree[root.id] = {}
            tree[root.id].x, tree[root.id].y = root.x, root.y
        end

        local left = unmap(root.left)
        local right = unmap(root.right)

        for k, v in pairs(left) do
            tree[k] = {}
            tree[k].x, tree[k].y = v.x, v.y
        end
        for k, v in pairs(right) do
            tree[k] = {}
            tree[k].x, tree[k].y = v.x, v.y
        end

        return tree
    end

    local function bake()
        local images = loadImgs()

        local root = {}
        local w, h = images[1].w, images[1].h

        if pow2 then
            if w % 1 == 0 then w = nextpow2(w) end
            if h % 1 == 0 then h = nextpow2(h) end
        end

        repeat
            local node

            root = Node(0, 0, w, h)

            for i = 1, #images do
                node = add(root, i, images[i].w, images[i].h)
                if not node then break end
            end

            if not node then
                if h <= w then
                    if pow2 then h = h * 2 else h = h + 1 end
                else
                    if pow2 then w = w * 2 else w = w + 1 end
                end
            else
                break
            end
        until false

        local limits = love.graphics.getSystemLimits()
        if w > limits.texturesize or h > limits.texturesize then
            return "Resulting texture is too large for this system"
        end

        local coords = unmap(root)
        local map = love.graphics.newCanvas(w, h)
        love.graphics.setCanvas( map )
--        love.graphics.clear()

        for i = 1, #images do
            love.graphics.draw(images[i].img, coords[i].x, coords[i].y)
            if ids then coords[i].id = images[i].id end
        end
        love.graphics.setCanvas()

        if sort == "ids" then
            table.sort( coords, function( a, b ) return ( a.id < b.id ) end )
        end

        return { image = map, coords = coords }
    end

    return bake()
end

return module
