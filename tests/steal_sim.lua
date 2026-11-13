-- Simulates a 5-player dungeon with several K-Maxing clients sharing one
-- party channel, and checks that the steal banner names a K-Maxing user who
-- takes #1, straight from the damage meter, even though the meter hides every
-- name in combat on Forever (the banner hands the hidden name to the game to
-- draw, and the meter's class column says whether they run K-Maxing).
--
--   lua5.1 tests/steal_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

local world = Rig.NewWorld(CORE)
local kain = world:AddClient("Kain")
local emu = world:AddClient("Emu")
world:AddClient("Other")
world:SetCombat(true)

-- 1. Kain takes #1, then Emu takes it.
world:SetTop("Kain")
world:Run(2)
t.Check(Rig.StolenText(kain) == nil, "no steal banner while Kain holds #1")
world:SetTop("Emu")
world:Run(3)
t.Check(Rig.StolenText(kain) == "Emu has stolen your Balenciaga", "Kain sees Emu named, without the realm")

-- 2. Kain takes it back.
world:ClearTexts()
world:SetTop("Kain")
world:Run(3)
t.Check(Rig.StolenText(emu) == "Kain has stolen your Balenciaga", "Emu sees Kain named")

-- 3. Someone without K-Maxing takes it.
world:ClearTexts()
world:SetTop("Outsider")
world:Run(3)
t.Check(Rig.StolenText(kain) == nil, "no banner for a player without K-Maxing")

-- 4. Combat ends while Kain holds #1: no steal.
world:ClearTexts()
world:SetTop("Kain")
world:Run(3)
world:SetCombat(false)
world:Run(3)
t.Check(Rig.StolenText(kain) == nil, "no steal banner when combat just ends")

-- 5. Holding #1 sends one message, not one per poll.
world:SetCombat(true)
local before = #kain.sent
world:Run(10)
t.Check(#kain.sent - before == 1, "one claim message per time Kain takes #1")

t.Check(#world.errors == 0, "no Lua errors" .. (world.errors[1] and (": " .. world.errors[1]) or ""))

-- 6. A player without K-Maxing has the same class as Emu, so the class can't
-- tell them apart: only Emu's own claim names Emu.
do
	local w = Rig.NewWorld(CORE)
	local k = w:AddClient("Kain")
	w:AddClient("Emu", "PRIEST")
	w:AddPlayer("Twin", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("Twin")
	w:Run(3)
	t.Check(Rig.StolenText(k) == nil, "same class: no banner for the player without K-Maxing")
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("Emu")
	w:Run(3)
	t.Check(Rig.StolenText(k) == "Emu has stolen your Balenciaga", "same class: Emu's claim names Emu")
	t.Check(#w.errors == 0, "same class: no Lua errors" .. (w.errors[1] and (": " .. w.errors[1]) or ""))
end

-- 7. A K-Maxing user on an older version never says hello, so isn't named.
do
	local w = Rig.NewWorld(CORE)
	local k = w:AddClient("Kain")
	w:AddPlayer("OldEmu", "MAGE")
	w:AddPlayer("Healer", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("OldEmu")
	w:Run(3)
	t.Check(Rig.StolenText(k) == nil, "unknown user: no banner")
end

t.Finish()
