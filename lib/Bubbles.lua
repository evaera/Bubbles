--[[
	Bubbles are composable objects
]]

-- Forward declarations
local MakeBubble, Descriptor

local Util = {} do
	function Util.deepCopy(obj)
		if type(obj) ~= 'table' then return obj end
		local res = setmetatable({}, getmetatable(obj))
		for k, v in pairs(obj) do res[Util.deepCopy(k)] = Util.deepCopy(v) end
		return res
	end

	function Util.assign(toObj, ...)
		for _, fromObj in ipairs({...}) do
			for key, value in pairs(fromObj) do
				toObj[key] = Util.deepCopy(value)
			end
		end

		return toObj
	end

	function Util.arrayConcat(...)
		local result = {}
		local seen = {} -- for de-duping

		for _, t in pairs({...}) do
			for _, arrayValue in ipairs(t) do
				if not seen[arrayValue] then
					table.insert(result, arrayValue)
					seen[arrayValue] = true
				end
			end
		end

		return result
	end

	function Util.tableType(value)
		local valueType = type(value)

		if valueType == "table" then
			return #value > 0 and "array" or "dictionary"
		else
			return valueType
		end
	end

	function Util.merge(toObj, fromObj)
		for key, value in pairs(fromObj) do
			local valueType = Util.tableType(value)
			if type(value) ~= "table" or Util.tableType(toObj[key]) ~= valueType then
				toObj[key] = value -- Not deep copied
			elseif valueType == "dictionary" then
				Util.merge(toObj[key], value)
			elseif valueType == "array" then
				toObj[key] = Util.arrayConcat(toObj[key], value)
			end
		end
	end

	function Util.isBubble(value)
		return type(value) == "table" and (type(value.compose) == "table" and getmetatable(value.compose) == getmetatable(Descriptor)) or (type(getmetatable(value).compose) == "table" and getmetatable(getmetatable(value).compose) == getmetatable(Descriptor))
	end
end

--[[ Descriptor ]]--
do
	local DescriptorFunctions = {
		init = function(descriptor, callback)
			if descriptor.initializers == nil then
				descriptor.initializers = {}
			end

			table.insert(descriptor.initializers, callback)
		end;

		methods = function(_, callback)
			local methods = setmetatable({}, {
				__newindex = function(self, k, v)
					if type(v) ~= "function" then
						error("Only functions can be defined as methods.", 2)
					end
					rawset(self, k, v)
				end
			})
			callback(methods)
			return methods
		end
	}

	Descriptor = setmetatable({
		name = "Bubble";
		initializers = {};
		props = {};
		deepProps = {};
		composers = {};
		methods = {};
		statics = {};
		deepStatics = {};
	}, {
		-- TODO: Compose with non-Bubble objects by checking for .new
		__call = function(...)
			local composables = {...}
			local descriptor = {}
			local descriptors = {}
			local initializers = {}
			local composers = {}
			local props = {}
			local methods = {}
			local deepProps = {}
			local statics = {}
			local deepStatics = {}

			for i, bubble in ipairs(composables) do
				local compose = bubble.compose or bubble

				if type(compose) == "string" then
					compose = {name = compose}
					composables[i] = compose
				end

				if type(compose) ~= "table" then
					error(("Invalid type %s given for composition; must be a Bubble, dictionary, or string."):format(type(compose)), 2)
				end

				for key, shorthand in pairs(DescriptorFunctions) do
					if type(compose[key]) == "function" then
						compose[key] = shorthand(compose, compose[key])
					end
				end

				table.insert(descriptors, compose)
				table.insert(initializers, compose.initializers)
				table.insert(composers, compose.composers)
				table.insert(props, compose.props)
				table.insert(methods, compose.methods)
				table.insert(statics, compose.statics)

				descriptor.name = compose.name or descriptor.name

				Util.merge(deepProps, compose.deepProps or {})
				Util.merge(deepStatics, compose.deepStatics or {})
			end

			descriptor.initializers = Util.arrayConcat(unpack(initializers))
			descriptor.composers = Util.arrayConcat(unpack(composers))
			descriptor.props = Util.assign({}, unpack(props))
			descriptor.methods = Util.assign({}, unpack(methods))
			descriptor.statics = Util.assign({}, unpack(statics))
			descriptor.deepProps = deepProps
			descriptor.deepStatics = deepStatics

			local bubble = MakeBubble(descriptor)

			for _, composer in ipairs(bubble.compose.composers) do
				local result = composer(bubble, composables)
				bubble = result ~= nil and result or bubble
			end

			return bubble
		end
	})

	do
		local function addKeys(t)
			for key in pairs(t) do
				Descriptor.statics[key] = function(self, value)
					return self:compose({
						[key] = value
					})
				end
			end
		end

		addKeys(Descriptor)
		addKeys(DescriptorFunctions)
	end
end

--[[ MakeBubble ]]--
do
	local function bubbleCall(self, ...)
		return self:compose(...)
	end

	function MakeBubble(descriptor)
		local Bubble = {}

		Bubble.compose = setmetatable(
			Util.assign({}, Descriptor, descriptor),
			getmetatable(Descriptor)
		)

		Bubble.__tostring = function()
			return Bubble.compose.name
		end

		Bubble.__index = Bubble.compose.methods

		setmetatable(Bubble, { __call = bubbleCall })

		for key, value in pairs(Bubble.compose) do
			if Descriptor[key] == nil then
				error(("Invalid key %q in Bubble descriptor"):format(key), 2)
			end

			if value ~= nil and type(value) ~= type(Descriptor[key]) then
				error(("Invalid type %s for key %q in Bubble descriptor"):format(type(value), key), 2)
			end
		end

		-- Constructor
		function Bubble.new(options, ...)
			options = options or {}
			assert(type(options) == "table", ("Bad argument #1 to %s.new: must be a table or nil"):format(Bubble.compose.name))
			assert(select("#", ...) == 0, ("%s.new only accepts one argument (a dictionary)."):format(Bubble.compose.name))

			local self = setmetatable({}, Bubble)

			for key, value in pairs(Bubble.compose.deepProps) do
				self[key] = value
			end

			for key, value in pairs(Bubble.compose.props) do
				self[key] = value
			end

			for _, init in ipairs(Bubble.compose.initializers) do
				local value = init(self, options)
				self = value ~= nil and value or self
			end

			return self
		end

		for key, value in pairs(Bubble.compose.deepStatics) do
			Bubble[key] = value
		end

		for key, value in pairs(Bubble.compose.statics) do
			Bubble[key] = value
		end

		return Bubble
	end
end

return {
	Bubble = MakeBubble({});
	Util = Util;
}
