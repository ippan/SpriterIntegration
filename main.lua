local texture = Texture.new("data/bat.png")

local texture_pack = Spriter.TexturePack.new(texture, "data/bat.json")
spriter_object = Spriter.create("data/bat.scon")

local sprite = spriter_object:createEntitySprite("bat_with_bone")
sprite.texture_pack = texture_pack

sprite:setX(application:getDeviceWidth() / 2)
sprite:setY(application:getDeviceHeight() / 2)

function changeAnimation(self, event)
	if self:hitTestPoint(event.x, event.y) then
		self:pause()
	end
end

sprite:addEventListener(Event.MOUSE_UP, changeAnimation, sprite)

stage:addChild(sprite)