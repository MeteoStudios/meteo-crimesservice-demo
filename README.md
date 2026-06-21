# meteo-crimesservice-demo

A **reference / template crime service** for the `meteo-crimetablet` **Services** app.

Copy this resource to build your own service (heist, hunt, robbery, etc.). The gameplay
here is intentionally stubbed (prints + a timer that auto-completes) so you can focus on the
**contract**: crypto cost, cooldowns, organization level support, group members, rewards and
achievements. `meteo-crimetablet` handles the Services-app card, the cross-service / group /
police locks, and the org gating for you.

## How it works

Services are **self-registering plugins**. On start, this resource calls:

```lua
exports[Rename.prefix .. 'crimetablet']:RegisterService('demoservice', GetCurrentResourceName())
```

crimetablet stores your resource's **own** name and talks to it through a fixed set of
exports. Because you pass `GetCurrentResourceName()` (not a hardcoded/prefixed string), the
service keeps working if the resource is renamed - crimetablet never rebuilds your name from
`Rename.prefix`.

## The contract

Implement these exports (see `server/sv_main.lua` and `client/cl_main.lua`).

### Server
| Export | Returns | Purpose |
|---|---|---|
| `GetServiceDescriptor()` | `{ id, service, minPolice, achievements, achievementCategory }` | Card metadata + achievements |
| `IsServiceActive()` | bool | Global single-instance lock |
| `IsPlayerInService(source)` | bool | True if leader OR group member |
| `GetServiceCooldown(citizenid)` | seconds | Remaining cooldown for the player |
| `StartService(source, groupData, leaderOrgId)` | `{ success, data?, error?, ... }` | Start the mission server-side |

`groupData` (nil for solo) = `{ groupId, members = { { source, citizenid, name }, ... } }`.
`leaderOrgId` is the leader's organization id (or nil) - crimetablet has already validated
the org requirement before calling you.

### Client
| Export | Purpose |
|---|---|
| `StartServiceClient(data)` | Leader starts the client-side mission (`data` = your `StartService` result's `data`) |
| `JoinServiceClient(data)` | Group member starts the client-side mission |

The client needs **no** registration - crimetablet passes the owning resource name from the
server, so it calls your exports directly.

## Registration block (copy verbatim, change only the id)

Server (`server/sv_main.lua`):

```lua
local self = GetCurrentResourceName()
local function registerService()
    local ct = Rename.prefix .. 'crimetablet'
    if GetResourceState(ct) ~= 'started' then return end
    exports[ct]:RegisterService('demoservice', self)
end
AddEventHandler('onResourceStart', function(r) if r == self then registerService() end end)
AddEventHandler('meteo-crimetablet:server:ready', registerService) -- crimetablet (re)started
CreateThread(registerService)                                      -- crimetablet already up
```

## Config (`shared/config.lua`)

- `Config.service` - card metadata: `title, desc, icon, color, difficulty, cost, players` and
  `organization = { requiredLevel, xpReward }` (set `requiredLevel = 0` to disable org gating).
- `Config.minPolice` - min on-duty police to start (owner can override in crimetablet config).
- `Config.cooldown.duration` - seconds applied to leader + members after the service ends.
- `Config.rewards` - `{ crypto, rep }` paid on completion.
- `Config.group` - `{ rewardAllMembers, memberRewardPercent }` (members get a share).
- `Config.achievements` (`shared/achievements.lua`) - merged into the Achievements app;
  track with `exports[ct]:IncrementAchievement(citizenid, id, amount)`.

## Time-limit HUD (optional - meteo-timelimit)

If `meteo-timelimit` is running, the client shows a countdown for the mission. The server
sends `data.timeLimit` in the `StartService` result; the client starts the HUD in
`beginMission` and clears it on any end:

```lua
exports[Rename.prefix .. 'timelimit']:StartTimer({ title = Config.service.title, remaining = seconds })
exports[Rename.prefix .. 'timelimit']:StopTimer()
```

Guard both with `GetResourceState` so the service still works without it.

## Crypto + rewards (wallet lives in crimetablet)

Always go through crimetablet's exports - never touch its DB. A service needs no oxmysql.

- Balance: `exports[ct]:GetCryptoBalance(citizenid)`.
- Charge: `exports[ct]:RemoveCrypto(citizenid, amount, reason)` - returns `false` if the
  player can't afford it (checks the balance internally, so no separate balance check needed).
- Reward: `exports[ct]:AddCrypto(citizenid, amount, reason)`, `:AddReputation(citizenid, rep)`,
  `:AddRecentActivity(citizenid, text, icon, color)`.
- Org XP: `exports[ct]:AddServiceOrgXP(citizenid, amount)`.
- After awarding/charging outside a tablet round-trip, refresh the player's wallet UI with
  `exports[ct]:PushBalance(source)` (takes the server id, returns the balance).

## Errors

Return `{ success = false, error = '<code>' }`. The Services app resolves
`svc_demoservice_error_<code>` -> `svc_error_<code>` (shared) -> `svc_error_generic`, so the
standard codes (`insufficient_funds`, `cooldown`, `player_incapacitated`, ...) display
correctly **without** adding any locale keys to crimetablet.

## Install

`ensure meteo-crimesservice-demo` after `meteo-crimetablet`. Open the tablet -> Services -> "Demo
Service". With `Config.debug = true` you'll see `^6[METEO DEMOSERVICE]^0` console prints for
register / start / complete.
