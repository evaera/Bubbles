-- luacheck: ignore

stds.roblox = {
  read_globals = {
    -- global variables
    "game", "script",
  
    -- global functions
    "delay", "getfenv", "setfenv", "settings", "spawn", "tick", "time",
    "typeof", "unpack", "UserSettings", "wait", "warn", "version",
  
    -- types
    "Axes", "BrickColor", "CFrame", "Color3", "ColorSequence", "ColorSequenceKeypoint",
    "Enum", "Faces", "Instance", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
    "PhysicalProperties", "Random", "Ray", "Rect", "Region3", "Region3int16", "TweenInfo",
    "UDim", "UDim2", "Vector2", "Vector3", "Vector3int16",
  
    -- math library
    "math.clamp", "math.noise", "math.sign",
  
    -- debug library
    "debug.profilebegin", "debug.profileend"
  }
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

-- ignore = {"self"}

max_line_length = false
max_comment_line_length = 80

std = "lua51+roblox"

files["**/*.spec.lua"] = {
	std = "+testez",
}