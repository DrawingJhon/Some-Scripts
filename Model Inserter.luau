local BinaryParser, ByteReader, InstanceHandler, UnionOperationHandler, ScriptHandler, sha256, OOP, Class, WorkerMonitor
--[[
Code re-coded to lua from extension BTRoblox - Making Roblox Better
js/rbx/FileFormat/BinaryParser.js
js/rbx/FileFormat/ByteReader.js
]]

OOP = {}

local tokens = {"instanceof", "super", "class", "classMethods"}

--[[function OOP.InstanceOf(obj, class)
	return OOP.IsObject(obj) and OOP.IsClass(class) and obj.class == class
		or obj.super and OOP.InstanceOf(obj.super, class)
end

function OOP.IsClass(class)
	return type(class) == "userdata" and getmetatable(class) == "oop_class"
end

function OOP.IsObject(obj)
	return type(obj) == "userdata" and getmetatable(obj) == "oop_object"
end]]

function getHighestInheritor(object)
	if rawequal(object.__data.inheritor, object) then
		error("Object is equal to inheritor")
	end
	return object.__data.inheritor and getHighestInheritor(object.__data.inheritor) or object
end

function OOP.CreateClass(base, proxy)	
	local static = {}

	local class = proxy or newproxy(true)
	local meta = getmetatable(class)

	local classMethods = Class.new(class, base)
	static.Class = classMethods

	local function newObject(shouldInit: boolean, data: {any}?, ...)
		local vars = setmetatable({}, {
			__index = static
		})

		local object = newproxy(true)
		local meta = getmetatable(object)		

		local inheritor, mainInheritor = unpack(data or {})
		mainInheritor = mainInheritor or object

		vars.__data = {
			initiated = false,
			inheritor = inheritor,
			mainInheritor = mainInheritor,
			vars = vars
		}

		vars.class = class

		function vars:instanceof(otherClass)
			return classMethods:IsInstanceOf(otherClass)
		end

		function vars:equals(obj)
			if getmetatable(obj) == "oop_object" then
				return rawequal(mainInheritor, obj.__data.mainInheritor)
			else
				return rawequal(object, obj)
			end
		end

		function vars:__get(member)
			local val = vars[member]
			
			if val ~= nil then
				if type(val) == "function" then
					return function(_, ...)
						return val(object, ...)
					end
				end

				return val
			elseif vars.__data.super then
				return vars.__data.super:__get(member)
			end

			return nil
		end

		meta.__index = function(self, index)
			if index == "__data" then
				return vars.__data
			elseif index == "super" then
				return vars.super
			elseif index == "__get" then
				return vars.__get
			end

			return mainInheritor:__get(index)
		end

		meta.__newindex = function(self, index, value)
			local super = vars.__data.super

			--[[if table.find(tokens, index) then
				if index ~= "super" or not base or super then
					error("Attempted to set a token name: "..index)
				end
			end]]

			if index == "super" then
				vars.super = value
			elseif inheritor then
				mainInheritor[index] = value
			else
				vars[index] = value
			end
		end

		meta.__call = function(self, ...)
			if vars.__data.initiated then
				print(vars.__data)
				error("Instance already initiated", 2)
			end

			vars.__data.initiated = true

			local super = vars.__data.super

			if static.__init then
				static.__init(object, ...)

				if super and not super.__data.initiated then
					error("Must call super constructor in derived class before the end of initialization.", 2)
				end
			elseif super then
				super(...)
			end
		end

		meta.__tostring = function(self)
			return static.__tostring and static.__tostring(self) or tostring(class).." object"
		end
		
		meta.__len = function(self)
			return assert(static.__len, "__len is unassigned")(self)
		end
		
		meta.__iter = function(self)
			return assert(static.__iter, "__iter is unassigned")(self)
		end

		meta.__metatable = "oop_object"

		meta.__eq = function(self, obj)
			if getmetatable(obj) == "oop_object" then
				return rawequal(vars.__data.mainInheritor, obj.__data.mainInheritor)
			else
				return rawequal(object, obj)
			end
		end

		if inheritor then
			local inherSuper = newproxy(true)
			local mt = getmetatable(inherSuper)

			for prop, val in meta do
				mt[prop] = val
			end

			mt.__index = function(self, index)
				return vars:__get(index)
			end

			mt.__tostring = function(self)
				return tostring(object).." (extra)"
			end

			inheritor.super = inherSuper
			inheritor.__data.super = object
		end

		if base then
			base.newObject(false, {object, mainInheritor}, ...)
		end

		static.assign(object)

		if shouldInit then
			object(...)
		end

		return object
	end

	function static.new(...)
		return newObject(true, nil, ...)
	end

	function static.AbstractMethod(methodName: string)
		if type(methodName) ~= "string" then
			error("The type of method name isn't a string. Got "..typeof(methodName))
		end

		static[methodName] = function()
			error("Attempted to call an abstract method. Inheritor must have "..methodName.." included.")
		end
	end

	static.assign = function() end

	static.newObject = newObject

	meta.__index = function(self, index)
		return static[index]
	end

	meta.__newindex = function(self, index, value)
		if index == "new" then
			static.__init = value
		else
			static[index] = value
		end
	end

	meta.__tostring = function(self)
		return static.__className or "Class" --or static.env.script.Name
	end

	meta.__metatable = "oop_class"

	return class
end

function OOP.CreateSimpleClass()
	local Class = setmetatable({}, {
		__newindex = function(self, index, value)
			if index == "new" then
				index = "__init__"
			end
			
			rawset(self, index, value)
		end
	})
	
	Class.__index = Class
	
	rawset(Class, "new", function()
		local self = setmetatable({}, Class)

		if self.__init__ then
			self.__init__()
		end

		return self
	end)
	
	return Class
end

local HttpService = game:GetService("HttpService")

local function decodeText(array)
	local text = ""
	
	for _, charCode in array do
		text ..= string.char(charCode)
	end
	
	return text
end

local function fixNums(nums)
	for i, v in nums do
		nums[i] = math.round(v * 1e3) / 1e3
	end
	
	return nums
end

BinaryParser = {
	HeaderBytes = decodeText({0x3C, 0x72, 0x6F, 0x62, 0x6C, 0x6F, 0x78, 0x21, 0x89, 0xFF, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00}),
	Faces = {
		{1, 0, 0},
		{0, 1, 0},
		{0, 0, 1},
		{-1, 0, 0},
		{0, -1, 0},
		{0, 0, -1}
	},
	DataTypes = {
		nil, "string", "bool", "int", "float", "double", "UDim", "UDim2", -- 7
		"Ray", "Faces", "Axes", "BrickColor", "Color3", "Vector2", "Vector3", "Vector2int16", -- 15
		"CFrame", "Quaternion", "Enum", "Instance", "Vector3int16", "NumberSequence", "ColorSequence", -- 22
		"NumberRange", "Rect2D", "PhysicalProperties", "Color3uint8", "int64", "SharedString", "UnknownScriptFormat", -- 29
		"Optional", "UniqueId", "Font", "SecurityCapabilities"
	},
	RenamedProperties = {
		Color3uint8 = "Color",
		formFactorRaw = "FormFactor",
		Health_XML = "Health",
		xmlRead_MaxDistance_3 = "MaxDistance",
		shape = "Shape",
		size = "Size",
		formFactor = "FormFactor",
		archivable = "Archivable",
		style = "Style",
		MeshID = "MeshId",
		Part0Internal = "Part0",
		Part1Internal = "Part1",
		--InitialSize = "Size"
	},
	InstanceHandlers = {
		{
			ClassNames = {"UnionOperation", "NegateOperation",  "IntersectOperation"},
			Handler = UnionOperationHandler
		},
		{
			ClassNames = {"Script", "LocalScript", "ModuleScript"},
			Handler = ScriptHandler
		}
	},
	HandlerByClassName = {}
}

for _, instanceHandler in BinaryParser.InstanceHandlers do
	for _, className in instanceHandler.ClassNames do
		BinaryParser.HandlerByClassName[className] = instanceHandler.Handler
	end
end

local function GetEnumItem(enum, value)
	for _, item in enum:GetEnumItems() do
		if item.Value == value then
			return item
		end
	end
	
	error("The enum item "..tostring(value).." doesn't exist")
end

function BinaryParser:Parse(buff, options)
	options = options or {}
	local reader = ByteReader.new(buff)
	
	if buffer.readstring(buff, 0, 13) == "<roblox xmlns" then
		error("[ParseRBXBon] Cannot parse rbxmx format!")
	end
	
	if not reader:Match(self.HeaderBytes) then
		print(buffer.tostring(buff))
		error("[ParseRBXBin] Header bytes did not match (Did binary format change?)")
	end
	
	local groupsCount = reader:UInt32LE()
	local instancesCount = reader:UInt32LE()
	reader:Jump(8)
	
	--print("Groups:", groupsCount)
	--print("Instances:", instancesCount)
	
	local parser = {
		debugMain = options.DebugMain,
		yieldUnions = options.YieldUnions,
		precompile = options.Precompile,
		
		result = {},
		reader = reader,
		
		assetsCache = {}, -- Map of requested assets from AssetId of UnionOperations
		pendingRequests = {},
		
		instances = table.create(instancesCount),
		groups = table.create(groupsCount),

		sharedStrings = {}, -- Array
		meta = {}, -- Map

		arrays = {}, -- Array
		arrayIndex = 1,
		
		unionWorkers = WorkerMonitor.new()
	}
	
	function parser:request_get(url)
		if parser.assetsCache[url] then
			return parser.assetsCache[url]
		end
		
		if parser.pendingRequests[url] then
			return parser.pendingRequests[url].Event:Wait()
		end
		
		local bindable = Instance.new("BindableEvent")
		parser.pendingRequests[url] = bindable
		
		--print("Requesting "..url)
		local result = HttpService:GetAsync(url)
		--print("Requested!")
		
		parser.assetsCache[url] = result
		parser.pendingRequests[url] = nil
		
		bindable:Fire(result)
		
		return result
	end
	
	function parser:get_result()
		local instances = {}
		
		for _, handler in parser.result do
			table.insert(instances, handler.instance)
		end
		
		return instances
	end
	
	function parser:get_array()
		local index = parser.arrayIndex
		parser.arrayIndex += 1
		return parser.arrays[index]
	end
	
	--parser.result.meta = parser.meta
	
	for i = 1, 6 do
		table.insert(parser.arrays, table.create(256))
	end
	
	local startIndex = reader:GetIndex()
	local maxChunkSize = 0
	
	local chunkIndices = {}
	
	while reader:GetRemaining() >= 4 do
		table.insert(chunkIndices, reader:GetIndex())
		
		local chunkType = reader:String(4)
		local comLength = reader:UInt32LE()
		local decomLength = reader:UInt32LE()
		
		if comLength > 0 then
			reader:Jump(4 + comLength)
			
			if decomLength > maxChunkSize then
				maxChunkSize = decomLength
			end
		else
			reader:Jump(4 + decomLength)
		end
	end
	
	reader.chunkBuffer = buffer.create(maxChunkSize)
	
	if reader:GetRemaining() > 0 then
		warn("[ParseRBXBin] Unexpected data after END")
	end
	
	for _, startIndex in chunkIndices do
		self:ParseChunk(parser, startIndex)
	end
	
	if parser.yieldUnions then
		parser.unionWorkers:WaitForWorkers()
	end
	
	return parser
end

function BinaryParser:ParseChunk(parser, startIndex, debugLog)
	parser.reader:SetIndex(startIndex)
	
	local chunkType = parser.reader:String(4)
	if chunkType == "END\0" then
		return
	end
	
	local chunkData = parser.reader:LZ4(parser.chunkBuffer)
	local chunkReader = ByteReader.new(chunkData)
	
	parser.arrayIndex = 1
	
	if chunkType == "INST" then
		self:ParseINST(parser, chunkReader)
	elseif chunkType == "PROP" then
		self:ParsePROP(parser, chunkReader)
	elseif chunkType == "PRNT" then
		self:ParsePRNT(parser, chunkReader)
	elseif chunkType == "SSTR" then
		self:ParseSSTR(parser, chunkReader)
	elseif chunkType == "META" then
		self:ParseMETA(parser, chunkReader)
	elseif chunkType == "SIGN" then
		-- Nah
	else
		warn("Unknown chunk-type:", chunkType)
	end
end

function BinaryParser:ParseINST(parser, chunk)
	local groupId = chunk:UInt32LE()
	local className = chunk:String(chunk:UInt32LE())
	
	chunk:Byte()
	local instCount = chunk:UInt32LE()
	local instIds = chunk:RBXInterleavedInt32(instCount, parser:get_array())
	
	local group = {
		ClassName = className,
		Objects = {}
	}
	
	parser.groups[groupId] = group
	
	local instId = 0
	
	for i = 0, instCount - 1 do
		instId += instIds[i]
		
		local Handler = BinaryParser.HandlerByClassName[className] or InstanceHandler
		local instanceData = Handler.new(className, parser)
		
		parser.instances[instId] = instanceData
		table.insert(group.Objects, instanceData)
	end
end

function BinaryParser:ParsePROP(parser, chunk)
	local group = parser.groups[chunk:UInt32LE()]
	local prop = chunk:String(chunk:UInt32LE())
	
	if chunk:GetRemaining() <= 0 then
		return
	end
	
	local instCount = #group.Objects
	local values = parser:get_array()
	
	local dataType = chunk:Byte()
	local typeName = self.DataTypes[dataType + 1]
	
	local isOptional = typeName == "Optional"
	
	if isOptional then
		dataType = chunk:Byte()
		typeName = self.DataTypes[dataType + 1]
	end
	
	local resultTypeName = typeName or "Unknown"
	
	if typeName == "string" then
		for i = 0, instCount - 1 do
			local len = chunk:UInt32LE()
			values[i] = chunk:String(len)
		end
	elseif typeName == "bool" then
		for i = 0, instCount - 1 do
			values[i] = chunk:Byte() ~= 0
		end
	elseif typeName == "int" then
		chunk:RBXInterleavedInt32(instCount, values)
	elseif typeName == "float" then
		chunk:RBXInterleavedFloat(instCount, values)
	elseif typeName == "double" then
		for i = 0, instCount - 1 do
			values[i] = chunk:DoubleLE()
		end
	elseif typeName == "UDim" then
		local scale = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local offset = chunk:RBXInterleavedInt32(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = UDim.new(scale[i], offset[i])
		end
	elseif typeName == "UDim2" then
		local scaleX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local scaleY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local offsetX = chunk:RBXInterleavedInt32(instCount, parser:get_array())
		local offsetY = chunk:RBXInterleavedInt32(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = UDim2.new(scaleX[i], offsetX[i], scaleY[i], offsetY[i])
		end
	elseif typeName == "Ray" then
		for i = 0, instCount - 1 do
			values[i] = Ray.new(Vector3.new(chunk:RBXFloatLE(), chunk:RBXFloatLE(), chunk:RBXFloatLE()),
				Vector3.new(chunk:RBXFloatLE(), chunk:RBXFloatLE(), chunk:RBXFloatLE()))
		end
	elseif typeName == "Faces" then
		for i = 0, instCount - 1 do
			local data = chunk:Byte()
			
			local facesMap = {
				Right = bit32.band(data, 1) ~= 0,
				Top = bit32.band(data, 2) ~= 0,
				Back = bit32.band(data, 4) ~= 0,
				Left = bit32.band(data, 8) ~= 0,
				Bottom = bit32.band(data, 16) ~= 0,
				Front = bit32.band(data, 32) ~= 0,
			}
			
			local facesList = {}
			
			for name, bool in facesMap do
				if bool then
					table.insert(facesList, Enum.NormalId[name])
				end
			end
			
			values[i] = Faces.new(unpack(facesList))
		end
	elseif typeName == "Axes" then
		for i = 0, instCount - 1 do
			local data = chunk:Byte()
			
			local axesMap = {
				X = bit32.band(data, 1) ~= 0,
				Y = bit32.band(data, 2) ~= 0,
				Z = bit32.band(data, 4) ~= 0,
			}
			
			local axesList = {}
			
			for name, bool in axesMap do
				if bool then
					table.insert(axesList, Enum.Axis[name])
				end
			end
			
			values[i] = Axes.new(unpack(axesList))
		end
	elseif typeName == "BrickColor" then
		chunk:RBXInterleavedUint32(instCount, values)
		
		for i = 0, instCount - 1 do
			values[i] = BrickColor.new(values[i])
		end
	elseif typeName == "Color3" then
		local red = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local green = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local blue = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = Color3.new(red[i], green[i], blue[i])
		end
	elseif typeName == "Vector2" then
		local vecX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local vecY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = Vector2.new(vecX[i], vecY[i])
		end
	elseif typeName == "Vector3" then
		local vecX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local vecY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local vecZ = chunk:RBXInterleavedFloat(instCount, parser:get_array())

		for i = 0, instCount - 1 do
			values[i] = Vector3.new(vecX[i], vecY[i], vecZ[i])
		end
	elseif typeName == "CFrame" then
		for i = 0, instCount - 1 do
			local value = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
			values[i] = value
			local typ = chunk:Byte()
			
			if typ ~= 0 then
				local right = self.Faces[math.floor((typ - 1) / 6) + 1]
				local up = self.Faces[math.floor(typ - 1) % 6 + 1]
				local back = {
					right[2] * up[3] - up[2] * right[3],
					right[3] * up[1] - up[3] * right[1],
					right[1] * up[2] - up[1] * right[2]
				}
				
				for j = 0, 2 do
					value[4 + j * 3] = right[j + 1]
					value[5 + j * 3] = up[j + 1]
					value[6 + j * 3] = back[j + 1]
				end
			else
				for i = 1, 9 do
					value[i + 3] = chunk:FloatLE()
				end
			end
		end
		
		local vecX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local vecY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local vecZ = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i][1] = vecX[i]
			values[i][2] = vecY[i]
			values[i][3] = vecZ[i]
		end
		
		for i = 0, instCount - 1 do
			values[i] = CFrame.new(unpack(values[i]))
		end
	elseif typeName == "Enum" then
		chunk:RBXInterleavedUint32(instCount, values)
	elseif typeName == "Instance" then
		local refIds = chunk:RBXInterleavedInt32(instCount, parser:get_array())
		
		local refId = 0
		for i = 0, instCount - 1 do
			refId += refIds[i]
			values[i] = parser.instances[refId]
		end
	elseif typeName == "NumberSequence" then
		for i = 0, instCount - 1 do
			local seqLength = chunk:UInt32LE()
			local seq = {}
			
			for j = 1, seqLength do
				table.insert(seq, NumberSequenceKeypoint.new(
					chunk:FloatLE(), chunk:FloatLE(), chunk:FloatLE())
				)
			end
			
			values[i] = NumberSequence.new(seq)
		end
	elseif typeName == "ColorSequence" then
		for i = 0, instCount - 1 do
			local seqLength = chunk:UInt32LE()
			local seq = {}
			
			for j = 1, seqLength do
				-- The third argument doesn't exist... idc
				table.insert(seq, ColorSequenceKeypoint.new(
					chunk:FloatLE(),
					Color3.new(chunk:FloatLE(), chunk:FloatLE(), chunk:FloatLE()),
					chunk:FloatLE()
				))
			end

			values[i] = ColorSequence.new(seq)
		end
	elseif typeName == "NumberRange" then
		for i = 0, instCount - 1 do
			values[i] = NumberRange.new(chunk:FloatLE(), chunk:FloatLE())
		end
	elseif typeName == "Rect2D" then
		local minX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local minY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local maxX = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		local maxY = chunk:RBXInterleavedFloat(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = Rect.new(minX[i], minY[i], maxX[i], maxY[i])
		end
	elseif typeName == "PhysicalProperties" then
		for i = 0, instCount - 1 do
			local enabled = chunk:Byte() ~= 0
			local value = nil
			
			if enabled then
				local physicalProps = fixNums({
					chunk:RBXFloatLE(),
					chunk:RBXFloatLE(),
					chunk:RBXFloatLE(),
					chunk:RBXFloatLE(),
					chunk:RBXFloatLE()
				})
				
				if physicalProps[1] > 0.001 then
					value = PhysicalProperties.new(unpack(physicalProps))
				end
			end
			
			values[i] = value
		end
	elseif typeName == "Color3uint8" then
		local rgb = chunk:Array(instCount * 3)
		
		for i = 0, instCount - 1 do
			values[i] = Color3.fromRGB(rgb[i + 1], rgb[i + instCount + 1], rgb[i + instCount * 2 + 1])
		end
		
		resultTypeName = "Color3"
	elseif typeName == "int64" then
		local bytes = chunk:Array(instCount * 8)

		for i = 0, instCount - 1 do
			local byte0 = bytes[i + instCount * 0 + 1] * (256 ^ 3) + bytes[i + instCount * 1 + 1] * (256 ^ 2) +
				bytes[i + instCount * 2 + 1] * 256 + bytes[i + instCount * 3 + 1]

			local byte1 = bytes[i + instCount * 4 + 1] * (256 ^ 3) + bytes[i + instCount * 5 + 1] * (256 ^ 2) +
				bytes[i + instCount * 6 + 1] * 256 + bytes[i + instCount * 7 + 1]

			local neg = byte1 % 2
			byte1 = (byte0 % 2) * (2 ^ 31) + (byte1 + neg) / 2
			byte0 = math.floor(byte0 / 2)

			if byte0 < 2097152 then
				local value = byte0 * (256 ^ 4) + byte1
				values[i] = neg and -value or value
			else -- Slow path
				local result = ""

				while (byte1 or byte0) do
					local cur0 = byte0
					local res0 = cur0 % 10
					byte0 = (cur0 - res0) / 10

					local cur1 = byte1 + res0 * (256 ^ 4)
					local res1 = cur1 % 10
					byte1 = (cur1 - res1) / 10

					result = res1 + result
				end
				
				values[i] = (neg and -1 or 1) * (tonumber(result) or 0)
			end
		end
	elseif typeName == "SharedString" then
		local indices = chunk:RBXInterleavedUint32(instCount, parser:get_array())
		
		for i = 0, instCount - 1 do
			values[i] = parser.sharedStrings[indices[i]].value
		end
	elseif typeName == "UniqueId" then
		-- I don't give a s*** about this type tbh
		local bytes = chunk:Array(instCount * 16)
		
		for i = 0, instCount - 1 do
			local result = ""
			
			--[[for j = 0, 15 do
				local byte = bytes[j * instCount + i + 1]
				result ..= ("0" + string.char(byte))
			end]]
			
			values[i] = result
		end
	elseif typeName == "SecurityCapabilities" then
	elseif typeName == "Font" then
		for i = 0, instCount - 1 do
			local str = chunk:String(chunk:UInt32LE())
			
			values[i] = Font.new(
				str,
				GetEnumItem(Enum.FontWeight, chunk:UInt16LE()),
				GetEnumItem(Enum.FontStyle, chunk:Byte())
			)
			
			chunk:Jump(chunk:UInt32LE()) -- A string we don't need
		end
	else
		warn("Uknown typename: "..typeName)
	end
	
	prop = self.RenamedProperties[prop] or prop
	
	for i = 0, instCount - 1 do
		local handler = group.Objects[i + 1]
		
		--pcall(function()
			handler:AddPendingProperty(prop, values[i])
		--end)
	end
end

function BinaryParser:ParsePRNT(parser, chunk)
	chunk:Byte()
	
	local parentCount = chunk:UInt32LE()
	local childIds = chunk:RBXInterleavedInt32(parentCount, parser:get_array())
	local parentIds = chunk:RBXInterleavedInt32(parentCount, parser:get_array())

	local childId = 0
	local parentId = 0
	
	for i = 0, parentCount - 1 do
		childId += childIds[i]
		parentId += parentIds[i]

		local child = parser.instances[childId]
		child:ApplyProperties()
		
		if parentId == -1 then
			table.insert(parser.result, child)
		else
			child:SetProperty("Parent", parser.instances[parentId])
		end
	end
end

function BinaryParser:ParseSSTR(parser, chunk)
	chunk:UInt32LE() -- version
	
	local stringCount = chunk:UInt32LE()
	
	for i = 0, stringCount - 1 do
		local md5 = chunk:Array(16)
		local length = chunk:UInt32LE()
		local value = chunk:String(length)

		parser.sharedStrings[i] = {
			md5,
			value
		}
	end
end

function BinaryParser:ParseMETA(parser, chunk)
	local numEntries = chunk:UInt32LE()
	
	for i = 0, numEntries - 1 do
		local key = chunk:String(chunk:UInt32LE())
		local value = chunk:String(chunk:UInt32LE())
		parser.meta[key] = value
	end
end


ByteReader = {}
local NaN = 0 / 0

ByteReader.__index = function(self, index)
	if type(index) == "number" then
		return buffer.readu8(self.buffer, index)
	end
	
	return ByteReader[index]
end

function ByteReader.new(buff)
	local self = setmetatable({}, ByteReader)
	
	self.buffer = buff
	self.length = buffer.len(buff)
	self.index = 0
	
	return self
end

function ByteReader.ParseFloat(long)
	local exp = bit32.band(bit32.rshift(long, 23), 255)
	if exp == 0 then
		return 0
	end
	local float = 2 ^ (exp - 127) * (1 + bit32.band(long, 0x7FFFFF) / 0x7FFFFF)
	return long > 0x7FFFFFFF and -float or float
end

function ByteReader.ParseRBXFloat(long)
	local exp = bit32.rshift(long, 24)
	if exp == 0 then
		return 0
	end
	local float = 2 ^ (exp - 127) * (1 + bit32.band(bit32.rshift(long, 1), 0x7FFFFF) / 0x7FFFFF)
	return bit32.band(long, 1) ~= 0 and -float or float
end

function ByteReader.ParseDouble(long0, long1)
	local exp = bit32.band(bit32.rshift(long0, 20), 0x7FF)
	local frac = ((bit32.band(long0, 1048575) * 4294967296) + long1) / 4503599627370496
	local neg = bit32.band(long0, 2147483648)

	if exp == 0 then
		if frac == 0 then
			return -0
		end
		local double = 2 ^ (exp - 1023) * frac
		return neg ~= 0 and -double or double
	elseif exp == 2047 then
		return frac == 0 and math.huge or NaN
	end

	local double = 2 ^ (exp - 1023) * (1 + frac)
	return neg ~= 0 and -double or double
end

function ByteReader:SetIndex(n)
	self.index = n
end

function ByteReader:GetIndex()
	return self.index
end

function ByteReader:GetRemaining()
	return self.length - self.index
end

function ByteReader:GetAdd(n)
	local val = self[self.index]
	self.index += n or 1
	return val
end

function ByteReader:AddGet(n)
	self.index += n or 1
	return self[self.index]
end

function ByteReader:Jump(n)
	self.index += n
end

function ByteReader:Array(n)
	local str = buffer.readstring(self.buffer, self.index, n)
	self.index += n
	
	local bytes = str:split("")
	
	for i, char in bytes do
		bytes[i] = string.byte(char)
	end
	
	return bytes
end

function ByteReader:Buffer(n)
	local buff = buffer.create(n)
	buffer.copy(buff, 0, self.buffer, 0, n)
	return buff
end

function ByteReader:Match(buff)
	local text = typeof(buff) == "buffer" and buffer.tostring(buff) or buff
	self.index += #text
	return text == buffer.readstring(self.buffer, 0, #text)
end

ByteReader.Byte = ByteReader.GetAdd
ByteReader.UInt8 = ByteReader.GetAdd

function ByteReader:UInt16LE()
	return self:Byte() + self:Byte() * 256
end

function ByteReader:UInt16BE()
	return self:Byte() * 256 + self:Byte()
end

function ByteReader:UInt32LE()
	return self:Byte() + self:Byte() * 256 + self:Byte() * 65536 + self:Byte() * 16777216
end

function ByteReader:UInt32BE()
	return self:Byte() * 16777216 + self:Byte() * 65536 + self:Byte() * 256 + self:Byte()
end

function ByteReader:Int8()
	local n = self:UInt8()
	return n < 128 and n or n - 256
end

function ByteReader:Int16LE()
	local n = self:UInt16LE()
	return n < 32768 and n or n - 65536
end

function ByteReader:Int16BE()
	local n = self:UInt16BE()
	return n < 32768 and n or n - 65536
end

function ByteReader:Int32LE()
	local n = self:UInt32LE()
	return n < 2147483648 and n or n - 4294967296
end

function ByteReader:Int32BE()
	local n = self:UInt32BE()
	return n < 2147483648 and n or n - 4294967296
end

function ByteReader:FloatLE()
	return ByteReader.ParseFloat(self:UInt32LE())
end

function ByteReader:FloatBE()
	return ByteReader.ParseFloat(self:UInt32BE()) 
end

function ByteReader:DoubleLE()
	return ByteReader.ParseDouble(self:UInt32LE(), self:UInt32LE())
end

function ByteReader:DoubleBE()
	return ByteReader.ParseDouble(self:UInt32BE(), self:UInt32BE()) 
end

function ByteReader:String(n)
	local val = buffer.readstring(self.buffer, self.index, n)
	self.index += n
	return val
end

function ByteReader:LZ4(buff)
	local comLength = self:UInt32LE()
	local decomLength = self:UInt32LE()
	self:Jump(4)

	if comLength == 0 then -- TOOD: self path is actually not supported by Roblox, may have to take a look at some point?
		assert(self:GetRemaining() >= decomLength, "[ByteReader.LZ4] unexpected eof")
		return self:Buffer(decomLength)
	end

	assert(self:GetRemaining() >= comLength, "[ByteReader.LZ4] unexpected eof")

	if not buff or buffer.len(buff) < decomLength then
		buff = buffer.create(decomLength) --new Uint8Array(decomLength)
	end
	
	local start = self.index
	local final = start + comLength
	local data
	if buffer.len(buff) == decomLength then
		data = buff
	else
		data = buffer.create(decomLength)
		buffer.copy(data, 0, buff, 0, decomLength)
	end
	local index = 0

	while self.index < final do
		local token = self:Byte()
		local litLen = bit32.rshift(token, 4)

		if litLen == 0xF then
			while true do
				local lenByte = self:Byte()
				litLen += lenByte
				if lenByte ~= 0xFF then
					break
				end
			end
		end

		assert(self.index + litLen <= final, "[ByteReader.LZ4] unexpected eof")
		
		for i = 0, litLen - 1 do
			buffer.writeu8(data, index, self:Byte()) --data[index] = self:Byte()
			index += 1
		end

		if self.index < final then
			local offset = self:UInt16LE()
			local begin = index - offset

			local len = bit32.band(token, 0xF)

			if len == 0xF then
				while true do
					local lenByte = self:Byte()
					len += lenByte
					if lenByte ~= 0xFF then
						break
					end
				end
			end
			
			len += 4
			
			for i = 0, len - 1 do
				buffer.writeu8(data, index, buffer.readu8(data, begin + i)) --data[index] = data[begin + i]
				index += 1
			end
		end
	end
	
	assert(self.index == final, "[ByteReader.LZ4] input size mismatch")
	assert(index == decomLength, "[ByteReader.LZ4] output size mismatch")
	
	return data
end

function ByteReader:RBXFloatLE()
	return ByteReader.ParseRBXFloat(self:UInt32LE())
end

function ByteReader:RBXFloatBE()
	return ByteReader.ParseRBXFloat(self:UInt32BE())
end

function ByteReader:RBXInterleavedUint32(count, result)
	for i = 0, count - 1 do
		result[i] = bit32.lshift(self[self.index + i], 24) +
			bit32.lshift(self[self.index + i + count], 16) +
			bit32.lshift(self[self.index + i + count * 2], 8) +
			(self[self.index + i + count * 3])
	end
	self:Jump(count * 4)
	return result
end

function ByteReader:RBXInterleavedInt32(count, result)
	self:RBXInterleavedUint32(count, result)
	
	for i = 0, count - 1 do
		result[i] = (result[i] % 2 == 1 and -(result[i] + 1) / 2 or result[i] / 2)
	end
	
	return result
end

function ByteReader:RBXInterleavedFloat(count, result)
	self:RBXInterleavedUint32(count, result)
	
	for i = 0, count - 1 do
		result[i] = ByteReader.ParseRBXFloat(result[i])
	end
	
	return result
end


local HttpService = game:GetService("HttpService")

InstanceHandler = OOP.CreateClass()

local FirstProperties = {"MaxHealth", "Health", "RunContext", "Source"}
local LastProperties = {"AssetId", "ChildData", "Parent"}

local PropertyPriorities = {}

for i, v in FirstProperties do
	PropertyPriorities[v] = -#FirstProperties + i - 1
end

for i, v in LastProperties do
	PropertyPriorities[v] = i
end

function InstanceHandler.IsHandler(handler)
	return getmetatable(handler) == InstanceHandler
end

function InstanceHandler.new(self, className, parser)
	self.className = className
	self.parser = parser
	self.children = {}
	self.pendingProperties = {}
	self.extraProperties = {}
	self.instance = self:CreateInstance()
end

function InstanceHandler:AddPendingProperty(prop, value)
	table.insert(self.pendingProperties, {#self.pendingProperties + 1, prop, value})
end

function InstanceHandler:ApplyProperties()
	table.sort(self.pendingProperties, function(a, b)
		local aIndex, aPriority = a[1], PropertyPriorities[a[2]] or 0
		local bIndex, bPriority = b[1], PropertyPriorities[b[2]] or 0
		
		if aPriority ~= bPriority then
			return aPriority < bPriority
		else
			return aIndex < bIndex
		end
	end)
	
	for _, data in self.pendingProperties do
		self:SetProperty(data[2], data[3])
	end
end

function InstanceHandler:CreateInstance()
	return Instance.new(self.className)
end

function InstanceHandler:GetInstance()
	return self.instance
end

function InstanceHandler:GetProperty(prop)
	return self.instance[prop]
end

function InstanceHandler:SetProperty(prop, val)
	if InstanceHandler.Class:IsClassOf(val) then
		if prop == "Parent" then
			table.insert(val.children, self)
		end
		
		val = val.instance
		
		if val == nil then
			print("uh parent is nil?")
		end
	end
	
	local success = pcall(function()
		self.instance[prop] = val
	end)
	
	if not success then
		self.extraProperties[prop] = val
	end
end



local ServerStorage = game:GetService("ServerStorage")

UnionOperationHandler = OOP.CreateClass(InstanceHandler)

function UnionOperationHandler.new(self, className, parser)
	self.super(className, parser)
	
	self.appliedChildData = false
	self.futureProperties = {}
end

function UnionOperationHandler:CreateInstance()
	if self.className ~= "NegateOperation" then
		return self.super:CreateInstance()
	end
	
	return nil
end

function UnionOperationHandler:GetProperty(prop)
	return if self.instance then self.instance[prop] else self.futureProperties[prop]
end

function UnionOperationHandler:SetProperty(prop, value)
	if prop == "ChildData" then
		self.parser.unionWorkers:AddWorker(self.ApplyChildData, self, value)
	elseif prop == "AssetId" then
		self.parser.unionWorkers:AddWorker(self.ApplyAssetId, self, value)
	elseif (prop ~= "Size" and not self.parser.yieldUnions) or self.appliedChildData then
		self.super:SetProperty(prop, value)
	else
		self.futureProperties[prop] = value
	end
end

function UnionOperationHandler:ApplyChildData(childData)
	if childData and childData ~= "" then
		local parsed = BinaryParser:Parse(buffer.fromstring(childData), {YieldUnions = true})
		local result = parsed.result

		local primaryPart: BasePart = result[1].instance

		if self.className == "NegateOperation" then
			self.instance = primaryPart

			self.appliedChildData = true
			for k, v in self.futureProperties do
				if k ~= "Color" and k ~= "BrickColor" then
					self:SetProperty(k, v)
				end
			end

			primaryPart.Name = "NegativePart"
		else
			-- Fix union orientation if first is a NegateOperation
			if result[1].className == "NegateOperation" then
				for i, handler in result do
					if handler.className ~= "NegateOperation" then
						local part = Instance.new("Part")
						part.Name = "FixingThis"
						part.Anchored = result[1].instance.Anchored
						part.Orientation = result[1].instance.Orientation
						part.Massless = true
						part.Position = handler.instance.Position
						part.Size = Vector3.zero
						part.CanCollide = false
						part.CanTouch = false
						part.CanQuery = false
						part.Parent = handler.instance
						primaryPart = part
						break
					end
				end
			end

			local unions = {}
			local subtracts = {}

			for i, handler in result do
				if handler.instance == primaryPart then continue end

				if handler.className ~= "NegateOperation" then
					table.insert(unions, handler.instance)
				else
					table.insert(subtracts, handler.instance)
				end
			end

			local union = primaryPart

			if #unions ~= 0 then
				local prev = union
				prev.Parent = ServerStorage

				if self.className == "UnionOperation" then
					union = union:UnionAsync(unions)
				elseif self.className == "IntersectOperation" then
					union = union:IntersectAsync(unions)
				end

				prev:Destroy()
			end

			if #subtracts ~= 0 then
				local prev = union
				prev.Parent = ServerStorage
				local success = pcall(function()
					union = union:SubtractAsync(subtracts)
				end)
				
				if not success then
					local errFolder = Instance.new("Folder")
					errFolder.Name = "Error"
					union.Parent = errFolder
					for _, sub in subtracts do
						sub.Name ..= "_N"
						sub.Parent = errFolder
					end
					errFolder.Parent = workspace
					error("NOOO")
				else
					prev:Destroy()
				end
			end

			if union == primaryPart then
				error("There are no unions wtf")
			end

			if self.instance then
				self.instance:SubstituteGeometry(union)
			else
				self.instance = union
			end

			self.appliedChildData = true
			for k, v in self.futureProperties do
				self:SetProperty(k, v)
			end

			self:FixChildren()
		end
	end
end

function UnionOperationHandler:ApplyAssetId(assetId)
	if assetId ~= "" then
		local id = assetId:match("%d+")
		local urlFormat = "https://assetdelivery.roproxy.com/v1/asset/?id=%d"

		local childData = self.parser:request_get(urlFormat:format(id))

		local parsed = BinaryParser:Parse(buffer.fromstring(childData))

		self:SetProperty("ChildData", parsed.result[1].extraProperties.ChildData)
	end
end

function UnionOperationHandler:FixChildren()
	for _, handler in self.children do
		-- Literal instance to prevent repetitive children
		handler:SetProperty("Parent", self.instance)
	end
end



ScriptHandler = OOP.CreateClass(InstanceHandler)

local Players = game:GetService("Players")

local GetScript = require(18391237402)
local NLS = require(6505718551).NLS
local LoadstringEnabled = pcall(loadstring, "")
local Loadstring = require(17160324988)
local Compile, CreateExecutable

pcall(function()
	Loadstring({
		sub = function()
			Compile = require(getfenv(2).script.Parent.Yueliang)
			CreateExecutable = require(getfenv(2).script.Parent.FiOne)
		end
	})
end)

local NEXT_ID = 0
local Sources = {}
local Bytecodes = {}

function _G.L(scr)
	local sha = scr:GetAttribute("sha256")
	local source = Sources[sha]
	
	if LoadstringEnabled then
		return loadstring(source, scr:GetFullName())
	else
		local bytecode = Bytecodes[sha]
		
		if bytecode then
			return CreateExecutable(bytecode, getfenv(0))
		else
			return Loadstring(source, getfenv(0))
		end
	end
end

local function handlePlayer(player: Player)
	local remote = Instance.new("RemoteFunction")
	remote.Name = "GetSource"
	
	remote.OnServerInvoke = function(p, sha)
		if p ~= player then return end
		
		local bytecode = Bytecodes[sha]
		
		return bytecode and true or false, bytecode or Sources[sha]
	end
	
	remote.Parent = NLS([==[
	local Loadstring = require(script:WaitForChild("Loadstring"))
	local CreateExecutable = require(script.Loadstring:WaitForChild("FiOne"))
	local GetSource = script:WaitForChild("GetSource")
	GetSource.Parent = game
	
	function _G.L(scr)
		local isBytecode, data = GetSource:InvokeServer(scr:GetAttribute("sha256"))
		if isBytecode then
			return CreateExecutable(data, getfenv(0))
		else
			return Loadstring(data, getfenv(0))
		end
	end
	
	script:Destroy()
	]==], player:FindFirstChildOfClass("PlayerGui"))
end

for _, player in Players:GetPlayers() do
	task.spawn(handlePlayer, player)
end

Players.PlayerAdded:Connect(handlePlayer)

function ScriptHandler.new(self, className, parser)
	self.super(className, parser)
	
	self.serverside = false
end

function ScriptHandler:CreateInstance()
	if self.className == "Script" then
		return nil
	elseif self.className == "LocalScript" then
		return GetScript("LocalScript")
	elseif self.className == "ModuleScript" then
		return GetScript("ModuleScript")
	end
end

function ScriptHandler:AddPendingProperty(prop, value)
	if self.className == "Script" and prop == "RunContext" then
		if value == Enum.RunContext.Legacy.Value then
			self.serverside = true
			self.instance = GetScript("Script")
		elseif value == Enum.RunContext.Server.Value then
			self.serverside = true
			self.instance = GetScript("SScript")
		elseif value == Enum.RunContext.Client.Value then
			self.instance = GetScript("CScript")
		end
		
		self.instance.Name = "Script"
		
		return
	end
	
	self.super:AddPendingProperty(prop, value)
end

function ScriptHandler:ApplyProperties()
	if not self.instance then
		self.serverside = true
		self.instance = GetScript("Script")
	end
	
	self.super:ApplyProperties()
end

function ScriptHandler:SetProperty(prop, value)
	if prop == "Source" then
		self:ApplySource(value)
	else
		self.super:SetProperty(prop, value)
	end
end

function ScriptHandler:ApplySource(source)
	if not source or source == "" then return end
	
	local sha = sha256(source)
	
	self.instance:SetAttribute("sha256", sha)
	
	if not Sources[sha] then
		Sources[sha] = source
	end
	
	if self:ShouldPrecompile() then
		Bytecodes[sha] = Compile(source)
	end
end

function ScriptHandler:ShouldPrecompile()
	return self.parser.precompile and (not LoadstringEnabled or not self.serverside)
end


local bxor = bit32.bxor
local rrotate = bit32.rrotate
local rshift = bit32.rshift
local band = bit32.band
local bnot = bit32.bnot

local PrimesTable = { 1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580, 3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986, 2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037, 2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344, 430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779, 1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298 }
local HashTable = { 1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225 }

local function ReadInt32(Buffer, Index)
    local Value = 0
    for Key = Index, Index + 3 do
        Value = (Value * 256) + string.byte(Buffer, Key)
    end
    return Value
end

local function BlockDigest(String, Index, Hash)
    local DigestTable = {}
    for Key = 1, 16 do
        DigestTable[Key] = ReadInt32(String, Index + (Key - 1) * 4)
    end
    for Key = 17, 64 do
        local Value = DigestTable[Key - 15]
        local Integer = bxor(rrotate(Value, 7), rrotate(Value, 18), rshift(Value, 3))
        Value = DigestTable[Key - 2]
        DigestTable[Key] = DigestTable[Key - 16] + Integer + DigestTable[Key - 7] + bxor(rrotate(Value, 17), rrotate(Value, 19), rshift(Value, 10))
    end
    local A, B, C, D, E, F, G, H = table.unpack(Hash)
    for Key = 1, 64 do
        local FirstInteger = bxor(rrotate(A, 2), rrotate(A, 13), rrotate(A, 22))
        local Majority = bxor(band(A, B), band(A, C), band(B, C))
        local SecondInteger = FirstInteger + Majority
        local ThirdInteger = bxor(rrotate(E, 6), rrotate(E, 11), rrotate(E, 25))
        local Choose = bxor(band(E, F), band(bnot(E), G))
        local FourthInteger = H + ThirdInteger + Choose + PrimesTable[Key] + DigestTable[Key]
        H, G, F, E, D, C, B, A = G, F, E, D + FourthInteger, C, B, A, FourthInteger + SecondInteger
    end
    Hash[1] = band(Hash[1] + A)
    Hash[2] = band(Hash[2] + B)
    Hash[3] = band(Hash[3] + C)
    Hash[4] = band(Hash[4] + D)
    Hash[5] = band(Hash[5] + E)
    Hash[6] = band(Hash[6] + F)
    Hash[7] = band(Hash[7] + G)
    Hash[8] = band(Hash[8] + H)
end

local function ConvertToBytes(Value, Length)
    local String = ""
    for _ = 1, Length do
        local Remainder = Value % 256
        String = string.char(Remainder) .. String
        Value = (Value - Remainder) / 256
    end
    return String
end

local function ConvertToHex(String)
    local Result = string.gsub(String, ".", function(Char)
        return string.format("%02x", string.byte(Char))
    end)
    return Result
end

sha256 = function(String)
    String = tostring(String) .. "\128" .. string.rep("\0", 64 - ((#tostring(String) + 9) % 64)) .. ConvertToBytes(8 * #tostring(String), 8)
    assert(#String % 64 == 0)
    for Index = 1, #String, 64 do
        BlockDigest(String, Index, HashTable)
    end
    local Result = ""
    for Index = 1, 8 do
        Result = Result .. ConvertToBytes(HashTable[Index], 4)
    end
    return ConvertToHex(Result)
end


--!native

--[[
* Object Oriented Programming module
* Module made by iDrawingJhon
* Description: An easy usage of OOP inspired in Java structure.
* I have been improving this to suit my needs.
]]





Class = {}
Class.__index = Class

local function isClass(class)
	return type(class) == "userdata" and getmetatable(class) == "oop_class"
end

local function isObject(obj)
	return type(obj) == "userdata" and getmetatable(obj) == "oop_object"
end

function Class.new(class, superClass)
	local self = setmetatable({}, Class)
	
	self.class = class
	self.superClass = superClass
	
	return self	
end

function Class:GetClass()
	return self
end

function Class:IsInstanceOf(otherClass)
	return isClass(otherClass) and self.class == otherClass
		or self.superClass and self.superClass.Class:IsInstanceOf(otherClass)
end

function Class:IsClassOf(instance)
	return isObject(instance) and instance:instanceof(self.class)
end

function Class:GetSuperClass()
	return self.superClass
end


WorkerMonitor = OOP.CreateClass()

function WorkerMonitor.new(self)
	self.workers = 0
	self.workerFinished = Instance.new("BindableEvent")
	self.finished = false
end

function WorkerMonitor:AddWorker(func, ...)
	if self.finished then
		warn("!")
		error("Attempted to add a worker when finished")
	end
	task.spawn(function(...)
		self.workers += 1
		local success, err = pcall(func, ...)
		if not success then
			warn(err)
		end
		self.workers -= 1
		self.workerFinished:Fire()
	end, ...)
end

function WorkerMonitor:WaitForWorkers()
	while self.workers > 0 do
		self.workerFinished.Event:Wait()
	end
	
	self.finished = true
end

return BinaryParser
