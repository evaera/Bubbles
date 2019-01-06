--[[
	Bubbles are composable objects
]]


local function deepCopy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = setmetatable({}, getmetatable(obj))
  for k, v in pairs(obj) do res[deepCopy(k)] = deepCopy(v) end
  return res
end

local function assign(toObj, ...)
	for _, fromObj in ipairs({...}) do
		for key, value in pairs(fromObj) do
			toObj[key] = deepCopy(value)
		end
	end

	return toObj
end

local function arrayConcat(...)
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

local function tableType(value)
	local valueType = type(value)

	if valueType == "table" then
		return #value > 0 and "array" or "dictionary"
	else
		return valueType
	end
end

local function merge(toObj, fromObj)
	for key, value in pairs(fromObj) do
		local valueType = tableType(value)
		if type(value) ~= "table" or tableType(toObj[key]) ~= valueType then
			toObj[key] = value -- Not deep copied
		elseif valueType == "dictionary" then
			merge(toObj[key], value)
		elseif valueType == "array" then
			toObj[key] = arrayConcat(toObj[key], value)
		end
	end
end

local MakeBubble, BubbleCompose -- forward declarations

local function isBubble(value)
	return type(value) == "table" and type(value.compose) == "table" and getmetatable(value.compose) == getmetatable(BubbleCompose)
end

local BubbleComposeShorthands = {
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

-- Default metadata object
BubbleCompose = setmetatable({
	name = "Bubble";
	initializers = {};
	props = {};
	deepProps = {};
	composers = {};
	methods = {};
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

		for i, bubble in ipairs(composables) do
			local compose = bubble.compose or bubble

			if type(compose) == "string" then
				compose = {name = compose}
				composables[i] = compose
			end

			if type(compose) ~= "table" then
				error(("Invalid type %s given for composition; must be a Bubble, dictionary, or string."):format(type(compose)), 2)
			end

			for key, shorthand in pairs(BubbleComposeShorthands) do
				if type(compose[key]) == "function" then
					compose[key] = shorthand(compose, compose[key])
				end
			end

			table.insert(descriptors, compose)
			table.insert(initializers, compose.initializers)
			table.insert(composers, compose.composers)
			table.insert(props, compose.props)
			table.insert(methods, compose.methods)

			descriptor.name = compose.name or descriptor.name

			merge(deepProps, compose.deepProps or {})
		end


		descriptor.initializers = arrayConcat(unpack(initializers))
		descriptor.composers = arrayConcat(unpack(composers))
		descriptor.props = assign({}, unpack(props))
		descriptor.methods = assign({}, unpack(methods))
		descriptor.deepProps = deepProps

		local bubble = MakeBubble(descriptor)

		for _, composer in ipairs(bubble.compose.composers) do
			local result = composer(bubble, composables)
			bubble = result ~= nil and result or bubble
		end

		return bubble
	end
})

local UtilityFunctions do
	UtilityFunctions = {}

	local function addKeys(t)
		for key in pairs(t) do
			UtilityFunctions[key] = true
		end
	end

	addKeys(BubbleCompose)
	addKeys(BubbleComposeShorthands)
end

function MakeBubble(descriptor)
	local Bubble = {}
	Bubble.__index = Bubble
	Bubble.__tostring = function(self)
		return self.compose.name
	end
	Bubble.compose = setmetatable(
		assign({}, BubbleCompose, descriptor),
		getmetatable(BubbleCompose)
	)

	setmetatable(Bubble, {
		__index = Bubble.compose.methods;

		__call = function(self, ...)
			return self:compose(...)
		end;
	})

	for key, value in pairs(Bubble.compose) do
		if BubbleCompose[key] == nil then
			error(("Invalid key %q in Bubble descriptor"):format(key), 2)
		end

		if value ~= nil and type(value) ~= type(BubbleCompose[key]) then
			error(("Invalid type %s for key %q in Bubble descriptor"):format(type(value), key), 2)
		end
	end

	-- Constructor
	function Bubble.new(options, ...)
		options = options or {}
		assert(type(options) == "table", ("Bad argument #1 to %s.new: must be a table or nil"):format(Bubble.compose.name))
		assert(select("#", ...) == 0, ("%s.new only accepts one argument (a dictionary)."):format(Bubble.compose.name))

		local self = setmetatable({}, Bubble)

		for key, value in pairs(self.compose.deepProps) do
			self[key] = value
		end

		for key, value in pairs(self.compose.props) do
			self[key] = value
		end

		for _, init in ipairs(self.compose.initializers) do
			local value = init(self, options)
			self = value ~= nil and value or self
		end

		return self
	end

	-- Utility functions
	for name in pairs(UtilityFunctions) do
		Bubble[name] = function(self, value)
			return self:compose({
				[name] = value
			})
		end
	end

	return Bubble
end

return {
	Bubble = MakeBubble({});

	deepCopy = deepCopy;
	assign = assign;
	arrayConcat = arrayConcat;
	tableType = tableType;
	merge = merge;
	isBubble = isBubble;
}
