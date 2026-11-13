-- Simulates a 5-player dungeon with several K-Maxing clients sharing one
-- party channel, and checks that the steal banner names whoever takes #1,
-- straight from the damage meter, even though the meter hides every name in
-- combat on Forever (the banner hands the hidden name to the game to draw).
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
world:SetTop("Outsider")
world:Run(3)
t.Check(Rig.StolenText(kain) == "Outsider has stolen your Balenciaga", "a player without K-Maxing is named too")

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
t.Finish()
