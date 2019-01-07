# Bubbles

**Bubbles** are *composable* objects presented as an alternative to classical-style inheritance. Instead of modeling our objects with parent-child relationships as is conventional in Lua-style OOP, we represent each of the traits of our object as individual, simple objects that perform one purpose. We can then *compose* many of these simple objects into one larger object that encompasses all of the traits of  the constituent objects.

You can think of Bubbles as conventional Lua "classes", but more flexible, without limits, and fully featured. At first glance, Bubbles are somewhat similar to conventional classes:

```lua
local Bubbles = require(path.to.Bubbles)
local Bubble = Bubbles.Bubble

local bubble = Bubble.new()
print(getmetatable(bubble) == Bubble) --> true
```

However, Bubbles carry around metadata about the object instance they will produce when instantiated (with `.new()`) inside of a `compose` field. This is known as a Bubble *descriptor*.

```lua
local descriptor = Bubble.compose
```

Conventional classes model objects with child->parent->parent->parent->... relationships. In contrast, when you compose two or more Bubbles together, you *merge* methods, properties, static methods, and initializers (constructors) from multiple objects, making a brand new object. Fields from later-composed Bubbles overwrite fields from earlier-composed Bubbles.

The merge process is facilitated by this metadata attached to Bubbles, which are essentially instructions on how to create that type of object.

There are 8 kinds of metadata:

- `name`: string
  - A human-friendly name for this object, useful for debugging. If you call `tostring` on this object, you'll get this value.
- `initializers`: array (table)
  - Initializers are similar to constructors, except *every* initializer from every Bubble you compose will run upon instantiation. 
  - The order of execution is the order of composition.
  - Initializers only accept one argument: a dictionary (table) with descriptively-named properties. This way, all initializers can live in harmony with each other.
  - Initializers are always de-duplicated upon composition.
- `methods`: dictionary (table)
  - Methods that will be available on Bubble instances belong in the `methods` table.
  - Methods accept `self` as their first argument, followed by any number of arguments, just as in conventional classes.
  - The methods table becomes the __index metamethod of the Bubble.
- `props`: dictionary (table)
  - Props, or properties, are nothing more than default values for properties of the instantiated value.
  - Props are copied by reference into the new object upon instantiation.
- `deepProps`: dictionary (table)
  - Deep props are similar to props, except that upon composition, they are deeply merged with identically-named props from other Bubbles.
  - Tables are *deep-copied*.
  - Dictionaries are *deeply merged*.
  - Arrays are **concatenated**.
- `statics`: dictionary (table)
  - Both static methods and properties can be contained within `statics`.
  - They are available on the non-instance version of the Bubble.
- `deepStatics`: dictionary (table)
  - Deep statics are semantically identical to deep props, except they are accessed on the non-instance version of the Bubble.
- `composers`: array (table)
  - Composers are special hooks that run at time of *composition* and have the ability to influence the resulting object.
  - Composers are always de-duplicated upon composition.

## Composing Bubbles

Composing Bubbles can be accomplished a few different ways. Firstly, simply calling the static Bubble as a function will compose it with any passed values:

```lua
local Example = Bubble({
  name = "Example";
  methods = {
    foo = function(self)
      print(self) --> Example
    end
  };
})
```

In the code snippet above, we are composing the base `Bubble` object with a *descriptor*. This results in a new Bubble, merging the descriptor's traits with the base Bubble.

To clarify, all Bubbles must be composed from the base `Bubble` object. The `Bubble` object is a Bubble with all blank metadata, so composing with it just creates a fresh Bubble merged with your provided metadata.

Calling the Bubble as a function is identical to calling the `:compose` method explicitly:

```lua
local SecondExample = Example:compose({
  name = "SecondExample";
})
```

### Chainable Static Helpers

Several static helper methods are also provided on the base `Bubble` object, which  means that they are available to all Bubbles. These helper methods allow you to compose Bubbles, changing one property at a time:

```lua
local ThirdExample = SecondExample:name("ThirdExample")
```

Since each of these methods returns a new Bubble, that means that they are chainable:

```lua
local FourthExample = ThirdExample:name("FourthExample"):methods({
  bar = function(self, x, y)
    return x + y
  end;
}):init(function()
  print("A new", tostring(self), "was just instantiated!")
end):deepProps({
  List = {"One"}
})
```

In the code sample above, `init` is a helper function that is short for setting `initializers` to an empty array and then placing the provided function inside of it.

### Shorthands

Speaking of shortcuts, you can compose Bubbles with a string value as a shorthand for setting the `name`:

```lua
local FifthExample = FourthExample:compose("FifthExample")
-- or, equivalent:
local FifthExample = FourthExample("FifthExample")
```

And since methods in Lua are usually nicer to assign with the method syntax shortcut, you can pass a function to `methods` which offers this ability for quality of life:

```lua
local SixthExample = FifthExample:methods(function(FifthExample)
  local function privateMethod(self, x)
    return 2 + x
  end

  function FifthExample:baz(x)
    return privateMethod(self, x)
  end
end)
```

In the above sample, we can see that when using the functional method shortcut, a blank table is passed to the function as its first and only argument. Any methods defined on this table will become the methods dictionary in the Bubble descriptor.

**Important note:** This function is immediately invoked, so you can't store instance-specific private data inside of this closure. However, it can be convenient for helper functions or private methods. Prefixing method names with an underscore to indicate private methods is also an acceptable pattern, and is arguably more robust.

### Composing Multiple Bubbles

Up until now, we've only composed one Bubble at a time. But when using Bubbles in the wild, the real power comes from the ability to compose many "primitive" objects into one.

```lua
local Foo = Bubble({
  methods = function(Foo)
    function Foo:bar()
      -- do somethng
    end
  end
})

local Bar = Bubble({
  methods = function(Bar)
    function Bar:foo()
      -- do somethng
    end
  end
})

local Baz = Bubble({
  methods = function(Baz)
    function Baz:zoinks()
      -- do somethng
    end
  end
})

local FooBarBaz = Foo:compose(Bar, Baz)
-- or, equivalent:
local FooBarBaz = Bubble:compose(Foo, Bar, Baz)
-- or, equivalent:
local FoobarBaz = Bubble(Foo, Bar, Baz)
```

## Collisions

By default, methods from later-composed Bubbles override methods from earlier-composed ones. But Bubble provides a `Collision` utility Bubble which lets you override this behavior.

### Forbidding Overriding
By composing with a Bubble created with `Collsion.forbid`, you can explicitly define method names for which you want to forbid overriding. If you then compose with another Bubble that has methods that share those names, an error will be thrown.

```lua
local Bubbles = require(path.to.Bubbles)
local Bubble = Bubbles.Bubble
local Collision = Bubbles.Collision

local Example = Collision.forbidCollision({"foo"}):methods({
  foo = function() end;
})

-- Attempting to override `foo` will now cause an error:
Example:methods({
  foo = function() end; -- errors
})
```

### Deferring Methods
If you mark specific method names as *deferred*, identically-named methods will be collected and wrapped into a single method.

This is most useful for generalized cleanup methods, such as `Destroy`!

```lua
local Example = Collision.deferCollision({"Destroy"}):methods({
  Destroy = function()
    -- Destroy things...
    return 1
  end
})

local Example2 = Example:compose({
  methods = {
    Destroy = function()
      -- destroy more things...
      return 2
    end
  }
})

local example2 = Example2.new()

print(example2:Destroy()) --> 2 1
```

When you defer multiple methods into one, their return values are captured and returned as a tuple from the method, in **inverse** order of composition. Only the first return value will be captured from each function.

## Required fields

Often, when using Bubbles, you may be creating a Bubble that is expecting to be composed with another. In situations like this, you may rely on fields from `self` that aren't present in your individual Bubble, but will be once composed.

For ease of debuggability, a `Required` utility Bubble is provided, which allows you to mark certain fields as required before the Bubble can be instantiated without error.

The `Required.require` function expects a *descriptor-like* object, structured like a Bubble descriptor, except with `true` as values when a field is required.

```lua
local Bubbles = require(path.to.Bubbles)
local Bubble = Bubbles.Bubble
local Required = Bubbles.Required

local FooRequired = Required.require({
  methods = {
    foo = true; -- Require the "foo" method before this Bubble can be instantiated.
  }
}):methods({
  bar = function()
    return self:foo() -- We rely on the `foo` method here.
  end
})

-- Attempting to instantiate with `FooRequired.new()` right now will raise an error.

-- Elsewhere...

local HasFoo = FooRequired:compose({
  methods = {
    foo = function()
      return 5
    end
  }
})

local hasFoo = HasFoo.new() -- This now works without error.
```

## Composers

Composers are special hook functions which can influence composition. The Collision and Required utility Bubbles are implemented using composers. Composers are a very powerful and dangerous feature, so if you should only use them when necessary.

Composers are stored just like the other metadata types. Each composer stored inside of a Bubble is ran in sequence (in order of composition) as the last step of a `:compose` call (also including helper methods, as they use `:compose` internally).

Composers receive two arguments: the newly-composed Bubble, and an array of *composables* which were used to create that Bubble.

**Important note**: *composables* may be either an entire Bubble or just a descriptor. You can check with `compose = bubble.compose or bubble`.

It is recommended that you mutate the first bubble argument. However, if needed, you can return an entirely new value, which will replace the bubble as the result of the composition.

```lua
local composed = Bubble():composers({
  function(bubble, composables)
    return false
  end
}):compose(Bubble)

print(composed == false) --> true
```

Take a look at the source code for more details on composers by checking out the Collision and Required Bubbles.

## Tips

- As Bubbles are directly merged together, it is very important that you use descriptive field names. You should be doing this anyway, but it's doubly important when using Bubbles.
  - For example, instead of naming a method `get`, you should be specific and include *what* you're getting in the method name, e.g. `getCharacter`.
- All `Bubble.compose` tables share the same metatable. You can use this to detect  if an object is a Bubble. As a convenience, an `isBubble` function is included out of the box inside of the `Util` namespace, exported from the module.
- There is no out-of-the-box method to check if a Bubble has been composed with another Bubble. This is by design: it is preferred that you use duck typing when checking if an object is valid  rather than relying on inheriting from one specific  object. This makes your code more robust, because it allows you flexibility of switching out different implementations of objects that serve the same purpose. Duck typing is powerful and largely failsafe when using descriptive field names.