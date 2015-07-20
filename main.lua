local texture = Texture.new("data/bat.png")

local texture_pack = Spriter.TexturePack.new(texture, "data/bat.json")

local sprite = Bitmap.new(texture_pack:getTextureRegion("bat/wing_right.png"))

sprite:setX(application:getDeviceWidth() / 2)
sprite:setY(application:getDeviceHeight() / 2)

stage:addChild(sprite)

spriter_object = Spriter.create("data/bat.scon")

