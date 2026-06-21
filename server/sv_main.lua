--[[
    Reference implementation of the meteo-crimetablet service contract

    Contract (server exports, fixed names):
        GetServiceDescriptor()                 -> { id, service, minPolice, achievements, achievementCategory }
        IsServiceActive()                      -> bool   (global single-instance lock)
        IsPlayerInService(source)              -> bool   (leader OR group member)
        GetServiceCooldown(citizenid)          -> seconds remaining
        StartService(source, groupData, orgId) -> { success, data?, error?, name?, remaining?, newBalance? }
--]]

local QBCore = exports['qb-core']:GetCoreObject()

math.randomseed(os.time())

-- MUST be unique across every service (drives the registry key, achievement
-- category and svc_<id>_error_ locale prefix). A clash overwrites another service.
local SERVICE_ID = 'demoservice'

-- In-memory state
local Active = {}      -- leaderSource -> mission data
local GroupMap = {}    -- memberSource -> leaderSource
local Cooldowns = {}   -- citizenid -> os.time() expiry

-- HELPERS

local function GetCid(source)
    local player = QBCore.Functions.GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end

local function IsPlayerOnline(source)
    return source and GetPlayerPed(source) ~= 0
end

local function IsPlayerIncapacitated(source)
    if not IsPlayerOnline(source) then return true end
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return true end
    local meta = player.PlayerData.metadata
    if not meta then return false end
    return toBool(meta['isdead'], false) or toBool(meta['ishandcuffed'], false) or toBool(meta['inlaststand'], false)
end

local function FormatTime(seconds)
    return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

local function CrimetabletReady()
    return GetResourceState(Rename.prefix .. 'crimetablet') == 'started'
end

-- Cooldown

local function GetCooldown(citizenid)
    if not citizenid or not Cooldowns[citizenid] then return 0 end
    local remaining = Cooldowns[citizenid] - os.time()
    if remaining <= 0 then
        Cooldowns[citizenid] = nil
        return 0
    end
    return remaining
end

local function ApplyCooldowns(mission)
    local expiry = os.time() + Config.cooldown.duration
    if mission.citizenid then Cooldowns[mission.citizenid] = expiry end
    if mission.groupData then
        for _, m in ipairs(mission.groupData.members) do
            if m.citizenid then Cooldowns[m.citizenid] = expiry end
        end
    end
end

-- Crypto: the wallet lives in crimetablet. We go through its exports, never its
-- DB - so a service needs no oxmysql and no knowledge of the crypto schema.
--   GetCryptoBalance(citizenid)            -> balance
--   RemoveCrypto(citizenid, amount, reason)-> bool (checks balance internally)
--   AddCrypto(citizenid, amount, reason)   -> bool (also logs + achievements)

local function GetBalance(citizenid)
    if not CrimetabletReady() then return 0 end
    return exports[Rename.prefix .. 'crimetablet']:GetCryptoBalance(citizenid) or 0
end

-- Refresh a player's wallet balance on their tablet UI (crimetablet handles it)
local function PushBalance(source)
    if not CrimetabletReady() then return 0 end
    return exports[Rename.prefix .. 'crimetablet']:PushBalance(source)
end

-- Resolve a mission from leader or member source
local function ResolveMission(source)
    if Active[source] then return Active[source], source end
    local leader = GroupMap[source]
    if leader and Active[leader] then return Active[leader], leader end
    return nil, nil
end

-- Achievements (progress is stored by crimetablet)
local function TrackCompletion(citizenid, isGroup)
    if not citizenid or not CrimetabletReady() then return end
    pcall(function()
        exports[Rename.prefix .. 'crimetablet']:IncrementAchievement(citizenid, 'demo_first', 1)
        exports[Rename.prefix .. 'crimetablet']:IncrementAchievement(citizenid, 'demo_pro', 1)
        if isGroup then
            exports[Rename.prefix .. 'crimetablet']:IncrementAchievement(citizenid, 'demo_group', 1)
        end
    end)
end

-- LIFECYCLE

local function CleanupMission(leaderSource)
    local mission = Active[leaderSource]
    if not mission then return end

    -- Clear group mappings + unlock the group in crimetablet
    if mission.groupData then
        for src, leader in pairs(GroupMap) do
            if leader == leaderSource then GroupMap[src] = nil end
        end
        if CrimetabletReady() then
            pcall(function()
                exports[Rename.prefix .. 'crimetablet']:SetGroupBusy(mission.groupData.groupId, false, nil)
            end)
        end
    end

    Active[leaderSource] = nil
    DebugPrint('Mission cleaned up for', leaderSource)
end

local function CompleteMission(leaderSource)
    local mission = Active[leaderSource]
    if not mission or mission.completed then return end
    mission.completed = true

    local crypto = Config.rewards.crypto
    local rep = Config.rewards.rep
    local isGroup = mission.groupData ~= nil

    DebugPrint('Mission COMPLETE for', mission.citizenid, '- paying', crypto, 'MTC +', rep, 'rep')

    if CrimetabletReady() then
        exports[Rename.prefix .. 'crimetablet']:AddCrypto(mission.citizenid, crypto, 'Demo service completed')
        exports[Rename.prefix .. 'crimetablet']:AddReputation(mission.citizenid, rep)
        exports[Rename.prefix .. 'crimetablet']:AddRecentActivity(mission.citizenid, 'Demo service completed', Config.service.icon, Config.service.color)
    end

    TrackCompletion(mission.citizenid, isGroup)

    -- Org XP (no-op if no org / requiredLevel 0 still awards if leader has an org)
    if (Config.service.organization and Config.service.organization.xpReward or 0) > 0 and CrimetabletReady() then
        pcall(function()
            exports[Rename.prefix .. 'crimetablet']:AddServiceOrgXP(mission.citizenid, Config.service.organization.xpReward)
        end)
    end

    QBCore.Functions.Notify(leaderSource, ('Demo service complete: +%s MTC'):format(crypto), 'success')
    PushBalance(leaderSource)
    TriggerClientEvent('meteo-crimesservice-demo:client:missionEnded', leaderSource, { completed = true })

    -- Group member payout (share of leader rewards)
    if isGroup and Config.group.rewardAllMembers and CrimetabletReady() then
        local mCrypto = math.floor(crypto * Config.group.memberRewardPercent)
        local mRep = math.floor(rep * Config.group.memberRewardPercent)
        for _, m in ipairs(mission.groupData.members) do
            if m.source ~= leaderSource then
                exports[Rename.prefix .. 'crimetablet']:AddCrypto(m.citizenid, mCrypto, 'Demo service completed (group)')
                exports[Rename.prefix .. 'crimetablet']:AddReputation(m.citizenid, mRep)
                TrackCompletion(m.citizenid, true)
                if IsPlayerOnline(m.source) then
                    QBCore.Functions.Notify(m.source, ('Demo service complete: +%s MTC'):format(mCrypto), 'success')
                    PushBalance(m.source)
                    TriggerClientEvent('meteo-crimesservice-demo:client:missionEnded', m.source, { completed = true })
                end
            end
        end
    end

    ApplyCooldowns(mission)

    CreateThread(function()
        Wait(3000)
        CleanupMission(leaderSource)
    end)
end

local function StartServiceInternal(source, groupData, leaderOrgId)
    local citizenid = GetCid(source)
    if not citizenid then return { success = false, error = 'no_player' } end

    if Active[source] then return { success = false, error = 'already_active' } end
    if IsPlayerIncapacitated(source) then return { success = false, error = 'player_incapacitated' } end

    local cooldown = GetCooldown(citizenid)
    if cooldown > 0 then
        return { success = false, error = 'cooldown', remaining = FormatTime(cooldown) }
    end

    -- Group member readiness + cooldown checks (incapacitation is also re-checked here)
    if groupData then
        for _, m in ipairs(groupData.members) do
            if m.source ~= source then
                if IsPlayerIncapacitated(m.source) then
                    return { success = false, error = 'member_incapacitated' }
                end
                local mCooldown = GetCooldown(m.citizenid)
                if mCooldown > 0 then
                    return { success = false, error = 'member_cooldown', name = m.name, remaining = FormatTime(mCooldown) }
                end
            end
        end
    end

    -- Crypto cost (via crimetablet exports). RemoveCrypto checks the balance
    -- internally and returns false if the player can't afford it.
    if not CrimetabletReady() then return { success = false, error = 'not_available' } end
    if not exports[Rename.prefix .. 'crimetablet']:RemoveCrypto(citizenid, Config.service.cost, 'Demo service entry fee') then
        return { success = false, error = 'insufficient_funds' }
    end
    local newBalance = GetBalance(citizenid)

    -- Store mission state
    Active[source] = {
        citizenid = citizenid,
        startedAt = os.time(),
        groupData = groupData,
        orgId = leaderOrgId,
    }
    if groupData then
        for _, m in ipairs(groupData.members) do
            if m.source ~= source then GroupMap[m.source] = source end
        end
    end

    DebugPrint('Mission STARTED by', citizenid, groupData and ('(group of ' .. #groupData.members .. ')') or '(solo)',
        leaderOrgId and ('org ' .. tostring(leaderOrgId)) or '')

    -- Auto-complete after the timer (real services complete on gameplay events)
    CreateThread(function()
        Wait(Config.timeLimit * 1000)
        if Active[source] and not Active[source].completed then
            CompleteMission(source)
        end
    end)

    return {
        success = true,
        newBalance = newBalance,
        data = {
            -- Anything the client needs to run the mission. Stubbed here.
            timeLimit = Config.timeLimit,
            message = 'Demo service started - it will auto-complete in ' .. Config.timeLimit .. 's',
        },
    }
end

-- CONTRACT EXPORTS

exports('GetServiceDescriptor', function()
    return {
        id = SERVICE_ID,
        service = Config.service,
        minPolice = Config.minPolice or 0,
        achievements = Config.achievements,
        achievementCategory = SERVICE_ID,
    }
end)

exports('IsServiceActive', function()
    return next(Active) ~= nil
end)

exports('IsPlayerInService', function(source)
    return Active[source] ~= nil or GroupMap[source] ~= nil
end)

exports('GetServiceCooldown', function(citizenid)
    return GetCooldown(citizenid)
end)

exports('StartService', function(source, groupData, leaderOrgId)
    return StartServiceInternal(source, groupData, leaderOrgId)
end)

-- REGISTRATION (rename-safe: we pass our OWN resource name)

local self = GetCurrentResourceName()

local function registerService()
    local ct = Rename.prefix .. 'crimetablet'
    if GetResourceState(ct) ~= 'started' then return end
    exports[ct]:RegisterService(SERVICE_ID, self)
    DebugPrint('Registered with', ct)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == self then registerService() end
end)
-- crimetablet (re)started after us - re-register
AddEventHandler('meteo-crimetablet:server:ready', registerService)
-- crimetablet was already up when we started
CreateThread(registerService)

-- CLEANUP

AddEventHandler('playerDropped', function()
    local src = source
    if Active[src] then CleanupMission(src) end
    GroupMap[src] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if Active[src] then CleanupMission(src) end
    GroupMap[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= self then return end
    for leaderSource, mission in pairs(Active) do
        TriggerClientEvent('meteo-crimesservice-demo:client:missionEnded', leaderSource, { cancelled = true })
        if mission.groupData then
            for _, m in ipairs(mission.groupData.members) do
                if m.source ~= leaderSource and IsPlayerOnline(m.source) then
                    TriggerClientEvent('meteo-crimesservice-demo:client:missionEnded', m.source, { cancelled = true })
                end
            end
            if CrimetabletReady() then
                pcall(function()
                    exports[Rename.prefix .. 'crimetablet']:SetGroupBusy(mission.groupData.groupId, false, nil)
                end)
            end
        end
    end
    Active = {}
    GroupMap = {}
end)
