local Brick = require(script.Parent.Bricks).Brick

local Animal = Brick({
	props = {
		foo = true;
	};
	init = function(self, options)
		self:Test()
	end;
	methods = function(Animal)
		local function something(self, x)
			print(x * self.foo)
		end

		function Animal:Test()
			self.foo = 9
			something(self, 5)
		end
	end
})

local Test = Animal:props({
	bar = false;
})

local Test2 = Animal:compose({
	props = {
		bar = false;
	}
})

print(Test.new().bar)
print(Test2.new().bar)
