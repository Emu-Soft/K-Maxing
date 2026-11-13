-- Checks /kmax fake <name>: a pretend K-Maxing user for testing in game,
-- with nobody else in the group running K-Maxing.
--
--   lua5.1 tests/fake_user_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

local function InCombat(world) return world.combat end

-- Kain holds #1, a player without K-Maxing takes it, then combat ends.
local function Pull(options, fake)
	local world = Rig.NewWorld(CORE, options)
	local kain = world:AddClient("Kain") -- "Other" has no K-Maxing, so isn't a client
	if fake then world:Slash(kain, "KMAX", fake) end
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:SetTop("Other")
	world:Run(3)
	local inCombatText = Rig.StolenText(kain)
	world:Run(5)
	world:SetCombat(false)
	world:Run(3)
	return world, kain, inCombatText
end

local function NoErrors(world, label)
	t.Check(#world.errors == 0, label .. ": no Lua errors" .. (world.errors[1] and (" (" .. world.errors[1] .. ")") or ""))
end

local FAKE_STOLE = "Emu has stolen your Balenciaga"

do
	local world, kain, inCombat = Pull({}, "fake Emu")
	t.Check(inCombat == FAKE_STOLE, "open: the fake user is named during the fight")
	NoErrors(world, "open")
end

do
	local world, kain, inCombat = Pull({ lockdown = InCombat }, "fake Emu")
	t.Check(inCombat == nil, "lockdown: nothing during the fight")
	t.Check(Rig.StolenText(kain) == FAKE_STOLE, "lockdown: the fake user is named once combat ends")
	NoErrors(world, "lockdown")
end

do
	local world, kain = Pull({}, nil)
	t.Check(Rig.StolenText(kain) == nil, "no fake user: no banner")
	NoErrors(world, "no fake user")
end

do
	local world = Rig.NewWorld(CORE, {})
	local kain = world:AddClient("Kain")
	world:Slash(kain, "KMAX", "fake Emu")
	world:Slash(kain, "KMAX", "fake off")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:SetTop("Other")
	world:Run(5)
	t.Check(Rig.StolenText(kain) == nil, "fake off: no banner")
	NoErrors(world, "fake off")
end

-- Someone else's client can't use FAKETOP to frame a player.
do
	local world = Rig.NewWorld(CORE, {})
	local kain = world:AddClient("Kain")
	local emu = world:AddClient("Emu")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:SetTop("Other")
	world:Run(2)
	emu.env.C_ChatInfo.SendAddonMessage("BALENCIAGA_PING", "FAKETOP:Other:0.0", "PARTY")
	world:Run(3)
	t.Check(Rig.StolenText(kain) == nil, "a FAKETOP from another player is ignored")
	NoErrors(world, "spoof")
end

t.Finish()
