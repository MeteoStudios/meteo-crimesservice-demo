Config = {}

Config.debug = true

-- Service card metadata (shown in the crimetablet Services app)
-- This is the table returned inside GetServiceDescriptor().service
Config.service = {
    title = 'Demo Service',
    desc = 'A template crime service. Pays out after a short timer - copy this resource to build your own.',
    icon = 'science',           -- material icon name
    color = '#57EFAF',          -- accent color
    difficulty = 'Easy',        -- Easy | Medium | Hard (drives the badge color)
    cost = 50,                  -- crypto (MTC) charged to start
    players = '1-4',            -- display string for the group size

    -- Organization support (requires meteo-organizations). requiredLevel = 0 disables gating.
    -- crimetablet validates the leader's org + level and that group members share the org,
    -- then awards xpReward to the org on completion. Set requiredLevel = 2 to require org lvl 2.
    organization = {
        requiredLevel = 0,
        xpReward = 50,
    },
}

-- Minimum on-duty police required to start (0 = no requirement).
-- The server owner can override this per service in meteo-crimetablet config.policeCheck.minPolice.
Config.minPolice = 0

-- Cooldown applied to the leader + all group members after the service ends
Config.cooldown = { duration = 300 } -- seconds (5 min)

-- How long until the demo auto-completes (real services end on gameplay events instead)
Config.timeLimit = 60 -- seconds

-- Completion rewards (leader gets full, members get a share - see Config.group)
Config.rewards = {
    crypto = 150,
    rep = 25,
}

-- Group payout: members get memberRewardPercent of the leader's crypto + rep
Config.group = {
    rewardAllMembers = true,
    memberRewardPercent = 0.5,
}
