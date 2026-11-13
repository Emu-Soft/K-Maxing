-- Simulates Blizzard's dungeon lockdown on WoW: Forever: in combat the meter
-- hides names, and addon messages can be refused (a lockdown result code, or
-- a Lua error), arrive late, or come from a hidden sender. Checks that the
-- #1 display still works, that the banner names a K-Maxing thief from the
-- meter during the fight (the class column says they run K-Maxing), and
-- that when the meter can't settle it, a K-Maxing claim names them if it
-- gets through before the fight ends, never naming the wrong player.
--
--   lua5.1 tests/lockdown_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

local function InCombat(world) return world.combat end

-- A pull: Kain holds #1, `thief` takes it, the fight goes on, then combat ends.
local function Pull(options, thief, after)
	local world = Rig.NewWorld(CORE, options)
	local kain = world:AddClient("Kain")
	local emu = world:AddClient("Emu")
	world:AddClient("Other")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:SetTop(thief)
	world:Run(3)
	local inCombatText = Rig.StolenText(kain)
	if after then after(world) end
	world:Run(10)
	world:SetCombat(false)
	world:Run(3)
	return world, kain, emu, inCombatText
end

local function NoErrors(world, label)
	t.Check(#world.errors == 0, label .. ": no Lua errors" .. (world.errors[1] and (" (" .. world.errors[1] .. ")") or ""))
end

local EMU_STOLE = "Emu has stolen your Balenciaga"

print("-- the meter's hidden name goes straight on the banner")
for _, case in ipairs({
	{ "open", {} },
	{ "refused", { lockdown = InCombat } },
	{ "error", { lockdown = InCombat, lockdownMode = "error" } },
	{ "hidden index", { lockdown = InCombat, indexSecret = true } },
}) do
	local label, options = case[1], case[2]
	local world, kain, emu, inCombat = Pull(options, "Emu")
	t.Check(inCombat == EMU_STOLE, label .. ": Kain sees Emu named during the fight")
	t.Check(kain.music == 1 and emu.music == 1, label .. ": both get the #1 music")
	NoErrors(world, label)
end
do
	local world, kain = Pull({ lockdown = InCombat }, "Outsider")
	t.Check(Rig.StolenText(kain) == nil, "outsider: no banner")
	NoErrors(world, "outsider")
end
do
	-- Hidden senders: nobody can say hello, so nobody is known to run K-Maxing.
	local world, kain = Pull({ secretSender = true }, "Emu")
	t.Check(Rig.StolenText(kain) == nil, "hidden sender: no banner")
	NoErrors(world, "hidden sender")
end

print("-- the class can't settle it: a K-Maxing claim names the thief")
do
	local world, kain, _, inCombat = Pull({ lockdown = InCombat, secretClass = true }, "Emu")
	t.Check(inCombat == nil, "hidden class, lockdown: nothing during the fight")
	t.Check(Rig.StolenText(kain) == nil, "hidden class, lockdown: no banner after the fight either")
	NoErrors(world, "hidden class")
end

print("-- the meter gives no name: a K-Maxing claim names the thief")
local function NoNames(options)
	options.noNames = true
	return options
end
do
	local world, kain, _, inCombat = Pull(NoNames({}), "Emu")
	t.Check(inCombat == EMU_STOLE, "no names, open: Kain sees Emu named during the fight")
	NoErrors(world, "no names, open")
end
do
	local world, kain, _, inCombat = Pull(NoNames({ lockdown = InCombat }), "Emu")
	t.Check(inCombat == nil, "no names, refused: nothing during the fight (nothing can get through)")
	t.Check(Rig.StolenText(kain) == nil, "no names, refused: no banner after the fight either")
	NoErrors(world, "no names, refused")
end
do
	local world, kain, emu = Pull(NoNames({ lockdown = InCombat, lockdownMode = "error" }), "Emu")
	t.Check(emu.music == 1, "no names, error: Emu still gets the #1 music")
	t.Check(Rig.StolenText(kain) == nil, "no names, error: no banner after the fight either")
	NoErrors(world, "no names, error")
end
do
	-- The lockdown lifts mid-fight: the held-back claim gets out in time.
	local liftAt
	local world, kain, _, inCombat = Pull(NoNames({ lockdown = function(w) return w.combat and not (liftAt and w.now >= liftAt) end }), "Emu",
		function(w) liftAt = w.now + 2 end)
	t.Check(inCombat == nil, "no names, lockdown lifts mid-fight: nothing while it lasts")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "no names, lockdown lifts mid-fight: Kain sees Emu named once it lifts")
	NoErrors(world, "no names, lockdown lifts mid-fight")
end
do
	local world, kain, emu = Pull(NoNames({ lockdown = InCombat }), "Emu", function(world)
		world:SetTop("Kain")
		world:Run(3)
	end)
	t.Check(Rig.StolenText(kain) == nil, "no names, retaken: Kain sees no late banner about Emu")
	t.Check(Rig.StolenText(emu) == nil, "no names, retaken: no banner for Emu after the fight either")
	NoErrors(world, "no names, retaken")
end
do
	local world, kain = Pull(NoNames({ lockdown = InCombat }), "nobody")
	t.Check(Rig.StolenText(kain) == nil, "no names, outsider: no banner (nobody can say who it was)")
	NoErrors(world, "no names, outsider")
	-- Emu takes #1 from the outsider later in the same fight: Emu didn't take it from Kain.
	world, kain = Pull(NoNames({ lockdown = InCombat }), "nobody", function(world)
		world:Run(3)
		world:SetTop("Emu")
		world:Run(3)
	end)
	t.Check(Rig.StolenText(kain) == nil, "no names, outsider then Emu: Kain's banner doesn't blame Emu")
	NoErrors(world, "no names, outsider then Emu")
end
do
	local world, kain = Pull(NoNames({ delay = 2 }), "Emu")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "no names, 2s delay: Kain sees Emu named when the message lands")
	NoErrors(world, "no names, 2s delay")
	-- A claim that lands much later than the loss could be from someone who
	-- took #1 from a third player afterwards, so it isn't trusted.
	world, kain = Pull(NoNames({ delay = 4 }), "Emu")
	t.Check(Rig.StolenText(kain) == nil, "no names, 4s delay: no banner (too late to be sure who took it)")
	NoErrors(world, "no names, 4s delay")
end
do
	local world, kain = Pull(NoNames({ secretSender = true }), "Emu")
	t.Check(Rig.StolenText(kain) == nil, "no names, hidden sender: no banner (the claim can't be read)")
	NoErrors(world, "no names, hidden sender")
end

t.Finish()
