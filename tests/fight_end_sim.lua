-- Checks the timer's colour when #1 ends: green when the fight ends with
-- you still #1, red when someone passes you (even just before the fight
-- ends), and white again on the next pull.
--
--   lua5.1 tests/fight_end_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

local function Is(color, r, g, b)
	return color ~= nil and color[1] == r and color[2] == g and color[3] == b
end
local GREEN, RED, WHITE = { 0.2, 1.0, 0.2 }, { 1.0, 0.2, 0.2 }, { 1, 1, 1 }
local function Named(color)
	if Is(color, unpack(GREEN)) then return "green" end
	if Is(color, unpack(RED)) then return "red" end
	if Is(color, unpack(WHITE)) then return "white" end
	return "other"
end

local function Party()
	local world = Rig.NewWorld(CORE)
	local kain = world:AddClient("Kain")
	world:AddClient("Emu")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	return world, kain
end

do
	local world, kain = Party()
	t.Check(Named(Rig.TimerColor(kain)) == "white", "the timer is white while Kain is #1")
	world:SetCombat(false)
	t.Check(Named(Rig.TimerColor(kain)) == "green", "the fight ends with Kain #1: the timer turns green")
	world:Run(5)
	t.Check(Named(Rig.TimerColor(kain)) == "green", "it stays green as it fades (not red a moment later)")
	t.Check(Rig.StolenText(kain) == nil, "no steal banner")

	world:SetCombat(true)
	world:Run(2)
	t.Check(Named(Rig.TimerColor(kain)) == "white", "the next pull: white again")
	t.Check(#world.errors == 0, "no Lua errors" .. (world.errors[1] and (": " .. world.errors[1]) or ""))
end

do
	local world, kain = Party()
	world:SetTop("Emu")
	world:Run(3)
	world:SetCombat(false)
	world:Run(3)
	t.Check(Named(Rig.TimerColor(kain)) == "red", "Emu takes #1 mid-fight: red, and the fight ending keeps it red")
end

do
	-- Emu passes Kain half a second before the fight ends: Kain wasn't maxing.
	local world, kain = Party()
	world:SetTop("Emu")
	world:Run(0.5)
	world:SetCombat(false)
	world:Run(3)
	t.Check(Named(Rig.TimerColor(kain)) == "red", "Emu passes Kain just before the fight ends: red, not green")
	t.Check(#world.errors == 0, "no Lua errors" .. (world.errors[1] and (": " .. world.errors[1]) or ""))
end

do
	-- /kmax lose: pretending to be passed isn't maxing either.
	local world, kain = Party()
	world:Slash(kain, "KMAX", "lose Emu")
	world:Run(3)
	world:SetCombat(false)
	world:Run(3)
	t.Check(Named(Rig.TimerColor(kain)) == "red", "/kmax lose then the fight ends: red")
end

t.Finish()
