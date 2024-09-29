PLUGIN.name = "Funeralis"
PLUGIN.author = "Whatever, I don't care"
PLUGIN.description = "Plays faction-specific music for players when they die."

ix.config.Add("deathMusicEnabled", true, "Turns ON/OFF the plugin", nil, {
    category = "FUNERALIS"
})

ix.config.Add("defaultDeathMusic", "music/radio1.mp3", "Default sound file if no faction-specific setting is set", nil, {
    category = "FUNERALIS"
})

local deathMusicCache = {}

local function clearDeathMusicCache()
    table.Empty(deathMusicCache)
end

local function getDeathMusicForFaction(factionID)
    local configKey = "Death Music - " .. factionID
    local musicPath = ix.config.Get(configKey, "")
    
    if musicPath == "" or not file.Exists("sound/" .. musicPath, "GAME") then
        musicPath = ix.config.Get("defaultDeathMusic")
    end

    deathMusicCache[factionID] = musicPath
    return musicPath
end

function PLUGIN:InitializedPlugins()
    for _, faction in pairs(ix.faction.indices) do
        local displayName = faction.uniqueID:gsub("^%l", string.upper)
        ix.config.Add("Death Music - " .. displayName, "", "Death Music " .. faction.uniqueID, nil, {
            category = "FUNERALIS"
        })
    end
end

if SERVER then
    util.AddNetworkString("PlayDeathMusic")
    util.AddNetworkString("StopDeathMusic")

    function PLUGIN:DoPlayerDeath(victim, attacker, dmginfo)
        if not ix.config.Get("deathMusicEnabled", true) or not IsValid(victim) or not victim:IsPlayer() then return end
    
        local character = victim:GetCharacter()
        if not character then return end

        local faction = ix.faction.indices[character:GetFaction()]
        local capitalizedFactionID = faction.uniqueID:gsub("^%l", string.upper)
        local deathMusic = getDeathMusicForFaction(capitalizedFactionID)

        net.Start("PlayDeathMusic")
        net.WriteString(deathMusic)
        net.Send(victim)
    end

    function PLUGIN:PlayerSpawn(player)
        net.Start("StopDeathMusic")
        net.Send(player)
    end

    -- Hook into config changes
    hook.Add("OnConfigSet", "FuneralisConfigUpdate", function(key, value)
        if key:find("Death Music -") or key == "defaultDeathMusic" then
            clearDeathMusicCache()
        end
    end)

else
    local currentDeathMusic

    local function playDeathMusic(musicPath)
        if currentDeathMusic then
            currentDeathMusic:Stop()
        end
        sound.PlayFile("sound/" .. musicPath, "noplay", function(station)
            if IsValid(station) then
                currentDeathMusic = station
                station:Play()
            else
                ErrorNoHalt("Failed to play death music: ", musicPath)
            end
        end)
    end

    net.Receive("PlayDeathMusic", function()
        playDeathMusic(net.ReadString())
    end)

    net.Receive("StopDeathMusic", function()
        if currentDeathMusic then
            currentDeathMusic:Stop()
            currentDeathMusic = nil
        end
    end)
end