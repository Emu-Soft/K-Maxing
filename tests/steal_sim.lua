-- Simulates a 5-player dungeon with several K-Maxing clients sharing one
-- party channel, and checks that the steal banner names the thief even when
-- the damage meter hides every name (as it does in combat on Forever).
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

-- 1. Kain takes #1, then Emu (also running K-Maxing) takes it.
world:SetTop("Kain")
world:Run(2)
t.Check(Rig.StolenText(kain) == nil, "no steal banner while Kain holds #1")
world:SetTop("Emu")
world:Run(3)
t.Check(Rig.StolenText(kain) == "Emu has stolen your Balenciaga", "Kain sees Emu named as the thief")

-- 2. Kain takes it back, then loses it to someone without K-Maxing.
world:ClearTexts()
world:SetTop("Kain")
world:Run(3)
t.Check(Rig.StolenText(emu) == "Kain has stolen your Balenciaga", "Emu sees Kain named as the thief")
world:SetTop("nobody")
world:Run(3)
t.Check(Rig.StolenText(kain) == nil, "no steal banner when the new #1 doesn't run K-Maxing")

-- 3. An old claim must not name a thief later on.
world:ClearTexts()
world:SetTop("Emu")
world:Run(1)
world:SetTop("Kain")
world:Run(2)
world:SetTop("nobody")
world:Run(3)
t.Check(Rig.StolenText(kain) == nil, "a claim made before Kain retook #1 is ignored")

-- 4. Holding #1 sends one message, not one per poll.
local before = #kain.sent
world:SetTop("Kain")
world:Run(10)
t.Check(#kain.sent - before == 1, "one claim message per time Kain takes #1")

t.Check(#world.errors == 0, "no Lua errors" .. (world.errors[1] and (": " .. world.errors[1]) or ""))
t.Finish()
