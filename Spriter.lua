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
	dump(entities)
end

-- folder class
Spriter.Folder = Core.class()

function Spriter.Folder:init(folder_data)
	self.name = folder_data.name
	
	local files = {}	
	for i, file in ipairs(folder_data.file) do
		files[file.id + 1] =
		{
			name = file.name,
			pivot = { x = file.pivot_x, y = file.pivot_y }
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

Spriter.MainlineKey = Core.class()

function Spriter.MainlineKey:init(mainline_key_data)
	self.time = mainline_key_data.time or 0
	-- no need to load bone reference here, only support object now
	local object_references = {}
	for i, reference in ipairs(mainline_key_data.object_ref) do
		object_references[reference.id + 1] =
		{
			-- lua array start form 1, so add 1 to all index
			parent = reference.parent ~= nil and reference.parent + 1 or 0,
			timeline = reference.timeline + 1,
			key = reference.key + 1,
			z_index = reference.z_index
		}
	end	
	self.object_references = object_references
end

Spriter.Timeline = Core.class()

function Spriter.Timeline:init(timeline_data)
	self.name = timeline_data.name
	self.type = timeline_data.object_type or "sprite"
	
end

Spriter.TimelineKey = Core.class()

function Spriter.TimelineKey:init(timeline_key_data)
	self.time = timeline_key_data.time or 0
	self.spin = timeline_key_data.spin or 1
	-- support linear only
	--self.cruve = timeline_key_data.cruve_type or 0
end
