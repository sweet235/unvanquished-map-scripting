# Unvanquished Map Scripting Manual

This document describes a Lua interface to script Unvanquished maps. It is work in progress.

## Overview

Map scripting is implemented as an event driven Lua system.
This means that we can define a function in Lua, and register this function to be called by the game when something happens to an entity we care about.

You can find the current version of the library at <https://github.com/sweet235/Unvanquished/tree/lua-map-scripting>.

## Quick Start

Let us look at the map `ptcs8_13` as an example.
Load it with cheats enabled, using the command `/devmap ptcs8`.
In the human base, there is a button.
The command `/setviewpos -2279 -2 46 180 11` will take you to this button.
We will change what happens when a player pushes this button.

First, we need a way to identify our button.
The button is an "entity".
The game has several ways to give names to entities.
Entering the command `cg_drawEntityInfo on` will make the game show some information about the entity we are currently looking at.
Looking at this entity, I see that it has the _entity number_ 116.
If you see a different number, use the number you see.
The game does not guarantee that every entity has the same number in every situation.
We will see how to deal with this in later sections.

Create a Lua file `game/quickstart.lua`:

```lua
Entities.handlers[116] = function (event)
    print("Something happened to the button, the event is: " .. event)
end
```

Load it with `/lua -f quickstart.lua`.
Then push the button.
Observe the following output in the console:

```
Something happened to the button, the event is: default
```

`Entities.handlers` is a Lua table.
`Entities` is the name of the library.
There are other libraries like `math` or `Cmd`.
By convention, Unvanquished library names start with a capital letter.
You do not really need to worry about libraries, you can think of `Entities.handlers` as a single name.

The table `Entities.handlers` is initially empty.
If we put something in this table, it must be a function (the _event handler function_).
The index into this table (in this case 116) must be an integer.
Our function is called with different values of its argument `event`, depending on what is happening to our entity.
The argument `event` is always a string.
In the case of our button being pushed, its value is `"default"`.
There are other possible events (like `"enable"` or `"disable"`), which are explained in later sections.

For now, let us make sure that our function only handles the case of our button being pushed:

```lua
Entities.handlers[116] = function (event)
    if event == "default" then
        print("The button has been pushed")
    end
end
```

Notice that this button has the effect of opening and closing two doors in the human base.
This behavior is built into the map itself.
The doors are map entities as well.
We can disable such activations of such target entities by our button:

```lua
Entities.handlers[116] = function (event)
    if event == "default" then
        print("The button has been pushed")
    end
    return true
end
```

Now our button does nothing but printing a line in the console.

Until now, our function returned `nil`.
If we make it return `true` instead, this will disable the activation of target entities.
Any value but `nil` and `false` will disable it.

Finally, let us make the button slap the player pushing it:

```lua
Entities.handlers[116] = function (event, activator)
    if event == "default" then
        print("The button has been pushed")
        Cmd.exec("slap " .. tostring(activator))
    end
    return true
end
```

We made our function look at its second argument, which we call `activator`.
This argument is always an integer: the entity number or client number of the activator.
(In some rare cases, the argument might be `nil`.)
Our button can only be pushed by players, so we can be sure `activator` is a client number.
Thus we can use it to construct a slap command.
The function `Cmd.exec` executes a command given as a string.

## Entity numbers and entity IDs

The game does not guarantee that each entity always has the same entity number.
In the previous example, the button might have an entity number different from 116.
This is, and has been, a considerable source of frustration when writing configuration files.
Consider the following script:

```lua
Entities.handlers[116] = function (e) print("event: " .. e) end
```

We can never be sure that the number 116 will not refer to a different entity, like a door.

It has been decided that the game will never provide persistent entity numbers.
Instead, entity IDs were introduced.
Each map entity receives a unique string to identify it.
The ID will not change when different layouts are loaded or when small changes are made to the map.
We can think of this ID as the entitiy's persistent name.

To find out an entity's ID, we can use the console command `entityShow`:

```
]/entityShow 116 
⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼ 
#116:            MOVER 
⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼⎼ 
Classname: func_button 
ID: func_button_1
...
```

This tells us that the button's ID is `func_button_1`.
There is a Lua function `Entities.idToNum`.
It converts entity IDs to entity numbers.
In our example, we can use the expression `Entities.idToNum("func_button_1")`.
The result will be the number 116.
If there is no entity with the given ID, the function returns `nil`.

Thus, a more robust version of our script would be:

```lua
local entityNum = Entities.idToNum("func_button_1")
if entityNum then
    Entities.handlers[entityNum] = function (e) print("event: " .. e) end
end
```

This is robust, but a little too verbose.
Because this use case is so common, the standard prelude file `game/prelude_0.1.lua` allows for a shorter formulation:

```lua
dofile("prelude_0.1.lua")

Entities.handlers["func_button_1"] = function (e) print("event: " .. e) end
```

The prelude uses Lua metatable magic to convert `"func_button_1"` to `116`.
No string is actually used as key in the table.

This is the preferred way to assign handler functions to entities.

## The library Entities

### Entities.handlers

A table indexed by integers.
Each value must be a function of two arguments:

```lua
Entities.handlers[42] = function (event, activator) end
```

The function will be called when something happens to the entity with the corresponding number.

Its argument `event` will be one of:
- `"default"` - the most usual thing to happen to an entity
- `"damage"` - a buildable or a `func_destructable` entity is damaged
- `"custom"`
- `"free"` - the entity is removed from the game
- `"call"`
- `"act"`
- `"use"`
- `"die"` - a building dies
- `"reach"`
- `"reset"`
- `"touch"`
- `"enable"`
- `"disable"`

Its argument `activator` is the client or entity number of whatever or whoever caused this event.

If the result of the function is neither `nil` nor `false`, no target entities specified by the map are fired.

### Entities.spawnHandler

Optional function.

`Entities.spawnHandler` does not exist intially. Scripts may set it to a function:

```lua
Entities.spawnHandler = function (num) end
```

If it exists, this function is called whenever an entity is created.
Currently, this is restricted to buildings.
The argument `num` is the entity number of the newly created entity.

A common use case for this function is to register an event handler for newly created buildings:

```lua
function egghandler (event)
    if event == "die" then
        print("an egg has died")
    end
end

Entities.spawnHandler = function (num)
    if Entities.classname(num) == "team_alien_spawn" then
        Entities.handlers[num] = egghandler
    end
end
```

### Entities.numToId

Function of one argument. Converts an entity number to an entity ID, or `nil` if that fails.

### Entities.idToNum

Function of one argument. Converts an entity ID to an entity number, or `nil` if that fails.

### Entities.isNum

Function of one argument: an number. Return `true` if there is an entity with that number and `false` otherwise.

This function is useful because not all entities have IDs.
For entities that do have an ID, `Entities.numToId` provides the same information as this function.

### Selector functions

All the following functions accept one argument which must be a number.
They return some information about the entity, or `nil` if no such entity exists.

#### Entities.classname

Return a string: the classname of an entity.

#### Entities.origin

Return three numbers: the coordinates of the entity's position.

#### Entities.enabled

Return `true` if the entity is enabled, and `false` otherwise.

#### Entities.team

Return `"aliens"`, `"humans"` or `nil`.

#### Entities.team

Return a number: the entities health, or `nil` for entities that do not have health.

## The library Clients

### Clients.isNum

Function of one argument: a number. Return `true` if the number is a client number, `false` otherwise.

### Clients.team

Function of one argument: a number. Return `"aliens"`, `"humans"` or `nil`.

### Clients.items

Function of one argument: a number. Return the low level flags representing upgrades (like armours and grenades) or `nil`. See the file `game/prelude_0.1.lua` for examples.

_Warning:_ this function might be changed or removed in future versions. It exposes too many implementation details.

### Clients.weapon

Function of one argument: a number. Return the low level number representing the weapon or `nil`. See the file `game/prelude_0.1.lua` for examples.

_Warning:_ this function might be changed or removed in future versions. It exposes too many implementation details.

### Clients.blasterActive

Function of one argument: a number. For a human player, return `true` or `false`. For other players, return `nil`.

### Clients.ammo

Function of one argument: a number. Return two numbers, ammo and clips:

```lua
local ammo, clips = Clients.ammo(7)
```

### Clients.health

Function of one argument: a number. If there is a client with that number in one of the teams, return this client's health. Return `nil` otherwise.

## Complete example: buildings as win conditions

This example adds a win condition to map `plat23`.
We define the "very center" of the map as the area we are looking at from the intermission position.
To be prcise, we are using the cubiod with the corners (-300, 1679, 0) and (300, 2165, 130) and all sides parallel to the x, y, z axes.

The first team to build 8 buildings at the very center wins.

```lua
buildingCounters = {aliens = 0, humans = 0}
otherTeam = {aliens = "humans", humans = "aliens"}

function say (fmt, ...)
    local msg = string.format(fmt, ...)
    print(msg)
    Cmd.exec('chat ' .. msg)
    Cmd.exec('cp ' .. msg)
end

function checkWinner ()
    for team, numBuildings in pairs(buildingCounters) do
        if numBuildings >= 8 then
            Cmd.exec(string.format("admitdefeat %s", otherTeam[team]))
        end
    end
end

function Entities.spawnHandler (num)
    local x, y, z = Entities.origin(num)
    local atCenter =
        x > -300 and x < 300 and
        y > 1679 and y < 2165 and
        z > 0 and z < 130
    if not atCenter then return end
    local team = Entities.team(num)
    buildingCounters[team] = buildingCounters[team] + 1
    Entities.handlers[num] = function (event)
        if event == "free" then
            buildingCounters[team] = buildingCounters[team] - 1
        end
    end
    say("^DHumans ^*%d : %d ^IAliens^*", buildingCounters.humans, buildingCounters.aliens)
    checkWinner()
end
```

A remark about the design of the library:
notice the following function in the code given above:

```lua
    Entities.handlers[num] = function (event)
        if event == "free" then
            buildingCounters[team] = buildingCounters[team] - 1
        end
    end
```

The body of the function uses the name `team`.
That name is a free identifier.
As the name is defined in the surrounding environment, this function is a lexical closure.
Each function created this way will remember the value of `team` during its creation.
Lexical closures are one reason why a simple scripting system like this one can achieve considerable expressiveness without complex object oriented designs.

## Complete example: grangermaze

This example shows how to control all doors on map `grangermaze`.
Every 60 seconds, all doors are locked for 15 seconds.

```lua
dofile("prelude_0.1.lua")

local counter

-- disable all ctrl_relays
counter = 0
while true do
    local num = Entities.idToNum(string.format("ctrl_relay_%d", counter))
    if not num then break end
    Entities.handlers[num] = function () return true end
    counter = counter + 1
end

-- gather the numbers of all func_doors
func_door_nums = {}
counter = 0
while true do
    local num = Entities.idToNum(string.format("func_door_%d", counter))
    if not num then break end
    table.insert(func_door_nums, num)
    counter = counter + 1
end

function lock_or_unlock_all_doors()
    for k, v in ipairs(func_door_nums) do
        Cmd.exec(string.format("entityLock %d", v))
    end
end

function delay(n)
    Cmd.exec(string.format("delay %ds main", n))
end

local locked = false
function main()
    lock_or_unlock_all_doors()
    locked = not locked
    if locked then
        Cmd.exec("cp The doors are locked!")
        delay(15)
    else
        Cmd.exec("cp The doors are open!")
        delay(45)
    end
end

Cmd.exec('alias main "lua \"main()\""')
delay(45)
```

## Complete example: operation-dretch

This example makes map `operation-dretch` more difficult.
The changes are:

- A player must not have any equipment in order to reach the two critical buttons.
- As humans build further away from their starting position, the number of alien bots is increased.
- If humans destroy one of the eggs on the far side of the map, the firebomb is disabled.

```lua
-- forbid some equipment for players in order for them to be able to push the buttons
function hasForbiddenStuff (clientNum)
    local inv = Clients.inventory(clientNum)
    return inv.larmour or inv.marmour or inv.bsuit or inv.radar or inv.jetpack or inv.grenade or inv.firebomb
end

-- handler function for the sensor_player entities
-- only do something when the player has nothing forbidden
-- we must not spam clients with private messages
local lastActivated = {}
function stuffHandler (event, activator)
    if event ~= "default" then return end
    local result = nil
    if hasForbiddenStuff(activator) then
        local curTime = tonumber(os.time(os.date("!*t")))
        lastActivated[activator] = lastActivated[activator] or 0
        if curTime > lastActivated[activator] + 2 then
            Clients.centerPrint(activator, "You must not have any equipment to reach this button!")
            lastActivated[activator] = curTime
        end
        result = true
    end
    return result
end

Entities.handlers["sensor_player_0"] = stuffHandler
Entities.handlers["sensor_player_1"] = stuffHandler

-- as humans build further and further away from their start position,
-- add more and more bots
local advanceThresholds = {1350, 2100, 2900, 999999}
local advanceIndex = 1
function Entities.spawnHandler (num)
    if Entities.team(num) ~= "humans" then return end
    local x, y, z = Entities.origin(num)
    if x > advanceThresholds[advanceIndex] then
        advanceIndex = advanceIndex + 1
        Cmd.exec("cp ^7Humans advanced! ^aAdd more aliens!")
        Cmd.exec("chat ^3[!] ^7Humans advanced! ^aAdd more aliens!")
        for i = 1, 2 do Cmd.exec("bot add * a 5") end
    end
end

-- disable the firebomb when the eggs at the far end of the map are destroyed
local farEggDied = false
function farEggHandler(event)
    if event == "die" and not farEggDied then
        Cmd.exec("cp ^7Last eggs reached! ^iDisable the firebomb!")
        Cmd.exec("chat ^3[!] ^7Last eggs reached! ^iDisable the firebomb!")
        Cvar.set("g_disabledEquipment", "firebomb")
        farEggDied = true
    end
end

function registerEggHandlers()
    for num = 64, 8191 do
        if Entities.classname(num) == "team_alien_spawn" then
            local x, y, z = Entities.origin(num)
            if x > 4500 then
                Entities.handlers[num] = farEggHandler
            end
        end
    end
end

-- register the handlers when we are sure the eggs are already there
Cmd.exec('alias registerEggHandlers "lua registerEggHandlers()"')
Cmd.exec("delay 2s registerEggHandlers")

-- add 10 bots at the beginning
for i = 1, 10 do
    Cmd.exec("bot add * a 5")
end
```

## Complete example: rush-station

This example for map `rush-station` uses the function `Clients.centerPrint` to inform the human players about the remaining health of the four forcefield controller computers they are supposed to destroy.

```lua
function centerPrintAllHumans(fmt, ...)
   local msg = string.format(fmt, ...)
   for num = 0, 63 do
      if Clients.team(num) == "humans" then
         Clients.centerPrint(num, msg)
      end
   end
end

function registerComputerHandler (id)
   local num = Entities.idToNum(id)
   local nextTriggerHealth = 750
   Entities.handlers[num] = function (event, activator)
      if event ~= "damage" then return end
      if Entities.health(num) <= nextTriggerHealth then
         centerPrintAllHumans("The computer's health is %d!", Entities.health(num))
         nextTriggerHealth = nextTriggerHealth - 250
      end
   end
end

for i = 0, 3 do
   registerComputerHandler(string.format("func_destructable_%d", i))
end
```

This example shows how each event handler, being a lexical closure, can keep its own state variable `nextTriggerHealth`.
Lexical closures do not only remember the value of such a variable at their creation time.
They allow to use these variables as mutable local state.

## Design considerations

Designing a scripting system for game servers comes with several challenges that need be balanced against each other.
Among these are:

- The server has to be fast and reliable. There are timing constraints.
- The scripting system should be flexible enough to allow for a wide variety of unusual configurations.
- The system should expose as few implementation details as possible to the script programmer.
  This is required to maintain modularity and backward compatiblity.
- The system should be tested in realistic scenarios during its development.
- The system should use a minimal software interface with the C++ code.

I believe the simple event driven approach described here can achieve a reasonable amount of balance between these points.

### Drawbacks

The game might remove any entity at any server frame.
A Lua script in production will have to handle this case correctly.
If a script keeps a reference to an entity it is own data structures over several server frames, the corresponding entities might have vanished.
For any such entity, the script should handle the `"free"` event of its event handler accordingly.

In some cases, script programmers might prefer a system that keeps track of this automatically.
This can be achieved by implementing an entity reference type in Lua.
It is planned to provide such a type in the prelude.

A minimalistic example is given here:

```lua
local generation = 0
local generations = {}

Entity = {}

local function checkGeneration(self)
    local num = self.private.num
    if not generations[num] or self.generation ~= generations[num].generation then
        error(string.format("%s has vanished", tostring(self)))
    end
end

function Entity:__tostring()
    return string.format("Entity(%d)", self.private.num)
end

function Entity:__index (key)
    checkGeneration(self)
    return Entity[key]
end

function Entity:id ()
    return Entities.numToId(self.private.num)
end

function Entity:num ()
    return self.private.num
end

function Entity:classname ()
    return Entities.classname(self.private.num)
end

function Entity:handlers ()
    return self.private.handlers
end

function Entity:fire ()
    Cmd.exec(string.format("entityFire %d", self.private.num))
end

local function createEntityObject (self, idOrNum)
    local num
    if type(idOrNum) == "string" then
        num = Entities.idToNum(idOrNum)
    else
        num = idOrNum
    end
    -- if an object was already created, return it
    if generations[num] then
        return generations[num].object
    end
    local self = {}
    self.private = {}
    self.private.num = num
    self.generation = generation
    self.private.handlers = {
        free = function (_)
            generations[num] = nil
        end
    }
    generations[num] = { generation = generation, object = self }
    generation = generation + 1
    setmetatable(self, Entity)
    Entities.handlers[num] = function (event, activator)
        local f = self.private.handlers[event]
        if f then return f(activator) end
    end
    return self
end

setmetatable(Entity,
             {__call = createEntityObject})

function isentity(x)
    return getmetatable(x) == Entity
end
```

This allows us to create entity objects that make sure the corresponding entity is still existing.
For instance, load map `plat23`.
The overmind is entity number 97.
We can do this:

```lua
overmind = Entity(97)
print(overmind:classname())
```

The output will be:

```
team_alien_overmind
```

If we remove the overmind, and execute `print(overmind:classname())` again, we see this output:

```
Warn: error executing Lua code: 
Warn: [string "file.lua"]:9: Entity(97) has vanished
```

At the current stage of development, it is unclear if and how useful such an object type would be to typical map scripts.
We can postpone its design for now, as its implementation does not require any interface to the C++ code.
