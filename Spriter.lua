require("json")

-- TODO : for test only, remove later
local function dump(value)
	print(json.encode(value))
end

-- namespace
Spriter = {}

Spriter.TexturePack = Core.class()

function Spriter.TexturePack:init(texture, texture_pack_file)
	
	self.texture = texture
	
	local file = io.open(texture_pack_file)
	
	self.data = json.decode(file:read("*all"))
	
	file:close()
	
end

function Spriter.TexturePack:getTextureRegion(name)

	local data = self.data
	
	local frame_data = data.frames[name]	
	local frame = frame_data.frame
	local spriter_source_size = frame_data.spriteSourceSize
	local source_size = frame_data.sourceSize

	local x = frame.x
	local y = frame.y
	local width = frame.w
	local height = frame.h
	
	-- left and top in source image
	local dx1 = spriter_source_size.x
	local dy1 = spriter_source_size.y
	
	-- right and bottom space in source image 
	local dx2 = source_size.w - width - dx1
	local dy2 = source_size.h - height - dy1
	
	return TextureRegion.new(self.texture, x, y, width, height, dx1, dy1, dx2, dy2)
end

-- math functions
local function linear(a, b, t)
	return (b - a) * t + a
end

local function vectorLinear(vector_a, vector_b, t)
	return Spriter.Vector.new(linear(vector_a.x, vector_b.x, t), linear(vector_a.y, vector_b.y, t))
end

local function angleLinear(angle_a, angle_b, spin, t)

	if spin == 0 then
		return angle_a
	elseif spin > 0 then
		if angle_b - angle_a > 0 then angle_b = angle_b - 360 end
	elseif spin < 0 then
		if angle_b - angle_a < 0 then angle_b = angle_b + 360 end
	end
	
	return linear(angle_a, angle_b, t)
end

local function spatialLinear(spatial_a, spatial_b, spin, t)
	local spatial = Spriter.Spatial.new()
	spatial.position = vectorLinear(spatial_a.position, spatial_b.position, t)
	
	spatial.angle = angleLinear(spatial_a.angle, spatial_b.angle, spin, t)
	spatial.scale = vectorLinear(spatial_a.scale, spatial_b.scale, t)
	spatial.a = linear(spatial_a.a, spatial_b.a, t)	
	return spatial
end

-- factory method for spriter object
function Spriter.create(filename)
	local file = io.open(filename)
	local json_data = json.decode(file:read("*all"))
	file:close()
	
	return Spriter.Object.new(json_data)
end

Spriter.Object = Core.class()

function Spriter.Object:init(spriter_data)
	local folders = {}
	for i, folder in ipairs(spriter_data.folder) do
		-- lua array index start form 1
		folders[folder.id + 1] = Spriter.Folder.new(folder)
	end
	self.folders = folders
	
	local entities = {}
	for i, entity in ipairs(spriter_data.entity) do
		entities[entity.id + 1] = Spriter.Entity.new(entity)
		-- use name as key, for faster name reference
		entities[entity.name] = entities[entity.id + 1]
	end
	self.entities = entities
end

function Spriter.Object:createEntitySprite(name)
	return Spriter.EntitySprite.new(self.entities[name], self.folders)
end

Spriter.EntitySprite = Core.class(Sprite)

function Spriter.EntitySprite:init(entity, folders)
	self.time = 0
	self.entity = entity
	self.animation = entity.animations[1]
	self.bitmaps = {}
	self.folders = folders
	self.playing = false
	
	self:addEventListener(Event.ENTER_FRAME, Spriter.EntitySprite.onUpdate, self)
end

function Spriter.EntitySprite:play(name)
	self.animation = self.entity.animations[name]
	self.time = 0
	self.playing = true
end

function Spriter.EntitySprite:pause()
	self.playing = not self.playing
end

function Spriter.EntitySprite:stop()
	self.playing = false
	self.time = 0
end

function Spriter.EntitySprite:setTime(time)
	local animation = self.animation
	
	if animation.looping then
		self.time = time % animation.length
	else
		self.time = math.min(time, animation.length)
	end
end

function Spriter.EntitySprite:onUpdate(event)
	if self.playing then
		self:setTime(self.time + event.deltaTime * 1000.0)	
	end
	
	if self.texture_pack == nil then return end
	
	self:applyAnimation()
	self:updateObjects()
end

function Spriter.EntitySprite:updateObjects()
	local folders = self.folders
	local texture_pack = self.texture_pack
	local bitmaps = self.bitmaps
	
	for i, bitmap in ipairs(bitmaps) do
		bitmap:setVisible(false)
	end
	
	for i, key in ipairs(self.object_keys) do
		if bitmaps[i] == nil then
			bitmaps[i] = Bitmap.new(texture_pack.texture)
			self:addChild(bitmaps[i])
			bitmaps[i]:setVisible(false)
		end
	
		local bitmap = bitmaps[i]
		
		if key.folder and key.folder > 0 then
			
			bitmap:setVisible(true)
			
			local file = folders[key.folder].files[key.file]
			
			bitmap:setTextureRegion(texture_pack:getTextureRegion(file.name))
			
			local pivot = key.pivot
			
			if key.use_default_pivot then 
				pivot = file.pivot
			end
				
			bitmap:setAnchorPoint(pivot.x, pivot.y)
			
			bitmap:setPosition(key.spatial.position.x, key.spatial.position.y)
			bitmap:setRotation(key.spatial.angle)
			bitmap:setScale(key.spatial.scale.x, key.spatial.scale.y)
			
		end
	
	end
	
end

function Spriter.EntitySprite:applyAnimation()
	local animation = self.animation
	
	local mainline_key = animation:getMainlineKeyFromTime(self.time)
	
	local bone_keys = {}
	
	for i, reference in ipairs(mainline_key.bone_references) do
		
		local current_key = animation:getKeyFromReference(reference, self.time)
		
		if reference.parent > 0 and bone_keys[reference.parent] then
			current_key.spatial = current_key.spatial:combineParent(bone_keys[reference.parent].spatial)	
		end
		
		current_key.parent = reference.parent
		
		bone_keys[i] = current_key
	end	
	
	local object_keys = {}
	
	for i, reference in ipairs(mainline_key.object_references) do
		local current_key = animation:getKeyFromReference(reference, self.time)
		
		if reference.parent > 0 and bone_keys[reference.parent] then
			current_key.spatial = current_key.spatial:combineParent(bone_keys[reference.parent].spatial)	
		end
		
		current_key.parent = reference.parent	
		
		object_keys[i] = current_key	
	end
	
	self.object_keys = object_keys
	
end

-- folder class
Spriter.Folder = Core.class()

function Spriter.Folder:init(folder_data)
	self.name = folder_data.name
	
	local files = {}	
	for i, file in ipairs(folder_data.file) do
		local pivot = Spriter.Vector.new(file.pivot_x, file.pivot_y)
		pivot.y = 1 - pivot.y
		files[file.id + 1] =
		{
			name = file.name,
			pivot = pivot
		}
	end	
	self.files = files
end

-- entity class
Spriter.Entity = Core.class()

function Spriter.Entity:init(entity_data)
	self.name = entity_data.name
	
	local animations = {}
	for i, animation in ipairs(entity_data.animation) do
		animations[animation.id + 1] = Spriter.Animation.new(animation)
		animations[animation.name] = animations[animation.id + 1]
	end
	self.animations = animations
		
end

Spriter.Animation = Core.class()

function Spriter.Animation:init(animation_data)
	self.name = animation_data.name
	self.looping = animation_data.looping == nil and true or animation_data.looping
	self.length = animation_data.length
	
	local mainline_keys = {}
	for i, mainline_key in ipairs(animation_data.mainline.key) do
		mainline_keys[mainline_key.id + 1] = Spriter.MainlineKey.new(mainline_key)
	end
	self.mainline_keys = mainline_keys
	
	local timelines = {}	
	for i, timeline in ipairs(animation_data.timeline) do
		timelines[timeline.id + 1] = Spriter.Timeline.new(timeline)
	end
	self.timelines = timelines
	
end

function Spriter.Animation:getMainlineKeyFromTime(time)
	local mainline_keys = self.mainline_keys
	
	local index = 0
	
	for i, key in ipairs(mainline_keys) do
		if key.time <= time then
			index = i
		else
			break
		end
	end

	return mainline_keys[index]
end

function Spriter.Animation:getKeyFromReference(reference, time)
	local timeline = self.timelines[reference.timeline]
	
	local key_length = #timeline.keys
	
	if key_length == 0 then return nil end
	
	local key_a = timeline.keys[reference.key]
	
	if key_length == 1 then return key_a:clone() end
	
	local next_key_index = reference.key + 1
	
	if next_key_index > key_length then 
		if self.looping then next_key_index = 1 else return key_a:clone()  end
	end
	
	local key_b = timeline.keys[next_key_index]
	local key_b_time = key_b.time
	
	if key_b_time < key_a.time then key_b_time = key_b_time + self.length end

	return key_a:interpolate(key_b, key_b_time, time)
end

Spriter.MainlineKey = Core.class()

function Spriter.MainlineKey:load_references(references_data)
	local references = {}
	for i, reference in ipairs(references_data) do
		references[reference.id + 1] =
		{
			-- lua array start form 1, so add 1 to all index
			parent = reference.parent ~= nil and reference.parent + 1 or 0,
			timeline = reference.timeline + 1,
			key = reference.key + 1,
			z_index = reference.z_index
		}
	end	
	return references
end

function Spriter.MainlineKey:init(mainline_key_data)
	self.time = mainline_key_data.time or 0
	self.bone_references = self:load_references(mainline_key_data.bone_ref)
	self.object_references = self:load_references(mainline_key_data.object_ref)
end

Spriter.Timeline = Core.class()

function Spriter.Timeline:init(timeline_data)
	self.name = timeline_data.name
	self.type = timeline_data.object_type or "sprite"
	
	local keys = {}
	
	for i, key in ipairs(timeline_data.key) do
		-- support sprite timeline key only
		keys[key.id + 1] = Spriter.TimelineKey.classes[self.type].new(key)
	end
	
	self.keys = keys
	
end

Spriter.TimelineKey = Core.class()

function Spriter.TimelineKey:init(timeline_key_data)
	timeline_key_data = timeline_key_data or {}
	self.time = timeline_key_data.time or 0
	self.spin = timeline_key_data.spin or 1
	-- support linear only
	--self.cruve = timeline_key_data.cruve_type or 0
end

function Spriter.TimelineKey:copyTo(timeline_key)
	timeline_key.time = self.time
	timeline_key.spin = self.spin
end

function Spriter.TimelineKey:clone()
	local timeline_key = self:create()
	self:copyTo(timeline_key)
	return timeline_key
end

function Spriter.TimelineKey:create()
	return Spriter.TimelineKey.new()
end

function Spriter.TimelineKey:interpolate(next_key, next_key_time, time)
	return self:linear(next_key, self:getTWithNextKey(next_key, next_key_time, time))
end

function Spriter.TimelineKey:getTWithNextKey(next_key, next_key_time, time)
	-- support linear only
	if time == next_key.time then return 0 end
	
	local t = (time - self.time) / (next_key_time - self.time)
	
	-- support linear only
	return t
end

Spriter.Vector = Core.class()

function Spriter.Vector:init(x, y)
	self.x = x or 0
	self.y = y or 0
end

Spriter.Spatial = Core.class()

function Spriter.Spatial:init(spatial_data)
	spatial_data = spatial_data or {}
	
	self.position = Spriter.Vector.new(spatial_data.x, spatial_data.y)
	self.position.y = -self.position.y
	self.angle = spatial_data.angle or 0
	self.angle = -self.angle
    self.scale = Spriter.Vector.new(spatial_data.scale_x or 1, spatial_data.scale_y or 1)
	self.a = spatial_data.a or 1
end

function Spriter.Spatial:copyTo(spatial)
	spatial.position = Spriter.Vector.new(self.position.x, self.position.y)
	spatial.angle = self.angle
	spatial.scale = Spriter.Vector.new(self.scale.x, self.scale.y)
	spatial.a = self.a
end

function Spriter.Spatial:clone()
	local spatial = Spriter.Spatial.new()
	self:copyTo(spatial)
	return spatial
end

function Spriter.Spatial:combineParent(parent)
	local spatial = Spriter.Spatial.new()
	self:copyTo(spatial)
	
	spatial.angle = spatial.angle + parent.angle
	spatial.scale.x = spatial.scale.x * parent.scale.x
	spatial.scale.y = spatial.scale.y * parent.scale.y
	spatial.a = spatial.a * parent.a
	
	if x ~= 0 or y ~= 0 then
		local pre_x = spatial.position.x * parent.scale.x
		local pre_y = spatial.position.y * parent.scale.y
		local radians = parent.angle * math.pi / 180
		local s = math.sin(radians)
		local c = math.cos(radians)
		
		spatial.position.x = (pre_x * c) - (pre_y * s) + parent.position.x
		spatial.position.y = (pre_x * s) + (pre_y * c) + parent.position.y
			
	else
		spatial.position.x = parent.position.x
		spatial.position.y = parent.position.y
	end
	
	return spatial
end

Spriter.SpatialTimelineKey = Core.class(Spriter.TimelineKey)

function Spriter.SpatialTimelineKey:init(timeline_key_data)
	timeline_key_data = timeline_key_data or {}
	self.spatial = Spriter.Spatial.new(timeline_key_data.bone or timeline_key_data.object)
end

function Spriter.SpatialTimelineKey:copyTo(timeline_key)
	Spriter.TimelineKey.copyTo(self, timeline_key)
	timeline_key.spatial = self.spatial:clone()
end

function Spriter.SpatialTimelineKey:create()
	return Spriter.SpatialTimelineKey.new()
end

Spriter.SpriteTimelineKey = Core.class(Spriter.SpatialTimelineKey)

function Spriter.SpriteTimelineKey:init(timeline_key_data)
	local sprite_object = timeline_key_data and timeline_key_data.object or {}
	
	self.folder = sprite_object.folder ~= nil and sprite_object.folder + 1 or 0
	self.file = sprite_object.file ~= nil and sprite_object.file + 1 or 0
	self.use_default_pivot = sprite_object.pivot_x == nil
	self.pivot = Spriter.Vector.new(sprite_object.pivot_x, sprite_object.pivot_y)
	self.pivot.y = 1 - self.pivot.y
end

function Spriter.SpriteTimelineKey:copyTo(timeline_key)
	Spriter.SpatialTimelineKey.copyTo(self, timeline_key)
	
	timeline_key.folder = self.folder
	timeline_key.file = self.file
	timeline_key.use_default_pivot = self.use_default_pivot
	timeline_key.pivot = Spriter.Vector.new(self.pivot.x, self.pivot.y)
end

function Spriter.SpriteTimelineKey:create()
	return Spriter.SpriteTimelineKey.new()
end

function Spriter.SpriteTimelineKey:linear(key_b, t)
	local key = self:clone()
	
	key.spatial = spatialLinear(self.spatial, key_b.spatial, self.spin, t)
	
	if not self.use_default_pivot and not key_b.use_default_pivot then
		key.pivot = vectorLinear(self.pivot, key_b.pivot, t)
		key.use_default_pivot = false
	else
		key.use_default_pivot = true
	end
	
	return key
end

Spriter.BoneTimelineKey = Core.class(Spriter.SpatialTimelineKey)

function Spriter.BoneTimelineKey:create()
	return Spriter.BoneTimelineKey.new()
end

function Spriter.BoneTimelineKey:linear(key_b, t)
	local key = self:clone()	
	key.spatial = spatialLinear(self.spatial, key_b.spatial, self.spin, t)	
	return key
end


Spriter.TimelineKey.classes = 
{
	sprite = Spriter.SpriteTimelineKey,
	bone = Spriter.BoneTimelineKey
}