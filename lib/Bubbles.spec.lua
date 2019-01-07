return function()
	local Bubbles = require(script.Parent.Bubbles)
	local Bubble = Bubbles.Bubble
	local Util = Bubbles.Util

	describe("Bubble", function()
		it("Should create new objects", function()
			local blank = Bubble()
			expect(blank.new).to.be.ok()
			expect(blank.compose).to.be.ok()
			expect(blank.new()).to.be.ok()
			expect(getmetatable(blank.new())).to.equal(blank)
		end)

		it("Should compose an object and a descriptor", function()
			local array = {1, 2}
			local dictionary = {foo = "bar"}

			local first = Bubble("none", {
				name = "first";
				props = {
					firstProperty = true;
					shallowDictionary = {
						firstProperty = "hello";
					}
				};
				deepProps = {
					array = {1, 2, 3};
					number = 1;
					differentType = array;
					dictionary = {
						firstProperty = "hello";
					}
				};
				deepStatics = {
					array = {7, 8};
				};
				init = function(self, options)
					print(options.firstInitValue)
					self.firstInitValue = options.firstInitValue
				end;
				methods = function(first)
					function first:firstMethod(value)
						self.firstMethodProperty = value
					end
				end;
			})
			local second = first:compose("second", {
				props = {
					secondProperty = 5;
					shallowDictionary = {
						secondProperty = "goodbye";
					}
				};
				deepProps = {
					array = {4, 5, 6};
					number = 7;
					differentType = dictionary;
					dictionary = {
						secondProperty = "goodbye";
					}
				};
				deepStatics = {
					array = {9, 10};
				};
				init = function(self, options)
					self.secondInitValue = options.secondInitValue
				end;
				methods = function(second)
					function second:secondMethod(value)
						self.secondMethodProperty = value
					end
				end;
			})

			for i = 7, 10 do
				expect(second.array[i-6]).to.equal(i)
			end

			local instance = second.new({
				firstInitValue = 1;
				secondInitValue = 2;
			})

			instance:firstMethod(3)
			instance:secondMethod(4)

			expect(tostring(instance)).to.equal("second")
			expect(instance.firstInitValue).to.equal(1)
			expect(instance.secondInitValue).to.equal(2)
			expect(instance.firstMethodProperty).to.equal(3)
			expect(instance.secondMethodProperty).to.equal(4)
			expect(instance.secondProperty).to.equal(5)
			expect(#instance.array).to.equal(6)

			for i = 1, 6 do
				expect(instance.array[i]).to.equal(i)
			end

			expect(instance.number).to.equal(7)
			expect(instance.differentType.foo).to.equal("bar")
			expect(instance.differentType[1]).to.never.be.ok()
			expect(instance.dictionary.firstProperty).to.equal("hello")
			expect(instance.dictionary.secondProperty).to.equal("goodbye")
			expect(instance.shallowDictionary.firstProperty).to.never.be.ok()
			expect(instance.shallowDictionary.secondProperty).to.equal("goodbye")
			expect(second.compose.deepProps.dictionary).to.never.equal(first.compose.deepProps.dictionary)
		end)

		it("should allow nilling default props", function()
			local TestBubble = Bubble({
				props = {
					Health = 100
				}
			})

			local testBubble = TestBubble.new()

			expect(testBubble.Health).to.equal(100)

			testBubble.Health = nil

			expect(testBubble.Health).to.never.be.ok()
		end)

		it("should not duplicate initializers", function()
			local callCount = 0

			local function init()
				callCount = callCount + 1
			end

			local TestBubble = Bubble:init(init)
			local TestBubble2 = Bubble:init(init)

			local Composed = TestBubble:compose(TestBubble2)

			Composed.new()

			expect(callCount).to.equal(1)
		end)

		it("should allow static methods", function()
			local callCount = 0
			local bubble = Bubble:statics({
				method = function(param)
					callCount = callCount + 1
					expect(param).to.equal(4)
				end
			}):methods({
				bad = function() end;
			})

			expect(bubble.bad).to.never.be.ok()

			bubble.method(4)

			expect(callCount).to.equal(1)
		end)
	end)

	describe("Util.isBubble", function()
		it("should return true if passed a bubble", function()
			expect(Util.isBubble(Bubble)).to.equal(true)
			expect(Util.isBubble(Bubble.new())).to.equal(true)
		end)
	end)
end
