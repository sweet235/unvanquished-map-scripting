local EMT = {}
setmetatable(Entities.handlers, EMT)
function EMT.__newindex(self, key, value)
    local entity_num = key
    if type(key) == "string" then
        entity_num = Entities.idToNum(key)
    end
    if entity_num then
        rawset(Entities.handlers, entity_num, value)
    end
end

-- in sync with the C++ type `enum upgrade_t`
local upgrades = {
    "larmour",
    "marmour",
    "bsuit",
    "radar",
    "jetpack",
    "grenade",
    "firebomb",
    "medkit"
}

-- in sync with the C++ type `enum weapon_t`
local weapons = {
    "level0",
    "level1",
    "level2",
    "level2upg",
    "level3",
    "level3upg",
    "level4",
    "blaster",
    "rifle",
    "painsaw",
    "shotgun",
    "lgun",
    "mdriver",
    "chaingun",
    "flamer",
    "prifle",
    "lcannon",
    "rocketpod", -- unused
    "mgturret", -- unused
    "builder",
    "buiderupg",
    "ckit"
}

function Clients.inventory (num)
    if not Clients.isNum(num) then return nil end
    local result = {}
    local itemFlags = Clients.items(num)
    for exponent, name in pairs(upgrades) do
        local flag = 1 << exponent
        if itemFlags & flag ~= 0 then
            result[name] = true
        end
    end
    local weapon = Clients.weapon(num)
    if weapons[weapon] then
        result[weapons[weapon]] = true
    end
    if Clients.team(num) == "humans" then
        result["blasterActive"] = Clients.blasterActive(num)
    end
    return result
end
