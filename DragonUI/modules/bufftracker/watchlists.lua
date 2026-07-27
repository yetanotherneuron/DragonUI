local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

DragonUIBuffTracker = DragonUIBuffTracker or {}
local BT = DragonUIBuffTracker

BT.WATCH_LISTS = {
	classes = {
		actives = {
			WARRIOR = {
				{ id = 46924, border = "spells", duration = true }, -- Bladestorm
				{ id = 12292, border = "spells", duration = true }, -- Death Wish
				{ id = 55694, border = "spells", duration = true }, -- Enraged Regeneration
				{ id = 12976, border = "spells", duration = true }, -- Last Stand (aura; cast 12975)
				{ id = 1719, border = "spells", duration = true }, -- Recklessness
				{ id = 20230, border = "spells", duration = true }, -- Retaliation
				{ id = 871, border = "spells", duration = true }, -- Shield Wall
				{ id = 12328, border = "spells", duration = true }, -- Sweeping Strikes
			},
			PALADIN = {
				{ id = 31884, border = "spells", duration = true }, -- Avenging Wrath
				{ id = 20216, border = "spells", duration = true }, -- Divine Favor
				{ id = 54428, border = "spells", duration = true }, -- Divine Plea
				{ id = 642, border = "spells", duration = true }, -- Divine Shield
				{ id = 1044, border = "spells", duration = true }, -- Hand of Freedom
				{ id = 1022, border = "spells", duration = true }, -- Hand of Protection
				{ id = 1038, border = "spells", duration = true }, -- Hand of Salvation
				{ id = 48952, border = "spells", duration = true, ranks = { 48951, 48952 } }, -- Holy Shield
				{ id = 53601, border = "spells", duration = true }, -- Sacred Shield
			},
			HUNTER = {
				{ id = 19574, border = "spells", duration = true }, -- Bestial Wrath
				{ id = 54216, border = "spells", duration = true }, -- Master's Call
				{ id = 3045, border = "spells", duration = true }, -- Rapid Fire
				{ id = 23989, border = "spells", duration = true }, -- Readiness
			},
			ROGUE = {
				{ id = 13750, border = "spells", duration = true }, -- Adrenaline Rush
				{ id = 13877, border = "spells", duration = true }, -- Blade Flurry
				{ id = 5277, border = "spells", duration = true }, -- Evasion
				{ id = 51690, border = "spells", duration = true }, -- Killing Spree
				{ id = 51713, border = "spells", duration = true }, -- Shadow Dance
				{ id = 5171, border = "spells", duration = true }, -- Slice and Dice
				{ id = 1856, border = "spells", duration = true }, -- Vanish
			},
			PRIEST = {
				{ id = 47585, border = "spells", duration = true }, -- Dispersion
				{ id = 14751, border = "spells", duration = true }, -- Inner Focus
			},
			DEATHKNIGHT = {
				{ id = 48707, border = "spells", duration = true }, -- Anti-Magic Shell
				{ id = 49222, border = "spells", duration = true, stacks = true }, -- Bone Shield
				{ id = 45529, border = "spells", duration = true }, -- Blood Tap
				{ id = 49028, border = "spells", duration = true }, -- Dancing Rune Weapon
				{ id = 47568, border = "spells", duration = true }, -- Empower Rune Weapon
				{ id = 49206, border = "spells", duration = true }, -- Summon Gargoyle
				{ id = 48792, border = "spells", duration = true }, -- Icebound Fortitude
				{ id = 51271, border = "spells", duration = true }, -- Unbreakable Armor
				{ id = 55233, border = "spells", duration = true }, -- Vampiric Blood
			},
			SHAMAN = {
				{ id = 16166, border = "spells", duration = true }, -- Elemental Mastery
				{ id = 51533, border = "spells", duration = true }, -- Feral Spirit
				{ id = 30823, border = "spells", duration = true }, -- Shamanistic Rage
			},
			MAGE = {
				{ id = 12042, border = "spells", duration = true }, -- Arcane Power
				{ id = 11129, border = "spells", duration = true }, -- Combustion
				{ id = 12472, border = "spells", duration = true }, -- Icy Veins
				{ id = 55342, border = "spells", duration = true }, -- Mirror Image
				{ id = 12043, border = "spells", duration = true }, -- Presence of Mind
			},
			WARLOCK = {
				{ id = 47193, border = "spells", duration = true }, -- Demonic Empowerment
				{ id = 59672, border = "spells", duration = true }, -- Metamorphosis
				{ id = 19028, border = "spells", duration = true }, -- Soul Link
			},
			DRUID = {
				{ id = 22812, border = "spells", duration = true }, -- Barkskin
				{ id = 50334, border = "spells", duration = true }, -- Berserk
				{ id = 29166, border = "spells", duration = true }, -- Innervate
				{ id = 53312, border = "spells", duration = true }, -- Nature's Grasp
				{ id = 61336, border = "spells", duration = true }, -- Survival Instincts
				{ id = 50213, border = "spells", duration = true }, -- Tiger's Fury
			},
		},
		passives = {
			WARRIOR = {
				{ id = 46916, border = "procs" }, -- Blood Surge
				{ id = 52437, border = "procs" }, -- Sudden Death
				{ id = 50227, border = "procs" }, -- Sword and Board
				{ id = 60503, border = "procs" }, -- Taste for Blood
				{ id = 57522, border = "procs", duration = true, ranks = { 12880, 14202, 14203, 14204, 14205 } }, -- Enrage
			},
			PALADIN = {
				{ id = 54149, border = "procs" }, -- Infusion of Light
				{ id = 53657, border = "procs", duration = true }, -- Judgements of the Pure
				{ id = 59578, border = "procs" }, -- The Art of War
			},
			HUNTER = {
				{ id = 53220, border = "procs", duration = true }, -- Improved Steady Shot
				{ id = 56453, border = "procs" }, -- Lock and Load
				{ id = 64420, border = "procs", duration = true }, -- Sniper Training
			},
			ROGUE = {
				{ id = 63848, border = "procs", duration = true }, -- Hunger For Blood
				{ id = 58426, border = "procs", duration = true }, -- Overkill
			},
			PRIEST = {
				{ id = 52893, border = "procs", duration = true }, -- Borrowed Time
				{ id = 34754, border = "procs", duration = true }, -- Holy Concentration
				{ id = 47755, border = "procs", duration = true }, -- Improved Spirit Tap
				{ id = 33151, border = "procs" }, -- Surge of Light
			},
			DEATHKNIGHT = {
				{ id = 59052, border = "procs" }, -- Freezing Fog (Rime)
				{ id = 51124, border = "procs" }, -- Killing Machine
				{ id = 81340, border = "procs" }, -- Sudden Doom
			},
			SHAMAN = {
				{ id = 16246, border = "procs" }, -- Clearcasting
				{ id = 53804, border = "procs" }, -- Lightning Overload
				{ id = 53817, border = "procs", stacks = true }, -- Maelstrom Weapon
				{ id = 53390, border = "procs", stacks = true }, -- Tidal Waves
			},
			MAGE = {
				{ id = 57761, border = "procs", stacks = true }, -- Brain Freeze
				{ id = 12536, border = "procs" }, -- Clearcasting
				{ id = 44544, border = "procs", stacks = true }, -- Fingers of Frost
				{ id = 48108, border = "procs" }, -- Hot Streak
				{ id = 44401, border = "procs", stacks = true }, -- Missile Barrage
			},
			WARLOCK = {
				{ id = 34936, border = "procs" }, -- Backlash
				{ id = 63167, border = "procs" }, -- Decimation
				{ id = 64371, border = "procs", duration = true }, -- Eradication
				{ id = 47258, border = "procs", stacks = true }, -- Molten Core
				{ id = 17941, border = "procs" }, -- Shadow Trance (Nightfall)
			},
			DRUID = {
				{ id = 48518, border = "procs", duration = true }, -- Eclipse (Lunar)
				{ id = 48517, border = "procs", duration = true }, -- Eclipse (Solar)
				{ id = 16870, border = "procs" }, -- Omen of Clarity
				{ id = 62606, border = "procs", duration = true }, -- Savage Defense
			},
		},
	},
	buffs = {
		{ id = 53138, border = "utility" }, -- Abomination's Might
		{ id = 48932, border = "utility", ranks = { 48932, 48933, 48934 } }, -- Blessing of Might
		{ id = 20217, border = "utility", ranks = { 20217, 25898 } }, -- Blessing of Kings
		{ id = 67480, border = "utility", ranks = { 20911, 25899, 67480 } }, -- Blessing of Sanctuary
		{ id = 48938, border = "utility", ranks = { 48936, 48938 } }, -- Blessing of Wisdom
		{ id = 2825, border = "utility", duration = true }, -- Bloodlust
		{ id = 47436, border = "utility", ranks = { 47436, 47437 } }, -- Battle Shout
		{ id = 47440, border = "utility", ranks = { 47440, 47441 } }, -- Commanding Shout
		{ id = 64205, border = "utility", duration = true }, -- Divine Sacrifice
		{ id = 48942, border = "utility" }, -- Devotion Aura
		{ id = 32182, border = "utility", duration = true }, -- Heroism
		{ id = 57330, border = "utility" }, -- Horn of Winter
		{ id = 53292, border = "utility" }, -- Hunting Party
		{ id = 55610, border = "utility" }, -- Improved Icy Talons
		{ id = 24907, border = "utility" }, -- Leader of the Pack
		{ id = 48469, border = "utility" }, -- Mark of the Wild
		{ id = 48336, border = "utility" }, -- Moonkin Aura
		{ id = 48161, border = "utility" }, -- Power Word: Fortitude
		{ id = 10060, border = "utility", duration = true }, -- Power Infusion
		{ id = 48074, border = "utility" }, -- Prayer of Spirit
		{ id = 54043, border = "utility" }, -- Retribution Aura
		{ id = 48169, border = "utility" }, -- Shadow Protection
		{ id = 58643, border = "utility" }, -- Strength of Earth
		{ id = 57934, border = "utility", duration = true }, -- Tricks of the Trade (damage buff)
		{ id = 19506, border = "utility" }, -- Trueshot Aura
	},
	procs = {
		{ id = 72412, border = "procs", duration = true }, -- Ashen Verdict Ring (Frostforged Champion)
		{ id = 59629, border = "procs", duration = true }, -- Black Heart (Tidal Fury proc)
		{ id = 67703, border = "procs", duration = true, ranks = { 67703, 67708, 67772, 67773 } }, -- Death's Choice Paragon
		{ id = 71485, border = "procs", duration = true, ranks = { 71485, 71486, 71491, 71556, 71558, 71559 } }, -- Deathbringer's Will
		{ id = 71601, border = "procs", duration = true, ranks = { 71601, 71644 } }, -- Dislodged Foreign Object
		{ id = 60229, border = "procs", duration = true, ranks = { 60229, 60233, 60234, 60235 } }, -- Greatness
		{ id = 54758, border = "procs", duration = true }, -- Hyperspeed Accelerators
		{ id = 53762, border = "procs", duration = true }, -- Indestructible Potion
		{ id = 54861, border = "procs", duration = true }, -- Nitro Boosts
		{ id = 54757, border = "procs", duration = true }, -- Pyro Rocket (engineering)
		{ id = 53763, border = "procs", duration = true }, -- Protection Potion
		{ id = 53908, border = "procs", duration = true }, -- Potion of Speed
		{ id = 53909, border = "procs", duration = true }, -- Potion of Wild Magic
		{ id = 71564, border = "procs", duration = true }, -- Reign of the Dead (Deadly Precision)
		{ id = 71605, border = "procs", duration = true }, -- Reign of the Unliving (Siphoned Power)
		{ id = 67713, border = "procs", duration = true, stacks = true }, -- Reign of the Unliving (Mote of Flame)
		{ id = 75458, border = "procs", duration = true, ranks = { 75458, 75456, 71562 } }, -- Sharpened Twilight Scale
		{ id = 71401, border = "procs", duration = true, ranks = { 71401, 71541 } }, -- Whispering Fanged Skull
		{ id = 71905, border = "procs", duration = true, stacks = true }, -- Shadowmourne Soul Fragment
		{ id = 73422, border = "procs", duration = true }, -- Shadowmourne Chaos Bane
	},
	consume = {
		{ id = 53755, border = "consumables" }, -- Flask of the Frost Wyrm (aura 53755)
		{ id = 53758, border = "consumables" }, -- Flask of Stoneblood (aura 53758)
		{ id = 53760, border = "consumables" }, -- Flask of Endless Rage
		{ id = 54212, border = "consumables" }, -- Flask of Pure Mojo
		{ id = 60345, border = "consumables" }, -- Elixir of Armor Piercing (aura, not item)
		{ id = 60344, border = "consumables" }, -- Elixir of Expertise (aura, not item)
		{ id = 60346, border = "consumables" }, -- Elixir of Lightning Speed (aura, not item)
		{ id = 60343, border = "consumables" }, -- Elixir of Mighty Defense (aura, not item)
		{ id = 53751, border = "consumables" }, -- Elixir of Mighty Fortitude
		{ id = 53764, border = "consumables" }, -- Elixir of Mighty Mageblood
		{ id = 60347, border = "consumables" }, -- Elixir of Mighty Thoughts
		{ id = 57426, border = "consumables" }, -- Fish Feast (item use aura)
		{ id = 57341, border = "consumables" }, -- Firecracker Salmon
		{ id = 57357, border = "consumables" }, -- Hearty Rhino (item use aura)
		{ id = 57344, border = "consumables" }, -- Imperial Manta Steak (item use aura)
		{ id = 57326, border = "consumables" }, -- Tender Shoveltusk Steak (item use aura)
	},
	stacks = {
		{ id = 55078, border = "stacks", duration = true }, -- Blood Plague
		{ id = 51735, border = "stacks", duration = true }, -- Ebon Plague
		{ id = 8647, border = "stacks", duration = true, stacks = true, ranks = { 8649, 8650, 11197, 11198, 26866 } }, -- Expose Armor
		{ id = 770, border = "stacks", duration = true, ranks = { 778, 9749, 9907, 26993 } }, -- Faerie Fire
		{ id = 55095, border = "stacks", duration = true }, -- Frost Fever
		{ id = 48468, border = "stacks", duration = true }, -- Insect Swarm
		{ id = 55360, border = "stacks", duration = true, stacks = true }, -- Living Bomb
		{ id = 772, border = "stacks", duration = true, ranks = { 6546, 6547, 6548, 11572, 11573, 11574 } }, -- Rend
		{ id = 32389, border = "stacks", stacks = true }, -- Shadow Embrace
		{ id = 15258, border = "stacks", stacks = true }, -- Shadow Weaving (verify on target vs self)
		{ id = 7386, border = "stacks", duration = true, stacks = true, ranks = { 7405, 8380, 11596, 11597, 25225 } }, -- Sunder Armor
	},
	enchants = {
		{ id = 59620, border = "buffs_enchants", duration = true }, -- Berserking (Enchant proc)
		{ id = 59626, border = "buffs_enchants", duration = true }, -- Black Magic
		{ id = 51994, border = "buffs_enchants", duration = true }, -- Earthliving
		{ id = 42976, border = "buffs_enchants", duration = true }, -- Executioner (proc aura)
		{ id = 58790, border = "buffs_enchants", duration = true }, -- Flametongue Weapon
		{ id = 28093, border = "buffs_enchants", duration = true }, -- Mongoose (Lightning Speed proc)
		{ id = 58804, border = "buffs_enchants", duration = true }, -- Windfury Weapon
	},
}
