-- Checks the in-game test commands: /kmax fake <name> (a pretend K-Maxing
-- user) and /kmax lose (pretend someone passed you on the meter), with
-- nobody else in the group running K-Maxing. A fake user's claim is only
-- the backup for a meter row with no name, so most cases use noNames.
--
--   lua5.1 tests/commands_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

local function InCombat(world) return world.combat end

-- Kain holds #1, a player without K-Maxing takes it, then combat ends.
local function Pull(options, fake)
	if options.noNames == nil and not options.plainNames then options.noNames = true end
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
	local world = Rig.NewWorld(CORE, { noNames = true })
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
	local world = Rig.NewWorld(CORE, { noNames = true })
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

-- /kmax debug logs a held-back retry once, not every poll.
do
	local lines = 0
	local world = Rig.NewWorld(CORE, { lockdown = InCombat, noNames = true })
	local kain = world:AddClient("Kain")
	kain.env.print = function(text) if text:find("send FAKETOP") then lines = lines + 1 end end
	world:Slash(kain, "KMAX", "debug")
	world:Slash(kain, "KMAX", "fake Emu")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:SetTop("Other")
	world:Run(10)
	world:SetCombat(false)
	world:Run(2)
	t.Check(lines == 2, "debug: one line for the refusal, one for the send that got out (got " .. lines .. ")")
	t.Check(Rig.StolenText(kain) == FAKE_STOLE, "debug: the banner still shows")
	NoErrors(world, "debug")
end

-- The player who passes you has a readable name (or none at all) on the meter.
do
	local world, kain, inCombat = Pull({ plainNames = true }, "fake Emu")
	t.Check(inCombat == "Other has stolen your Balenciaga", "readable names: the meter's name wins over the fake user")
	NoErrors(world, "readable names")
	world, kain, inCombat = Pull({ noNames = true }, "fake Emu")
	t.Check(inCombat == FAKE_STOLE, "no names on the meter: the fake user is still named")
	NoErrors(world, "no names on the meter")
end

-- /kmax lose: solo, with only the commands.
local function SoloLose(options, fake, loseCommand)
	local world = Rig.NewWorld(CORE, options)
	local kain = world:AddClient("Kain")
	if fake then world:Slash(kain, "KMAX", fake) end
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:Slash(kain, "KMAX", loseCommand or "lose")
	world:Run(3)
	local inCombatText = Rig.StolenText(kain)
	world:SetCombat(false)
	world:Run(3)
	return world, kain, inCombatText
end

do
	local world, kain, inCombat = SoloLose({}, "fake Emu")
	t.Check(inCombat == FAKE_STOLE, "lose + fake: the fake user is named during the fight")
	NoErrors(world, "lose + fake")
end

do
	local world, kain, inCombat = SoloLose({ lockdown = InCombat }, "fake Emu")
	t.Check(inCombat == nil, "lose + fake, lockdown: nothing during the fight")
	t.Check(Rig.StolenText(kain) == FAKE_STOLE, "lose + fake, lockdown: the fake user is named once combat ends")
	NoErrors(world, "lose + fake, lockdown")
end

do
	local world, kain, inCombat = SoloLose({ solo = true }, "fake Emu")
	t.Check(inCombat == FAKE_STOLE, "lose + fake, not in a group: the fake user is named")
	NoErrors(world, "not in a group")
end

do
	local world, kain, inCombat = SoloLose({ lockdown = InCombat }, nil, "lose Bob")
	t.Check(inCombat == "Bob has stolen your Balenciaga", "lose Bob: Bob is named during the fight, even in lockdown")
	NoErrors(world, "lose Bob")
end

do
	local world, kain = SoloLose({}, nil)
	t.Check(Rig.StolenText(kain) == nil, "lose alone: no banner, just the fade-out")
	-- Combat ended, so the next fight reads the real meter again.
	world:SetCombat(true)
	world:Run(2)
	t.Check(kain.music == 2, "lose alone: the next fight is back to the real meter")
	NoErrors(world, "lose alone")
end

do
	local world = Rig.NewWorld(CORE, {})
	local kain = world:AddClient("Kain")
	world:SetCombat(true)
	world:SetTop("Kain")
	world:Run(2)
	world:Slash(kain, "KMAX", "lose")
	world:Run(1)
	world:Slash(kain, "KMAX", "lose off")
	world:Run(3)
	t.Check(kain.music == 1 and Rig.StolenText(kain) == nil, "lose off within the grace period: still #1")
	world:Slash(kain, "KMAX", "lose")
	world:Run(3)
	world:Slash(kain, "KMAX", "lose off")
	world:Run(2)
	t.Check(kain.music == 2, "lose off after losing: #1 comes back")
	NoErrors(world, "lose off")
end

t.Finish()
