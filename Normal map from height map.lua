----------------------------------------------------------------------
-- Generate normal map from height map
--
-- It works only for RGB color mode.
----------------------------------------------------------------------


if app.apiVersion < 1 then
    return app.alert("This script requires Aseprite v1.2.10-beta3")
end

local cel = app.activeCel
if not cel then
    return app.alert("There is no active image")
end

function cross_product(p0, p1)
    return {
        x = p0.y*p1.z - p0.z*p1.y;
        y = p0.z*p1.x - p0.x*p1.z;
        z = p0.x*p1.y - p0.y*p1.x;
    }
end

function normalize(vec)
    local inv_len = 1.0 / math.sqrt(
        vec.x * vec.x +
        vec.y * vec.y +
        vec.z * vec.z)

    return {
        x = vec.x * inv_len,
        y = vec.y * inv_len,
        z = vec.z * inv_len
    }
end

function create_normal(dx, dy, dh)
    local dire = normalize({x=dx, y= dy, z=dh})     -- Direction of pixel
    local orth = normalize({x=dy, y=-dx, z=0.0})    -- Orthogonal
    return cross_product(orth, dire)                -- Upwards vector
end

local img = cel.image:clone()
local position = cel.position

if img.colorMode == ColorMode.RGB then
    local rgba = app.pixelColor.rgba
    local rgbaA = app.pixelColor.rgbaA
    for it in img:pixels() do
        local normals = {}
        local x = it.x
        local y = it.y

        function add_pixel_plane(dx, dy)
            local ax = (x + dx) % img.width
            local ay = (y + dy) % img.height

            local offs_px = cel.image:getPixel(ax, ay)
            -- Height difference, 50 seams like a good number
            local dh = (app.pixelColor.rgbaR(offs_px) - app.pixelColor.rgbaR(it)) / 50
            normals[#normals+1] = create_normal(dx, dy, dh)
        end

        add_pixel_plane(-1, 0)
        add_pixel_plane(-1, -1)
        add_pixel_plane(-1, 1)
        add_pixel_plane(1, 0)
        add_pixel_plane(1, -1)
        add_pixel_plane(1, 1)
        add_pixel_plane(0, -1)
        add_pixel_plane(0, 1)

        -- Calculate average plane
        local avg_plane = {x=0, y=0, z=0}
        for i=1, #normals do
            avg_plane.x = avg_plane.x + normals[i].x
            avg_plane.y = avg_plane.y + normals[i].y
            avg_plane.z = avg_plane.z + normals[i].z
        end

        avg_plane = normalize(avg_plane)

        -- Convert to pixel values
        avg_plane.x = 127 + 127 * avg_plane.x
        avg_plane.y = 127 - 127 * avg_plane.y
        avg_plane.z = 127 + 127 * avg_plane.z

        it(rgba(avg_plane.x, avg_plane.y, avg_plane.z, 255))
    end

elseif img.colorMode == ColorMode.GRAY then
    return app.alert("This script is only for RGB Color Mode")
elseif img.colorMode == ColorMode.INDEXED then
    return app.alert("This script is only for RGB Color Mode")
end

local sprite = app.activeSprite
local frame = app.activeFrame
local currentLayer = app.activeLayer
local newLayerName = currentLayer.name .. "_NormalGenerated"
local newLayer = nil
for i,layer in ipairs(sprite.layers) do
    if layer.name == newLayerName then
        -- the layer to write normal on is already exists
        newLayer = layer
    end
end
if newLayer == nil then
    newLayer = sprite:newLayer()
    newLayer.name = newLayerName
end
local newCel = sprite:newCel(newLayer, frame, img, position)

app.refresh()
