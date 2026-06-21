-- Achievements for this service. crimetablet merges these into its Achievements
-- app when the service registers (keyed by id, grouped by category).
-- Track progress at runtime with:
--   exports[Rename.prefix .. 'crimetablet']:IncrementAchievement(citizenid, id, amount)

Config.achievements = {
    ['demo_first'] = {
        title = 'First Timer',
        description = 'Complete the demo service once',
        icon = 'science',
        category = 'demoservice',
        required = 1,
        reward = { rarity = 'common', type = 'crypto', amount = 50, name = '+50 MTC' },
    },
    ['demo_pro'] = {
        title = 'Demo Pro',
        description = 'Complete the demo service 5 times',
        icon = 'science',
        category = 'demoservice',
        required = 5,
        reward = { rarity = 'rare', type = 'crypto', amount = 300, name = '+300 MTC' },
    },
    ['demo_group'] = {
        title = 'Demo Crew',
        description = 'Complete the demo service 3 times as a group',
        icon = 'groups',
        category = 'demoservice',
        required = 3,
        reward = { rarity = 'rare', type = 'crypto', amount = 300, name = '+300 MTC' },
    },
}
