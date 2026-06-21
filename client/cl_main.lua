--[[
    Reference implementation of the meteo-crimetablet service client contract.

    Contract (client exports, fixed names):
        StartServiceClient(data)   -- the LEADER starts the client-side mission
        JoinServiceClient(data)    -- a GROUP MEMBER starts the client-side mission
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- Time-limit HUD (optional dependency - meteo-timelimit)
local function startTimeLimit(remaining)
    local res = Rename.prefix .. 'timelimit'
    if remaining and remaining > 0 and GetResourceState(res) == 'started' then
        exports[res]:StartTimer({ title = Config.service.title, remaining = remaining })
    end
end

local function stopTimeLimit()
    local res = Rename.prefix .. 'timelimit'
    if GetResourceState(res) == 'started' then
        exports[res]:StopTimer()
    end
end

-- Stubbed gameplay. Real services would spawn entities, set up targets/blips, etc.
local function beginMission(data, asMember)
    if not data then return end
    DebugPrint('Mission begin -', asMember and 'group member' or 'leader', '-', data.message or '')
    QBCore.Functions.Notify(
        asMember and 'You joined a demo service' or (data.message or 'Demo service started'),
        'primary'
    )
    -- Show the countdown HUD for the whole mission
    startTimeLimit(data.timeLimit)
end

-- LEADER entry point
exports('StartServiceClient', function(data)
    beginMission(data, false)
end)

-- GROUP MEMBER entry point
exports('JoinServiceClient', function(data)
    beginMission(data, true)
end)

-- Server tells us the mission ended (completed / failed / cancelled)
RegisterNetEvent('meteo-crimesservice-demo:client:missionEnded', function(info)
    info = info or {}
    stopTimeLimit() -- always clear the HUD, whatever the outcome
    if info.completed then
        DebugPrint('Mission ended: completed')
    elseif info.cancelled then
        DebugPrint('Mission ended: cancelled')
        QBCore.Functions.Notify('Demo service cancelled', 'error')
    elseif info.failed then
        DebugPrint('Mission ended: failed')
        QBCore.Functions.Notify('Demo service failed', 'error')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopTimeLimit()
    end
end)
