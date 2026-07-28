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
				{ id = 29131, border = "spells", duration = true, spellID = 2687, ranks = { 2687 } }, -- Bloodrage (aura; cast 2687)
				{ id = 18499, border = "spells", duration = true }, -- Berserker Rage
				{ id = 55694, border = "spells", duration = true }, -- Enraged Regeneration
				{ id = 12976, border = "spells", duration = true }, -- Last Stand (aura; cast 12975)
				{ id = 1719, border = "spells", duration = true }, -- Recklessness
				{ id = 20230, border = "spells", duration = true }, -- Retaliation
				{ id = 2565, border = "spells", duration = true }, -- Shield Block
				{ id = 871, border = "spells", duration = true }, -- Shield Wall
				{ id = 23920, border = "spells", duration = true }, -- Spell Reflection
				{ id = 12328, border = "spells", duration = true }, -- Sweeping Strikes
			},
			PALADIN = {
				{ id = 31884, border = "spells", duration = true }, -- Avenging Wrath
				{ id = 31821, border = "spells", duration = true }, -- Aura Mastery
				{ id = 20216, border = "spells", duration = true }, -- Divine Favor
				{ id = 54428, border = "spells", duration = true }, -- Divine Plea
				{ id = 498, border = "spells", duration = true }, -- Divine Protection
				{ id = 642, border = "spells", duration = true }, -- Divine Shield
				{ id = 1044, border = "spells", duration = true }, -- Hand of Freedom
				{ id = 1022, border = "spells", duration = true, ranks = { 1022, 5599, 10278 } }, -- Hand of Protection
				{ id = 1038, border = "spells", duration = true }, -- Hand of Salvation
				{ id = 48952, border = "spells", duration = true, ranks = { 48951, 48952 } }, -- Holy Shield
				{ id = 53601, border = "spells", duration = true }, -- Sacred Shield
				{ id = 57318, border = "spells", duration = true }, -- Sanctified Wrath
			},
			HUNTER = {
				{ id = 19574, border = "spells", duration = true }, -- Bestial Wrath
				{ id = 34471, border = "spells", duration = true }, -- The Beast Within
				{ id = 19263, border = "spells", duration = true }, -- Deterrence
				{ id = 54216, border = "spells", duration = true }, -- Master's Call
				{ id = 3045, border = "spells", duration = true }, -- Rapid Fire
				{ id = 23989, border = "spells", duration = true }, -- Readiness
			},
			ROGUE = {
				{ id = 13750, border = "spells", duration = true }, -- Adrenaline Rush
				{ id = 13877, border = "spells", duration = true }, -- Blade Flurry
				{ id = 31224, border = "spells", duration = true }, -- Cloak of Shadows
				{ id = 5277, border = "spells", duration = true, ranks = { 5277, 26669 } }, -- Evasion
				{ id = 51690, border = "spells", duration = true }, -- Killing Spree
				{ id = 51713, border = "spells", duration = true }, -- Shadow Dance
				{ id = 36563, border = "spells", duration = true, spellID = 36554 }, -- Shadowstep (aura; cast 36554)
				{ id = 5171, border = "spells", duration = true }, -- Slice and Dice
				{ id = 11305, border = "spells", duration = true }, -- Sprint
				{ id = 1856, border = "spells", duration = true, ranks = { 1856, 1857, 26889 } }, -- Vanish
			},
			PRIEST = {
				{ id = 47585, border = "spells", duration = true }, -- Dispersion
				{ id = 64901, border = "spells", duration = true }, -- Hymn of Hope
				{ id = 14751, border = "spells", duration = true }, -- Inner Focus
				{ id = 15286, border = "spells", duration = true }, -- Vampiric Embrace
			},
			DEATHKNIGHT = {
				{ id = 48707, border = "spells", duration = true }, -- Anti-Magic Shell
				{ id = 49222, border = "spells", duration = true, stacks = true }, -- Bone Shield
				{ id = 45529, border = "spells", duration = true }, -- Blood Tap
				{ id = 49028, border = "spells", duration = true }, -- Dancing Rune Weapon
				{ id = 47568, border = "spells", duration = true }, -- Empower Rune Weapon
				{ id = 49206, border = "spells", duration = true }, -- Summon Gargoyle
				{ id = 48792, border = "spells", duration = true }, -- Icebound Fortitude
				{ id = 49039, border = "spells", duration = true }, -- Lichborne
				{ id = 51271, border = "spells", duration = true }, -- Unbreakable Armor
				{ id = 55233, border = "spells", duration = true }, -- Vampiric Blood
			},
			SHAMAN = {
				{ id = 16166, border = "spells", duration = true }, -- Elemental Mastery
				{ id = 51533, border = "spells", duration = true }, -- Feral Spirit
				{ id = 16188, border = "spells", duration = true }, -- Nature's Swiftness
				{ id = 30823, border = "spells", duration = true }, -- Shamanistic Rage
				{ id = 55198, border = "spells", duration = true }, -- Tidal Force
			},
			MAGE = {
				{ id = 12042, border = "spells", duration = true }, -- Arcane Power
				{ id = 11129, border = "spells", duration = true }, -- Combustion
				{ id = 12472, border = "spells", duration = true }, -- Icy Veins
				{ id = 45438, border = "spells", duration = true }, -- Ice Block
				{ id = 66, border = "spells", duration = true }, -- Invisibility
				{ id = 55342, border = "spells", duration = true }, -- Mirror Image
				{ id = 12043, border = "spells", duration = true }, -- Presence of Mind
			},
			WARLOCK = {
				{ id = 47193, border = "spells", duration = true }, -- Demonic Empowerment
				{ id = 18708, border = "spells", duration = true }, -- Fel Domination
				{ id = 59672, border = "spells", duration = true }, -- Metamorphosis
				{ id = 19028, border = "spells", duration = true }, -- Soul Link
			},
			DRUID = {
				{ id = 22812, border = "spells", duration = true }, -- Barkskin
				{ id = 50334, border = "spells", duration = true }, -- Berserk
				{ id = 5229, border = "spells", duration = true }, -- Enrage
				{ id = 22842, border = "spells", duration = true }, -- Frenzied Regeneration
				{ id = 29166, border = "spells", duration = true }, -- Innervate
				{ id = 53312, border = "spells", duration = true }, -- Nature's Grasp
				{ id = 53201, border = "spells", duration = true }, -- Starfall
				{ id = 61336, border = "spells", duration = true }, -- Survival Instincts
				{ id = 50213, border = "spells", duration = true }, -- Tiger's Fury
			},
		},
		passives = {
			WARRIOR = {
				{ id = 46916, border = "procs" }, -- Blood Surge
				{ id = 12970, border = "procs", duration = true, ranks = { 12966, 12967, 12968, 12969 } }, -- Flurry
				{ id = 52437, border = "procs" }, -- Sudden Death
				{ id = 50227, border = "procs" }, -- Sword and Board
				{ id = 60503, border = "procs" }, -- Taste for Blood
				{ id = 57522, border = "procs", duration = true, ranks = { 12880, 14202, 14203, 14204, 14205 } }, -- Enrage
			},
			PALADIN = {
				{ id = 54149, border = "procs" }, -- Infusion of Light
				{ id = 53657, border = "procs", duration = true }, -- Judgements of the Pure
				{ id = 66922, border = "procs", duration = true }, -- Sacred Shield (Flash of Light crit)
				{ id = 59578, border = "procs" }, -- The Art of War
			},
			HUNTER = {
				{ id = 53220, border = "procs", duration = true }, -- Improved Steady Shot
				{ id = 56453, border = "procs" }, -- Lock and Load
				{ id = 35098, border = "procs", duration = true }, -- Rapid Killing
				{ id = 64420, border = "procs", duration = true, ranks = { 64418, 64419, 64420 } }, -- Sniper Training
				{ id = 34720, border = "procs" }, -- Thrill of the Hunt
			},
			ROGUE = {
				{ id = 63848, border = "procs", duration = true }, -- Hunger For Blood
				{ id = 31665, border = "procs", duration = true }, -- Master of Subtlety
				{ id = 58427, border = "procs", duration = true }, -- Overkill
			},
			PRIEST = {
				{ id = 52893, border = "procs", duration = true }, -- Borrowed Time
				{ id = 34754, border = "procs", duration = true }, -- Holy Concentration
				{ id = 47755, border = "procs", duration = true }, -- Improved Spirit Tap
				{ id = 63944, border = "procs", duration = true }, -- Renewed Hope
				{ id = 63734, border = "procs", duration = true, stacks = true, ranks = { 63731, 63735, 63734 } }, -- Serendipity
				{ id = 33151, border = "procs" }, -- Surge of Light
			},
			DEATHKNIGHT = {
				{ id = 59052, border = "procs" }, -- Freezing Fog (Rime)
				{ id = 51124, border = "procs" }, -- Killing Machine
				{ id = 50421, border = "procs", duration = true, stacks = true }, -- Scent of Blood
				{ id = 81340, border = "procs" }, -- Sudden Doom
			},
			SHAMAN = {
				{ id = 16246, border = "procs" }, -- Clearcasting
				{ id = 51466, border = "procs", duration = true }, -- Elemental Oath
				{ id = 53804, border = "procs" }, -- Lightning Overload
				{ id = 53817, border = "procs", stacks = true }, -- Maelstrom Weapon
				{ id = 53390, border = "procs", stacks = true }, -- Tidal Waves
			},
			MAGE = {
				{ id = 57761, border = "procs", stacks = true }, -- Brain Freeze
				{ id = 44450, border = "procs", duration = true }, -- Burnout
				{ id = 12536, border = "procs" }, -- Clearcasting
				{ id = 44544, border = "procs", stacks = true }, -- Fingers of Frost
				{ id = 48108, border = "procs" }, -- Hot Streak
				{ id = 28682, border = "procs", duration = true }, -- Combustion (crit proc)
				{ id = 44401, border = "procs", stacks = true }, -- Missile Barrage
				{ id = 55080, border = "procs" }, -- Shattered Barrier
			},
			WARLOCK = {
				{ id = 34936, border = "procs" }, -- Backlash
				{ id = 63167, border = "procs", ranks = { 63167, 64343, 71162, 71165 } }, -- Decimation
				{ id = 64371, border = "procs", duration = true }, -- Eradication
				{ id = 47283, border = "procs" }, -- Empowered Imp
				{ id = 47258, border = "procs", stacks = true }, -- Molten Core
				{ id = 17941, border = "procs" }, -- Shadow Trance (Nightfall)
			},
			DRUID = {
				{ id = 48518, border = "procs", duration = true }, -- Eclipse (Lunar)
				{ id = 48517, border = "procs", duration = true }, -- Eclipse (Solar)
				{ id = 16886, border = "procs", duration = true }, -- Nature's Grace
				{ id = 16870, border = "procs" }, -- Omen of Clarity
				{ id = 62606, border = "procs", duration = true }, -- Savage Defense
			},
		},
	},
	buffs = {
		{ id = 53138, border = "utility" }, -- Abomination's Might
		{ id = 48932, border = "utility", lowTime = true, ranks = { 48932, 48933, 48934 } }, -- Blessing of Might
		{ id = 20217, border = "utility", lowTime = true, ranks = { 20217, 25898 } }, -- Blessing of Kings
		{ id = 67480, border = "utility", lowTime = true, ranks = { 20911, 25899, 67480 } }, -- Blessing of Sanctuary
		{ id = 48938, border = "utility", lowTime = true, ranks = { 48936, 48938 } }, -- Blessing of Wisdom
		{ id = 2825, border = "utility", duration = true }, -- Bloodlust
		{ id = 47436, border = "utility", lowTime = true, ranks = { 47436, 47437 } }, -- Battle Shout
		{ id = 47440, border = "utility", lowTime = true, ranks = { 47440, 47441 } }, -- Commanding Shout
		{ id = 64205, border = "utility", duration = true }, -- Divine Sacrifice
		{ id = 59542, border = "utility", duration = true, ranks = { 28880, 59542, 59543, 59544, 59545, 59546, 59547, 59548 } }, -- Gift of the Naaru (Draenei racial HoT)
		-- Paladin auras (passive, no expiry — uncomment to track):
		-- { id = 48942, border = "utility" }, -- Devotion Aura
		-- { id = 54043, border = "utility" }, -- Retribution Aura
		-- { id = 19746, border = "utility" }, -- Concentration Aura
		-- { id = 48943, border = "utility" }, -- Shadow Resistance Aura
		-- { id = 48945, border = "utility" }, -- Frost Resistance Aura
		-- { id = 48947, border = "utility" }, -- Fire Resistance Aura
		-- { id = 32223, border = "utility" }, -- Crusader Aura
		{ id = 32182, border = "utility", duration = true }, -- Heroism
		{ id = 70867, border = "utility", duration = true }, -- Essence of the Blood Queen (ICC)
		{ id = 57330, border = "utility", lowTime = true }, -- Horn of Winter
		-- { id = 53292, border = "utility" }, -- Hunting Party
		-- { id = 55610, border = "utility" }, -- Improved Icy Talons
		-- { id = 24907, border = "utility" }, -- Leader of the Pack
		{ id = 48469, border = "utility", lowTime = true }, -- Mark of the Wild
		-- { id = 48336, border = "utility" }, -- Moonkin Aura
		{ id = 48161, border = "utility", lowTime = true }, -- Power Word: Fortitude
		{ id = 10060, border = "utility", duration = true }, -- Power Infusion
		{ id = 48074, border = "utility", lowTime = true }, -- Prayer of Spirit
		{ id = 48169, border = "utility", lowTime = true }, -- Shadow Protection
		-- { id = 58643, border = "utility" }, -- Strength of Earth
		{ id = 57934, border = "utility", duration = true }, -- Tricks of the Trade (damage buff)
		-- { id = 19506, border = "utility" }, -- Trueshot Aura (passive raid buff)
	},
	procs = {
		{ id = 72412, border = "procs", duration = true }, -- Ashen Verdict Ring (Frostforged Champion)
		{ id = 59629, border = "procs", duration = true }, -- Black Heart (Tidal Fury proc)
		{ id = 67703, border = "procs", duration = true, ranks = { 67703, 67708, 67772, 67773 } }, -- Death's Choice Paragon
		{ id = 71485, border = "procs", duration = true, ranks = {
			71484, 71485, 71486, 71487, 71490, 71491, 71492, -- Normal
			71556, 71557, 71558, 71559, 71560, 71561, -- Heroic
		} }, -- Deathbringer's Will (30s proc, 105s ICD)
		-- Surging Power stacks (71600/71643) + Surge of Power driver (71601/71644)
		{ id = 71600, border = "procs", duration = true, stacks = true, ranks = { 71600, 71643, 71601, 71644 } }, -- Dislodged Foreign Object
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
		{ id = 53755, border = "consumables", lowTime = true }, -- Flask of the Frost Wyrm (aura 53755)
		{ id = 53758, border = "consumables", lowTime = true }, -- Flask of Stoneblood (aura 53758)
		{ id = 53760, border = "consumables", lowTime = true }, -- Flask of Endless Rage
		{ id = 54212, border = "consumables", lowTime = true }, -- Flask of Pure Mojo
		{ id = 60345, border = "consumables", lowTime = true }, -- Elixir of Armor Piercing (aura, not item)
		{ id = 60344, border = "consumables", lowTime = true }, -- Elixir of Expertise (aura, not item)
		{ id = 60346, border = "consumables", lowTime = true }, -- Elixir of Lightning Speed (aura, not item)
		{ id = 60343, border = "consumables", lowTime = true }, -- Elixir of Mighty Defense (aura, not item)
		{ id = 53751, border = "consumables", lowTime = true }, -- Elixir of Mighty Fortitude
		{ id = 53764, border = "consumables", lowTime = true }, -- Elixir of Mighty Mageblood
		{ id = 60347, border = "consumables", lowTime = true }, -- Elixir of Mighty Thoughts
		{ id = 57426, border = "consumables", lowTime = true }, -- Fish Feast (item use aura)
		{ id = 57341, border = "consumables", lowTime = true }, -- Firecracker Salmon
		{ id = 57357, border = "consumables", lowTime = true }, -- Hearty Rhino (item use aura)
		{ id = 57344, border = "consumables", lowTime = true }, -- Imperial Manta Steak (item use aura)
		{ id = 57326, border = "consumables", lowTime = true }, -- Tender Shoveltusk Steak (item use aura)
	},
	stacks = {
		-- Death Knight
		{ id = 55078, border = "stacks", duration = true }, -- Blood Plague
		{ id = 51735, border = "stacks", duration = true }, -- Ebon Plague
		{ id = 55095, border = "stacks", duration = true }, -- Frost Fever
		{ id = 45524, border = "stacks", duration = true }, -- Chains of Ice
		-- Druid
		{ id = 770, border = "stacks", duration = true, ranks = { 778, 9749, 9907, 26993 } }, -- Faerie Fire
		{ id = 48468, border = "stacks", duration = true }, -- Insect Swarm
		{ id = 48568, border = "stacks", duration = true, stacks = true }, -- Lacerate
		{ id = 48463, border = "stacks", duration = true }, -- Moonfire
		{ id = 48574, border = "stacks", duration = true }, -- Rake
		{ id = 49800, border = "stacks", duration = true }, -- Rip
		-- Hunter
		{ id = 60053, border = "stacks", duration = true, ranks = { 53301, 53302, 53303, 60053 } }, -- Explosive Shot
		{ id = 53338, border = "stacks", duration = true }, -- Hunter's Mark
		{ id = 49001, border = "stacks", duration = true }, -- Serpent Sting
		{ id = 3034, border = "stacks", duration = true }, -- Viper Sting
		-- Mage
		{ id = 36032, border = "stacks", duration = true, stacks = true }, -- Arcane Blast (debuff)
		{ id = 12654, border = "stacks", duration = true }, -- Ignite
		{ id = 55360, border = "stacks", duration = true, stacks = true }, -- Living Bomb
		{ id = 22959, border = "stacks", duration = true }, -- Fire Vulnerability (Scorch)
		-- Paladin
		{ id = 53742, border = "stacks", duration = true, stacks = true }, -- Blood Corruption
		{ id = 21183, border = "stacks", duration = true }, -- Heart of the Crusader
		{ id = 31803, border = "stacks", duration = true, stacks = true }, -- Holy Vengeance
		{ id = 20184, border = "stacks", duration = true }, -- Judgement of Justice
		{ id = 20185, border = "stacks", duration = true }, -- Judgement of Light
		{ id = 20186, border = "stacks", duration = true }, -- Judgement of Wisdom
		{ id = 68055, border = "stacks", duration = true }, -- Judgements of the Just
		-- Priest
		{ id = 48300, border = "stacks", duration = true }, -- Devouring Plague
		{ id = 15258, border = "stacks", stacks = true }, -- Shadow Weaving
		{ id = 48125, border = "stacks", duration = true }, -- Shadow Word: Pain
		{ id = 48160, border = "stacks", duration = true }, -- Vampiric Touch
		-- Rogue
		{ id = 2818, border = "stacks", duration = true, stacks = true }, -- Deadly Poison
		{ id = 8647, border = "stacks", duration = true, stacks = true, ranks = { 8649, 8650, 11197, 11198, 26866 } }, -- Expose Armor
		{ id = 703, border = "stacks", duration = true }, -- Garrote
		{ id = 48672, border = "stacks", duration = true, ranks = { 1943, 8639, 8640, 11273, 11274, 11275, 26867, 48671, 48672 } }, -- Rupture
		-- Shaman
		{ id = 49233, border = "stacks", duration = true, ranks = { 8050, 8052, 8053, 10448, 29228, 25457, 49232, 49233 } }, -- Flame Shock
		{ id = 17364, border = "stacks", duration = true }, -- Stormstrike
		-- Warlock
		{ id = 47813, border = "stacks", duration = true }, -- Corruption
		{ id = 47864, border = "stacks", duration = true }, -- Curse of Agony
		{ id = 47867, border = "stacks", duration = true }, -- Curse of Doom
		{ id = 47865, border = "stacks", duration = true }, -- Curse of the Elements
		{ id = 59164, border = "stacks", duration = true }, -- Haunt
		{ id = 47811, border = "stacks", duration = true }, -- Immolate
		{ id = 47836, border = "stacks", duration = true }, -- Seed of Corruption
		{ id = 32389, border = "stacks", stacks = true }, -- Shadow Embrace
		{ id = 47843, border = "stacks", duration = true }, -- Unstable Affliction
		-- Warrior
		{ id = 12721, border = "stacks", duration = true }, -- Deep Wounds
		{ id = 47437, border = "stacks", duration = true, ranks = { 1160, 6190, 11554, 11555, 11556, 25202, 25203, 47437 } }, -- Demoralizing Shout
		{ id = 1715, border = "stacks", duration = true }, -- Hamstring
		{ id = 772, border = "stacks", duration = true, ranks = { 6546, 6547, 6548, 11572, 11573, 11574 } }, -- Rend
        { id = 7386,  border = "stacks", duration = true, stacks = true,                                                         ranks = { 7405, 8380, 11596, 11597, 25225 } }, -- Sunder Armor
        { id = 12323, border = "stacks", duration = true }, -- Piercing Howl
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
