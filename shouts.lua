-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ FFXIV World Tour Shout Script with Congestion Retry ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

-- World lists
local chaosWorlds = { "Cerberus", "Louisoix", "Moogle", "Omega", "Phantom", "Ragnarok", "Sagittarius", "Spriggan" }
local lightWorlds = { "Alpha", "Lich", "Odin", "Phoenix", "Raiden", "Shiva", "Twintania", "Zodiark" }
local aetherWorlds = { "Adamantoise", "Cactuar", "Faerie", "Gilgamesh", "Jenova", "Midgardsormr", "Sargatanas", "Siren" }
local crystalWorlds = { "Balmung", "Brynhildr", "Coeurl", "Diabolos", "Goblin", "Malboro", "Mateus", "Zalera" }
local dynamisWorlds = { "Cuchulainn", "Golem", "Halicarnassus", "Kraken", "Maduin", "Marilith", "Rafflesia", "Seraph" }
local primalWorlds = { "Behemoth", "Excalibur", "Exodus", "Famfrit", "Hyperion", "Lamia", "Leviathan", "Ultros" }

-- Major cities
local cityAetherytes = {
    { id = 8, zone = 129, name = "Limsa Lominsa" },
    { id = 9, zone = 130, name = "Ul'dah" },
    { id = 2, zone = 132, name = "New Gridania" },
}

-- Characters
local EU_CHARACTER = "Deb Morgan@Louisoix"
local NA_CHARACTER = "Dex Morgan@Golem"
local TEST_MODE = true

-- Congested worlds tracker
local congestedWorlds = {}

-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ WORLD DETECTION + HELPERS ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

local function GetCurrentWorld()
    local tries = 0
    while (Svc.ClientState.LocalPlayer == nil or Svc.ClientState.LocalPlayer.HomeWorld == nil) and tries < 100 do
        Svc.Framework.RunNextFrame()
        tries = tries + 1
    end
    
    if Svc.ClientState.LocalPlayer and Svc.ClientState.LocalPlayer.HomeWorld then
        local hw = Svc.ClientState.LocalPlayer.HomeWorld
        if hw.GameData and hw.GameData.Name then
            return tostring(hw.GameData.Name)
        elseif hw.Value and hw.Value.Name then
            return tostring(hw.Value.Name)
        elseif hw.Name then
            return tostring(hw.Name)
        end
    end
    return nil
end

-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ WAIT / BUSY / SHOUT ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

local function WaitForTransfer(maxWait, world, datacenterName)
    maxWait = maxWait or 180
    local waited = 0
    
    -- Wait for transfer start
    while not (IPC.Lifestream and IPC.Lifestream.IsBusy and IPC.Lifestream.IsBusy()) and waited < maxWait do
        yield("/wait 1")
        waited = waited + 1
    end
    
    if waited >= maxWait then
        return false
    end
    
    waited = 0
    while (IPC.Lifestream and IPC.Lifestream.IsBusy and IPC.Lifestream.IsBusy()) do
        -- Safe check for world unavailable
        if IPC.Lifestream and IPC.Lifestream.IsWorldUnavailable and IPC.Lifestream.IsWorldUnavailable() then
            yield("/echo [WARN] " .. world .. " is congested, adding to retry list")
            congestedWorlds[datacenterName] = congestedWorlds[datacenterName] or {}
            table.insert(congestedWorlds[datacenterName], world)
            return false
        end
        
        -- Safe check for queue
        if IPC.Lifestream and IPC.Lifestream.IsQueued and IPC.Lifestream.IsQueued() then
            yield("/echo [INFO] In queue for " .. world .. "...")
        end
        
        yield("/wait 5")
        waited = waited + 5
        if waited >= maxWait and not (IPC.Lifestream and IPC.Lifestream.IsQueued and IPC.Lifestream.IsQueued()) then
            return false
        end
    end
    
    yield("/wait 6")
    return true
end

local function WaitForCharacterLoad()
    yield("/wait 4")
end

local function SetBusyStatus()
    WaitForCharacterLoad()
    yield("/busy")
end

local function ShoutPromoMessage(characterName)
    while Svc.Condition[45] do
        yield("/wait 1")
    end
    
    local region = characterName:find("Deb") and "EU" or "NA"
    yield("/wait 2")
    
    if TEST_MODE then
        yield("/echo [TEST SHOUT] [" .. region .. "] " .. characterName .. ": [Twitch Giveaway] 300M Gil | 1M per draw | twitch.tv/stingcatknight <se.7>")
    else
        yield("/shout [Twitch Giveaway] 300M Gil | 1M per draw | twitch.tv/stingcatknight <se.7>")
    end
    
    yield("/wait 2")
end

-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ CITY VISITS ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

local function VisitAllCities(characterName)
    local currentZone = (IPC.Lifestream and IPC.Lifestream.GetRealTerritoryType and IPC.Lifestream.GetRealTerritoryType()) or 0
    local visited = {}
    
    for _, city in ipairs(cityAetherytes) do
        if currentZone == city.zone then
            yield("/echo [INFO] Already in " .. city.name .. " - shouting here first!")
            ShoutPromoMessage(characterName)
            visited[city.name] = true
            break
        end
    end
    
    for _, city in ipairs(cityAetherytes) do
        if not visited[city.name] then
            local doneZone = (IPC.Lifestream and IPC.Lifestream.GetRealTerritoryType and IPC.Lifestream.GetRealTerritoryType()) or 0
            
            if IPC.Lifestream and IPC.Lifestream.Teleport then
                IPC.Lifestream.Teleport(city.id, 0)
            end
            
            local waitTime = 0
            repeat
                yield("/wait 1")
                waitTime = waitTime + 1
            until ((IPC.Lifestream and IPC.Lifestream.GetRealTerritoryType and IPC.Lifestream.GetRealTerritoryType()) or 0) ~= doneZone or waitTime >= 30
            
            if waitTime < 30 then
                ShoutPromoMessage(characterName)
            end
        end
    end
end

-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ WORLD / DATACENTER TOURS ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

local function VisitWorldList(worlds, datacenterName, characterName)
    yield("/echo [INFO] === Starting " .. datacenterName .. " Tour ===")
    
    -- Set busy status IMMEDIATELY upon entering the datacenter
    SetBusyStatus()
    
    for _, world in ipairs(worlds) do
        -- Let Lifestream handle all world positioning automatically
        if IPC.Lifestream and IPC.Lifestream.ChangeWorld then
            IPC.Lifestream.ChangeWorld(world)
            if not WaitForTransfer(180, world, datacenterName) then
                goto continue
            end
        else
            yield("/echo [ERROR] Lifestream module not available, skipping world change")
            goto continue
        end
        
        VisitAllCities(characterName)
        
        ::continue::
    end
    
    yield("/echo [SUCCESS] " .. datacenterName .. " tour complete!")
end

local function RetryCongestedWorlds(characterName, maxRetryMinutes)
    if not congestedWorlds or next(congestedWorlds) == nil then
        return
    end
    
    yield("/echo [INFO] Retrying congested NA worlds for up to " .. maxRetryMinutes .. " minutes...")
    local start = os.time()
    
    while os.time() - start < (maxRetryMinutes * 60) do
        local newTable = {}
        
        for dc, worlds in pairs(congestedWorlds) do
            newTable[dc] = {}
            for _, world in ipairs(worlds) do
                yield("/echo [INFO] Retrying " .. dc .. " -> " .. world)
                
                if IPC.Lifestream and IPC.Lifestream.ChangeWorld then
                    IPC.Lifestream.ChangeWorld(world)
                    if WaitForTransfer(90, world, dc) then
                        SetBusyStatus()
                        VisitAllCities(characterName)
                    else
                        table.insert(newTable[dc], world)
                    end
                else
                    yield("/echo [ERROR] Lifestream module not available, skipping retry")
                    table.insert(newTable[dc], world)
                end
            end
        end
        
        congestedWorlds = newTable
        
        if next(congestedWorlds) == nil then
            yield("/echo [SUCCESS] All congested worlds cleared early!")
            break
        end
        
        yield("/wait 30")
    end
    
    congestedWorlds = {}
end

-- ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ MAIN LOOP - DYNAMIS FIRST FOR NA ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════╝

local function Main()
    yield("/echo [INFO] Starting World Tour Script")
    if TEST_MODE then
        yield("/echo [INFO] TEST MODE ACTIVE - /echo instead of /shout")
    end
    
    for cycle = 1, 3 do
        yield("/echo [INFO] === Cycle " .. cycle .. " of 3 ===")
        
        -- EU tours - Lifestream will handle all world positioning automatically
        VisitWorldList(chaosWorlds, "Chaos (EU)", EU_CHARACTER)
        VisitWorldList(lightWorlds, "Light (EU)", EU_CHARACTER)
        
        -- Return Deb Morgan to home world Louisoix after EU tour
        yield("/echo [INFO] Returning Deb Morgan to Louisoix...")
        IPC.Lifestream.ChangeWorld("Louisoix")
        WaitForTransfer(180, "Louisoix", "Home")
        
        -- Relog to NA
        yield("/echo [INFO] Relogging to NA character...")
        yield("/ays relog " .. NA_CHARACTER)
        yield("/wait 15")
        
        -- NA tours - STARTING WITH DYNAMIS (home DC) first
        VisitWorldList(dynamisWorlds, "Dynamis (NA)", NA_CHARACTER)
        VisitWorldList(aetherWorlds, "Aether (NA)", NA_CHARACTER)
        VisitWorldList(crystalWorlds, "Crystal (NA)", NA_CHARACTER)
        VisitWorldList(primalWorlds, "Primal (NA)", NA_CHARACTER)
        
        -- Retry congested NA worlds for up to 30 minutes
        RetryCongestedWorlds(NA_CHARACTER, 30)
        
        -- Return Dex Morgan to home world Golem after NA tour
        yield("/echo [INFO] Returning Dex Morgan to Golem...")
        IPC.Lifestream.ChangeWorld("Golem")
        WaitForTransfer(180, "Golem", "Home")
        
        -- Return to EU character and wait 30m anywhere (Lifestream handles positioning)
        yield("/echo [INFO] Relogging to EU character...")
        yield("/ays relog " .. EU_CHARACTER)
        yield("/wait 15")
        
        yield("/echo [INFO] Waiting 30 minutes before restarting...")
        yield("/wait 1800") -- 30 minutes
    end
    
    yield("/echo [SUCCESS] Completed all 3 full cycles!")
end

Main()
