local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

-- ============================================================================
-- Internal cooldown data (WotLK / TBC / Classic trinkets, weapons, enchants)
-- ============================================================================

DragonUIBuffTracker = DragonUIBuffTracker or {}
local BT = DragonUIBuffTracker

BT.ICD_DEFAULT_DURATION = 45
BT.ICD_PROC_BUFF_DURATION = 30

-- Preferred display spell when a trinket has multiple proc variants (e.g. DBW).
BT.ICD_ITEM_PRIMARY_SPELL = {
	[50362] = 71485, -- Deathbringer's Will (Normal)
	[50363] = 71556, -- Deathbringer's Will (Heroic)
}

BT.ICD_SPELL_TO_ITEM = {
	-- Deathbringer's Will (Normal, item 50362) — 30s buff, 105s ICD
	-- Melee: Strength 71486, Speed 71490, Crit 71487
	-- Physical: Agility 71485, AP 71486, Aim 71491
	[71484] = 50362,
	[71485] = 50362,
	[71486] = 50362,
	[71487] = 50362,
	[71490] = 50362,
	[71491] = 50362,
	[71492] = 50362,

	-- Deathbringer's Will (Heroic, item 50363)
	-- Melee: Strength 71558, Speed 71557, Crit 71560
	-- Physical: Agility 71556, AP 71558, Aim 71559
	[71556] = 50363,
	[71557] = 50363,
	[71558] = 50363,
	[71559] = 50363,
	[71560] = 50363,
	[71561] = 50363,

	-- ICC trinkets
	[71403] = 50198, -- Needle-Encrusted Scorpion
	[71601] = 50353, -- Dislodged Foreign Object
	[71644] = 50348, -- Dislodged Foreign Object (Heroic)
	[71401] = 50342, -- Whispering Fanged Skull
	[71541] = 50343, -- Whispering Fanged Skull (Heroic)
	[71605] = 50360, -- Phylactery of the Nameless Lich
	[71636] = 50365, -- Phylactery of the Nameless Lich (Heroic)
	[71610] = 50359, -- Althor's Abacus
	[71641] = 50366, -- Althor's Abacus (Heroic)
	[71633] = 50352, -- Corpse-tongue Coin
	[71639] = 50349, -- Corpse-tongue Coin (Heroic)
	[71584] = 50358, -- Purified Lunar Dust

	-- ICC rep rings
	[72412] = { 50402, 50401 },
	[72414] = { 50404, 50403 },
	[72416] = { 50398, 50397 },
	[72418] = { 50399, 50400 },

	-- Ruby Sanctum trinkets
	[75458] = 54569, -- Sharpened Twilight Scale
	[75456] = 54590, -- Sharpened Twilight Scale (Heroic)
	[75466] = 54572, -- Charred Twilight Scale
	[75473] = 54588, -- Charred Twilight Scale (Heroic)
	[75477] = 54571, -- Petrified Twilight Scale
	[75480] = 54591, -- Petrified Twilight Scale (Heroic)

	-- Legendary weapons
	[64411] = 46017, -- Val'anyr
	[64415] = 46017, -- Val'anyr (Blessing of Ancient Kings)
	[71905] = 49668, -- Shadowmourne (Soul Fragment)
	[73422] = 49668, -- Shadowmourne (Chaos Bane)

	-- WotLK epics
	[67703] = { 47303, 47115 }, -- Death's Choice / Death's Verdict (AGI)
	[67708] = { 47303, 47115 }, -- Death's Choice / Death's Verdict (STR)
	[67772] = { 47464, 47131 }, -- Death's Choice / Death's Verdict (Heroic AGI)
	[67773] = { 47464, 47131 }, -- Death's Choice / Death's Verdict (Heroic STR)
	[67671] = 47214, -- Banner of Victory
	[67669] = 47213, -- Abyssal Rune
	[64772] = 45609, -- Comet's Trail
	[65024] = 46038, -- Dark Matter
	[60443] = 40371, -- Bandit's Insignia
	[64790] = 45522, -- Blood of the Old God
	[60203] = 42990, -- Darkmoon Card: Death
	[60494] = 40255, -- Dying Curse
	[65004] = 65005, -- Elemental Focus Stone
	[60492] = 39229, -- Embrace of the Spider
	[60530] = 40258, -- Forethought Talisman
	[60437] = 40256, -- Grim Toll
	[49623] = 37835, -- Je'Tze's Bell
	[65019] = 45931, -- Mjolnir Runestone
	[64741] = 45490, -- Pandora's Plea
	[65014] = 45286, -- Pyrite Infuser
	[65003] = 45929, -- Sif's Remembrance
	[60538] = 40382, -- Soul of the Dead
	[58904] = 43573, -- Tears of Bitter Anguish
	[60062] = { 40685, 49078 }, -- Egg of Mortal Essence / Ancient Pickled Egg
	[64765] = 45507, -- The General's Heart
	[64739] = 45535, -- Show of Faith
	[59629] = 49703, -- Black Heart of the Flame
	[71564] = { 50352, 50354, 50355, 50356 }, -- Reign (Deadly Precision)
	[67713] = { 50352, 50354, 50355, 50356 }, -- Reign (Mote of Flame)

	[60065] = { 44914, 40684, 49074 }, -- Anvil of the Titans / Mirror of Truth / Coren's Coaster
	[60064] = { 44912, 40682, 49706 }, -- Flow of Knowledge / Sundial / Mithril Pocketwatch
	[60488] = 40373, -- Extract of Necromatic Power
	[64713] = 45518, -- Flare of the Heavens

	-- Greatness cards
	[60229] = { 44253, 44254, 44255, 42987 }, -- INT
	[60233] = { 44253, 44254, 44255, 42987 }, -- AGI
	[60234] = { 44253, 44254, 44255, 42987 }, -- STR
	[60235] = { 44253, 44254, 44255, 42987 }, -- SPI

	-- WotLK blues
	[51353] = 38358, -- Arcane Revitalizer
	[51348] = 38359, -- Goblin Repetition Reducer
	[60218] = 37220, -- Essence of Gossamer
	[60479] = 37660, -- Forge Ember
	[63250] = { 45131, 45219 }, -- Jouster's Fury
	[60302] = 37390, -- Meteorite Whetstone
	[54808] = 40865, -- Noise Machine
	[60483] = 37264, -- Pendulum of Telluric Currents
	[52424] = 38675, -- Signet of the Dark Brotherhood
	[55018] = 40767, -- Sonic Booster
	[52419] = 38674, -- Soul Harvester's Charm
	[60520] = 37264, -- Spark of Life
	[60307] = 37064, -- Vestige of Haldor

	-- The Burning Crusade
	[33648] = 28034, -- Hourglass of the Unraveller
	[42084] = 21698, -- Tsunami Talisman
	[35095] = 29370, -- Icon of the Silver Crescent
	[33297] = 27683, -- Quagmirran's Eye
	[33807] = 28288, -- Abacus of Violent Odds
	[38321] = 29181, -- Icon of Unyielding Courage
	[34774] = 32658, -- Badge of Tenacity
	[28862] = 22954, -- Kiss of the Spider
	[34775] = 28041, -- Bladefist's Breadth
	[37657] = 35783, -- Shard of Contempt

	-- Vanilla
	[23684] = 19288, -- Darkmoon Card: Blue Dragon
}

BT.ICD_COOLDOWNS = {
	-- Deathbringer's Will (105s / 1.75 min ICD, 30s proc)
	[71484] = 105,
	[71485] = 105,
	[71486] = 105,
	[71487] = 105,
	[71490] = 105,
	[71491] = 105,
	[71492] = 105,
	[71556] = 105,
	[71557] = 105,
	[71558] = 105,
	[71559] = 105,
	[71560] = 105,
	[71561] = 105,

	-- ICC rep rings
	[72412] = 60,
	[72414] = 60,
	[72416] = 60,
	[72418] = 60,

	-- Phylactery
	[71605] = 90,
	[71636] = 90,

	-- Ruby Sanctum
	[75458] = 45,
	[75456] = 45,
	[75466] = 45,
	[75473] = 45,
	[75477] = 45,
	[75480] = 45,

	-- Enchants / engineering
	[59620] = 90,
	[59626] = 35,

	-- Misc WotLK
	[60488] = 15,
	[51348] = 10,
	[51353] = 10,
	[54808] = 60,
	[55018] = 60,
	[52419] = 30,
	[59629] = 45,
	[71564] = 45,
	[67713] = 45,
	[64415] = 30,
	[73422] = 45,

	-- The Burning Crusade
	[33648] = 90,
	[42084] = 60,
	[35095] = 90,
	[33297] = 45,
	[33807] = 45,
	[38321] = 90,
	[34774] = 45,
	[28862] = 120,
	[34775] = 50,
	[37657] = 45,
}

BT.ICD_ENCHANTS = {
	[55637] = { 3722, 15 }, -- Lightweave Embroidery
	[55775] = { 3730, 15 }, -- Swordguard Embroidery
	[55767] = { 3728, 15 }, -- Darkglow Embroidery
	[59626] = { 3790, 16 }, -- Black Magic
}
