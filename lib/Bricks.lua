--[[
	Bricks are composable objects
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

local MakeBrick, BrickCompose -- forward declarations

local function isBrick(value)
	return type(value) == "table" and type(value.compose) == "table" and getmetatable(value.compose) == getmetatable(BrickCompose)
end

local BrickComposeShorthands = {
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
BrickCompose = setmetatable({
	name = "Brick";
	initializers = {};
	props = {};
	deepProps = {};
	composers = {};
	methods = {};
}, {
	-- TODO: Compose with non-Brick objects by checking for .new
	__call = function(...)
		local composables = {...}
		local descriptor = {}
		local descriptors = {}
		local initializers = {}
		local composers = {}
		local props = {}
		local methods = {}
		local deepProps = {}

		for i, brick in ipairs(composables) do
			local compose = brick.compose or brick

			if type(compose) == "string" then
				compose = {name = compose}
				composables[i] = compose
			end

			if type(compose) ~= "table" then
				error(("Invalid type %s given for composition; must be a Brick, dictionary, or string."):format(type(compose)), 2)
			end

			for key, shorthand in pairs(BrickComposeShorthands) do
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

		local brick = MakeBrick(descriptor)

		for _, composer in ipairs(brick.compose.composers) do
			local result = composer(brick, composables)
			brick = result ~= nil and result or brick
		end

		return brick
	end
})

function MakeBrick(descriptor)
	local Brick = setmetatable({}, {
		__index = function(self, key) -- Default properties
			if self.compose.props[key] ~= nil then
				return self.compose.props[key]
			end

			return self.compose.deepProps[key]
		end;

		__call = function(self, ...)
			return self:compose(...)
		end;
	})
	Brick.__index = Brick
	Brick.__tostring = function(self)
		return self.compose.name
	end
	Brick.compose = setmetatable(assign({}, BrickCompose, descriptor), getmetatable(BrickCompose))

	for key, value in pairs(Brick.compose) do
		if BrickCompose[key] == nil then
			error(("Invalid key %q in Brick descriptor"):format(key), 2)
		end

		if value ~= nil and type(value) ~= type(BrickCompose[key]) then
			error(("Invalid type %s for key %q in Brick descriptor"):format(type(value), key), 2)
		end
	end

	for methodName, method in pairs(Brick.compose.methods) do
		Brick[methodName] = method
	end

	-- Constructor
	function Brick.new(options, ...)
		options = options or {}
		assert(type(options) == "table", ("Bad argument #1 to %s.new: must be a table or nil"):format(Brick.compose.name))
		assert(select("#", ...) == 0, ("%s.new only accepts one argument (a dictionary)."):format(Brick.compose.name))

		local self = setmetatable({}, Brick)

		for _, init in ipairs(self.compose.initializers) do
			local value = init(self, options)
			self = value ~= nil and value or self
		end

		return self
	end

	-- Utility functions
	for name in pairs(BrickCompose) do
		Brick[name] = function(self, value)
			return self:compose({
				[name] = value
			})
		end
	end

	return Brick
end

return {
	Brick = MakeBrick({});

	deepCopy = deepCopy;
	assign = assign;
	arrayConcat = arrayConcat;
	tableType = tableType;
	merge = merge;
	isBrick = isBrick;
}
