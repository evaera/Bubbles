local Bubble = require(script.Parent.Bubbles).Bubble

local Character = Bubble({
	props = {
		Health = 100
	};
	init = function(self, options)
		print("A new", tostring(self), "has joined!")

		self.Health = options.Health or self.Health
	end;
	methods = {
		Hurt = function(self, amount)
			self.Health = self.Health - amount
		end;
	}
})

local Warrior = Character:compose({
	name = "Warrior";
	props = {
		Stamina = 50
	};
	deepProps = {
		Skills = {"Smithing"}
	};
	methods = function(Warrior)
		function Warrior:Fight(character)
			character:Hurt(10)
			self.Stamina = self.Stamina - 20
		end
	end
})

local Priest = Bubble:compose(Warrior)
	:name("Priest")
	:props({
		Mana = 50
	})
	:deepProps({
		Skills = {"Tailoring"}
	})
	:methods(function(Priest)
		local function heal(self)

		end

		function Priest:Heal(character)
			character:Hurt(-10)
			self.Mana = self.Mana - 15

			heal(self)
		end
	end)

local Paladin = Character:compose(Warrior, Priest)
	:name("Paladin")
	:init(function(self)
		self:Heal(self)
	end)

local Uther = Paladin.new({
	Health = 200
})

local Garrosh = Warrior.new({
	Health = 10
})

Uther:Fight(Garrosh)

print("Garrosh: ", Garrosh.Health)

print(table.concat(Uther.Skills, ", "))

--[[
	Output:
		A new Paladin has joined!
	A new Warrior has joined!
	Garrosh:  0
	Smithing, Tailoring
]]
