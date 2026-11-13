-- Simulates Blizzard's dungeon lockdown on WoW: Forever: in combat the meter
-- hides names, and addon messages can be refused (a lockdown result code, or
-- a Lua error), arrive late, or come from a hidden sender. Checks that the
-- #1 display still works and that the steal banner names the thief as soon
-- as a message can get through, and never names the wrong player.
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

print("-- messages flow in combat")
do
	local world, kain, emu, inCombat = Pull({}, "Emu")
	t.Check(inCombat == EMU_STOLE, "open: Kain sees Emu named during the fight")
	t.Check(kain.music == 1 and emu.music == 1, "open: both get the #1 music")
	NoErrors(world, "open")
end

print("-- lockdown: sends refused with a lockdown result")
do
	local world, kain, emu, inCombat = Pull({ lockdown = InCombat }, "Emu")
	t.Check(emu.music == 1, "refused: Emu still gets the #1 music")
	t.Check(inCombat == nil, "refused: no name during the fight (nothing can get through)")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "refused: Kain sees Emu named once combat ends")
	NoErrors(world, "refused")
end

print("-- lockdown: sends raise a Lua error")
do
	local world, kain, emu = Pull({ lockdown = InCombat, lockdownMode = "error" }, "Emu")
	t.Check(emu.music == 1, "error: Emu still gets the #1 music")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "error: Kain sees Emu named once combat ends")
	NoErrors(world, "error")
end

print("-- lockdown, and names stay hidden after combat too")
do
	local world, kain = Pull({ lockdown = InCombat, secretOutOfCombat = true }, "Emu")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "hidden after combat: Kain sees Emu named once combat ends")
	NoErrors(world, "hidden after combat")
end

print("-- lockdown: Kain takes #1 back before combat ends")
do
	local world, kain, emu = Pull({ lockdown = InCombat }, "Emu", function(world)
		world:SetTop("Kain")
		world:Run(3)
	end)
	t.Check(Rig.StolenText(kain) == nil, "retaken: Kain sees no late banner about Emu")
	t.Check(Rig.StolenText(emu) == "Kain has stolen your Balenciaga", "retaken: Emu sees Kain named once combat ends")
	NoErrors(world, "retaken")
end

print("-- lockdown: the new #1 doesn't run K-Maxing")
do
	local world, kain = Pull({ lockdown = InCombat }, "nobody")
	t.Check(Rig.StolenText(kain) == nil, "outsider: no banner")
	NoErrors(world, "outsider")
	-- Emu takes #1 from the outsider later in the same fight: Emu didn't take it from Kain.
	world, kain = Pull({ lockdown = InCombat }, "nobody", function(world)
		world:Run(3)
		world:SetTop("Emu")
		world:Run(3)
	end)
	t.Check(Rig.StolenText(kain) == nil, "outsider, then Emu: Kain's banner doesn't blame Emu")
	NoErrors(world, "outsider, then Emu")
end

print("-- messages arrive late")
do
	local world, kain = Pull({ delay = 0.3 }, "Emu")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "0.3s delay: Kain sees Emu named")
	NoErrors(world, "0.3s delay")
	world, kain = Pull({ delay = 2 }, "Emu")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "2s delay: Kain sees Emu named when the message lands")
	NoErrors(world, "2s delay")
	-- A claim that lands much later than the loss could be from someone who
	-- took #1 from a third player afterwards, so it isn't trusted.
	world, kain = Pull({ delay = 4 }, "Emu")
	t.Check(Rig.StolenText(kain) == nil, "4s delay: no banner (too late to be sure who took it)")
	NoErrors(world, "4s delay")
end

print("-- the sender's name is hidden")
do
	local world, kain, emu = Pull({ secretSender = true }, "Emu")
	t.Check(emu.music == 1, "hidden sender: Emu still gets the #1 music")
	t.Check(Rig.StolenText(kain) == nil, "hidden sender: no banner (the name can't be read)")
	NoErrors(world, "hidden sender")
end

print("-- the meter's row index is hidden")
do
	local world, kain, emu = Pull({ indexSecret = true }, "Emu")
	t.Check(kain.music == 1 and emu.music == 1, "hidden index: #1 still detected from row order")
	t.Check(Rig.StolenText(kain) == EMU_STOLE, "hidden index: Kain sees Emu named")
	NoErrors(world, "hidden index")
end

t.Finish()
