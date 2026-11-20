-- With Details! loaded, K-Maxing follows the Details window (its fight and
-- its Damage Done/DPS view) instead of the game's meter. Any other Details
-- view, a closed or broken window, or no Details at all falls back to the
-- game's meter, as before.
--
--   lua5.1 tests/details_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

-- Kain holds #1 on the game's meter the whole fight. Halfway through, the
-- Details window ranks Emu first.
local function Fight(label, details)
	local w = Rig.NewWorld(CORE, { details = details })
	local k = w:AddClient("Kain", "MAGE")
	w:AddClient("Emu", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	local musicBefore = k.music
	w:SetDetailsTop("Emu")
	w:Run(3)
	t.Check(#w.errors == 0, label .. ": no Lua errors" .. (w.errors[1] and (": " .. w.errors[1]) or ""))
	return k, musicBefore
end

-- Details shows Damage Done on this fight: it decides.
do
	local k, music = Fight("Details damage done", {})
	t.Check(music > 0, "Details damage done: Kain's #1 starts the music")
	t.Check(Rig.StolenText(k) == "Emu has stolen your Balenciaga",
		"Details damage done: Emu passing Kain on Details is a steal (got: " .. tostring((Rig.StolenText(k))) .. ")")
end
do
	local k = Fight("Details DPS", { sub = 2 })
	t.Check(Rig.StolenText(k) == "Emu has stolen your Balenciaga", "Details DPS view counts too")
end

-- Any other Details view: the game's meter decides, so Kain keeps #1.
for _, case in ipairs({
	{ "Details healing view", { display = 2, sub = 1 } },
	{ "Details damage taken view", { sub = 3 } },
	{ "Details Overall", { segment = 0 } },
	{ "Details older fight", { segment = 2 } },
	{ "Details window closed", { enabled = false } },
	{ "Details window errors", { broken = true } },
}) do
	local k = Fight(case[1], case[2])
	t.Check(Rig.StolenText(k) == nil, case[1] .. ": the game's meter is read, Kain keeps #1")
end

-- No Details: unchanged.
do
	local k = Fight("no Details", nil)
	t.Check(Rig.StolenText(k) == nil, "no Details: the game's meter is read")
end

-- Details' window is empty (fight just started): the game's rows are read.
do
	local w = Rig.NewWorld(CORE, { details = {} })
	local k = w:AddClient("Kain", "MAGE")
	w:AddClient("Emu", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	for _, c in ipairs(w.clients) do c.detailsRows = {} end
	w:Run(2)
	t.Check(k.music > 0, "empty Details window: Kain's #1 on the game's meter still counts")
	t.Check(#w.errors == 0, "empty Details window: no Lua errors")
end

-- The steal banner still works with Details in a locked-down dungeon fight.
do
	local w = Rig.NewWorld(CORE, { details = {}, lockdown = function(x) return x.combat end })
	local k = w:AddClient("Kain", "MAGE")
	w:AddClient("Rogue", "ROGUE")
	w:AddClient("Healer", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetDetailsTop("Rogue")
	w:Run(3)
	t.Check(Rig.StolenText(k) == "Rogue has stolen your Balenciaga", "lockdown: Details' #1 is named")
	t.Check(#w.errors == 0, "lockdown: no Lua errors")
end

t.Finish()
