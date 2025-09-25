local testMode = false

local chaosWorlds = {
    "Cerberus", "Louisoix", "Moogle", "Omega",
    "Phantom", "Ragnarok", "Sagittarius", "Spriggan",
}

local lightWorlds = {
    "Lich", "Odin", "Phoenix", "Raiden",
    "Shiva", "Twintania", "Zodiark",
}

local aetherWorlds = {
    "Adamantoise", "Cactuar", "Faerie", "Gilgamesh",
    "Jenova", "Midgardsormr", "Sargatanas",
}

local crystalWorlds = {
    "Balmung", "Brynhildr", "Coeurl", "Diabolos",
    "Goblin", "Malboro", "Mateus",
}

local dynamisWorlds = {
    "Cuchulainn", "Golem", "Halicarnassus", "Kraken",
    "Maduin", "Marilith", "Rafflesia", "Seraph",
}

local primalWorlds = {
    "Excalibur", "Exodus", "Famfrit",
    "Hyperion", "Lamia", "Leviathan", "Behemoth",
}

-- ✅ Updated test worlds
local testWorlds = {
    chaos = "Cerberus",
    light = "Lich",
    aether = "Adamantoise",
    crystal = "Balmung",
    dynamis = "Cuchulainn",
    primal = "Excalibur",
}

local cityAetherytes = {
    { id = 8,  zone = 129, name = "Limsa Lominsa" },
    { id = 9,  zone = 130, name = "Ul'dah" },
    { id = 2,  zone = 132, name = "New Gridania" },
}

local testCityAetheryte = {
    { id = 9, zone = 130, name = "Ul'dah" },
}

local cityIndex = 1
local retryWorlds = {}

local function WaitForTransferSimple()
    repeat yield("/wait 4") until IPC.Lifestream.IsBusy()
    repeat yield("/wait 4") until not IPC.Lifestream.IsBusy()
    yield("/wait 4")
end

local function VisitCities()
    local currentZone = IPC.Lifestream.GetRealTerritoryType()
    local cities = testMode and testCityAetheryte or cityAetherytes

    if not testMode then
        for i, city in ipairs(cities) do
            if currentZone == city.zone then
                cityIndex = i
                break
            end
        end
    end

    for step = 1, #cities do
        local city = cities[testMode and 1 or cityIndex]

        if currentZone ~= city.zone then
            local doneZone = IPC.Lifestream.GetRealTerritoryType()
            IPC.Lifestream.Teleport(city.id, 0)         
            local waitTime = 0
            local maxWait = 30
            repeat
                yield("/wait 1")
                waitTime = waitTime + 1
            until IPC.Lifestream.GetRealTerritoryType() ~= doneZone or waitTime >= maxWait

            if waitTime >= maxWait then
                yield("/echo Teleport to " .. city.name .. " failed or timed out! <se.6>")
                return
            end
            currentZone = IPC.Lifestream.GetRealTerritoryType()
        end
        while Svc.Condition[45] do
            yield("/wait 2") 
        end
        yield("/wait 2") 
        yield("/echo Shout in " .. city.name .. " → StingKnight Cat stinks <se.7>")
        yield("/wait 2") 

        if not testMode then
            cityIndex = (cityIndex % #cityAetherytes) + 1
        end
    end
end

local function WaitForTransfer(world)
    yield("/echo Attempting transfer to " .. world .. "...")
    IPC.Lifestream.ChangeWorld(world)

    local checkInterval = 4
    local maxWait = 200
    local waitTime = 0

    -- Wait until transfer actually starts
    repeat
        yield("/wait " .. checkInterval)
        waitTime = waitTime + checkInterval
    until IPC.Lifestream.IsBusy() or waitTime >= maxWait

    if waitTime >= maxWait then
        yield("/echo Transfer to " .. world .. " never started. Skipping...")
        return false
    end

    -- Wait until transfer completes
    waitTime = 0
    repeat
        yield("/wait " .. checkInterval)
        waitTime = waitTime + checkInterval
    until not IPC.Lifestream.IsBusy() or waitTime >= maxWait

    if waitTime >= maxWait then
        yield("/echo Transfer to " .. world .. " did not finish. Skipping...")
        return false
    end

    return true
end

local function VisitWorlds(worlds)
    local worldList = testMode and { worlds } or worlds
    for _, world in ipairs(worldList) do
        local success = WaitForTransfer(world)

        if success then
            yield("/wait 2")
            VisitCities()
        else
            yield("/echo Skipping " .. world .. " due to congestion or timeouts.")
            table.insert(retryWorlds, world)
        end

        yield("/wait 5")
    end
end

local function RetrySkippedWorlds()
    if #retryWorlds == 0 then
        yield("/echo No skipped worlds this run.")
    else
        yield("/echo Retrying skipped worlds until success...")
    end

    local startTime = os.time()
    local totalWait = 2000

    for i = #retryWorlds, 1, -1 do
        local world = retryWorlds[i]
        local success = false

        while not success do
            success = WaitForTransfer(world)

            if success then
                yield("/wait 2")
                VisitCities()
                table.remove(retryWorlds, i)
            else
                yield("/wait 30")
            end
        end
    end

    -- Perform the Golem → relog → 2000s wait sequence
    IPC.Lifestream.ChangeWorld("Golem")
    WaitForTransferSimple()
    yield("/wait 20")
    yield("/ays relog Deb Morgan@Louisoix")
    yield("/wait 90")
    yield("/busy")
    yield("/li Alchemists' Guild")

    local elapsed = os.time() - startTime
    local remaining = totalWait - elapsed
    if remaining > 0 then
        yield("/wait " .. remaining)
    end

    yield("/li Ul'dah Aetheryte Plaza")
    yield("/busy")
    yield("/wait 10")
end

-- Main execution loop
for i = 1, 3 do
    yield("/busy")

    VisitWorlds(testMode and testWorlds.chaos or chaosWorlds)

    yield("/echo Preparing Data Center Travel to Alpha...")
    IPC.Lifestream.ChangeWorld("Alpha")
    if WaitForTransfer("Alpha") then
        yield("/wait 2")
        yield("/busy")
        VisitCities()
    end

    VisitWorlds(testMode and testWorlds.light or lightWorlds)
    yield("/wait 5")

    IPC.Lifestream.ChangeWorld("Louisoix")
    WaitForTransferSimple()
    yield("/wait 20")
    yield("/ays relog Dex Morgan@Golem")
    yield("/wait 90")
    yield("/busy")

    VisitWorlds(testMode and testWorlds.dynamis or dynamisWorlds)

    IPC.Lifestream.ChangeWorld("Ultros")
    if WaitForTransfer("Ultros") then
        yield("/wait 2")
        yield("/busy")
        VisitCities()
    end
    VisitWorlds(testMode and testWorlds.primal or primalWorlds)

    IPC.Lifestream.ChangeWorld("Siren")
    if WaitForTransfer("Siren") then
        yield("/wait 2")
        yield("/busy")
        VisitCities()
    end
    VisitWorlds(testMode and testWorlds.aether or aetherWorlds)

    IPC.Lifestream.ChangeWorld("Zalera")
    if WaitForTransfer("Zalera") then
        yield("/wait 2")
        yield("/busy")
        VisitCities()
    end
    VisitWorlds(testMode and testWorlds.crystal or crystalWorlds)

    -- Retry skipped servers only after full round
    RetrySkippedWorlds()
end
