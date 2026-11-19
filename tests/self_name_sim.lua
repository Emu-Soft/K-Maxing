-- The steal banner must name whoever took #1, never the player who lost it.
-- Kain saw his own name on every steal in game. This runs the ways the meter
-- could hand back his own name and checks the banner still names the thief.
--
--   lua5.1 tests/self_name_sim.lua [path to Maxing_Core.lua]

local Rig = dofile("tests/rig.lua")
local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"
local t = Rig.Checker()

-- Kain (MAGE) holds #1, then `thief` passes him mid-fight.
local function Steal(label, options, classes, thief)
	local w = Rig.NewWorld(CORE, options)
	local k = w:AddClient("Kain", "MAGE")
	for name, class in pairs(classes) do w:AddClient(name, class) end
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop(thief)
	w:Run(3)
	local text = Rig.StolenText(k)
	t.Check(text ~= nil and text:find("^" .. thief) ~= nil, label .. ": " .. thief .. " is named (got: " .. tostring(text) .. ")")
	t.Check(not (text and text:find("Kain")), label .. ": the banner doesn't name Kain")
	t.Check(#w.errors == 0, label .. ": no Lua errors" .. (w.errors[1] and (": " .. w.errors[1]) or ""))
end

local oneEmu = { Emu = "PRIEST" }
local twoRogues = { RogueA = "ROGUE", RogueB = "ROGUE" }

-- The meter window's rows carry Kain's own name, but the game's ranked rows
-- (read first) are right.
Steal("window names Kain", { windowShowsSelf = true }, oneEmu, "Emu")
Steal("window names Kain, two rogues", { windowShowsSelf = true }, twoRogues, "RogueB")
-- Only the window to read: the one K-Maxing priest is named from the user list.
Steal("window only, names Kain", { windowShowsSelf = true, noSessionAPI = true }, oneEmu, "Emu")
-- The GUID lookup answers with Kain: dropped, the row's own name is used.
Steal("GUID lookup names Kain", { guidNameIsSelf = true }, oneEmu, "Emu")
Steal("GUID lookup names Kain, two rogues", { guidNameIsSelf = true }, twoRogues, "RogueB")
Steal("GUID lookup names Kain, readable names", { guidNameIsSelf = true, plainNames = true }, oneEmu, "Emu")
-- A full meter: the thief is row 1 of five, not the only row.
Steal("full group on the meter", {}, { Emu = "PRIEST", Rogue = "ROGUE", Tank = "WARRIOR", Hunter = "HUNTER" }, "Rogue")
-- What /bmdiag showed in game: four on the meter, a rogue at #1, every name,
-- GUID and amount hidden, dungeon lockdown on. Only the class is readable.
Steal("as seen in game", { lockdown = function(x) return x.combat end },
	{ Rogue = "ROGUE", Healer = "PRIEST", Tank = "WARRIOR" }, "Rogue")

-- Forever writes names as "Name Realm", so our own party messages came back
-- looking like someone else's: we counted ourselves as a K-Maxing user and
-- took our own "I took #1" claim as the thief's. That named Kain in game.
local space = { spaceRealm = true }
local spaceLockdown = { spaceRealm = true, lockdown = function(x) return x.combat end }
Steal("Name Realm", space, { Rogue = "ROGUE", Healer = "PRIEST" }, "Rogue")
Steal("Name Realm, lockdown", spaceLockdown, { Rogue = "ROGUE", Healer = "PRIEST" }, "Rogue")
Steal("Name Realm, readable names", { spaceRealm = true, plainNames = true }, { Rogue = "ROGUE" }, "Rogue")
Steal("Name Realm, two rogues", space, twoRogues, "RogueB")

-- Kain's own class: a K-Maxing rogue passes a rogue Kain.
do
	local w = Rig.NewWorld(CORE, space)
	local k = w:AddClient("Kain", "ROGUE")
	w:AddClient("Emu", "ROGUE")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("Emu")
	w:Run(3)
	t.Check(Rig.StolenText(k) == "Emu has stolen your Balenciaga", "same class as Kain: Emu is named (got: " .. tostring(Rig.StolenText(k)) .. ")")
end

-- A rogue without K-Maxing passes a rogue Kain: the rogue is named, never Kain.
for _, opts in ipairs({ space, spaceLockdown }) do
	local w = Rig.NewWorld(CORE, opts)
	local k = w:AddClient("Kain", "ROGUE")
	w:AddPlayer("Stranger", "ROGUE")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("Stranger")
	w:Run(3)
	local text = Rig.StolenText(k)
	t.Check(text == "Stranger has stolen your Balenciaga", "rogue without K-Maxing passes rogue Kain"
		.. (opts.lockdown and ", lockdown" or "") .. ": Stranger is named (got: " .. tostring(text) .. ")")
end

-- Kain's test on 2026-11-19: he's the only K-Maxing user. A rogue passes him,
-- he takes #1 back, then a warrior passes him. Names hidden, lockdown on.
do
	local w = Rig.NewWorld(CORE, spaceLockdown)
	local k = w:AddClient("Kain", "MAGE")
	w:AddPlayer("Knome", "ROGUE")
	w:AddPlayer("Brock", "WARRIOR")
	w:AddPlayer("Gumbis", "PRIEST")
	w:SetCombat(true)
	w:SetTop("Kain")
	w:Run(2)
	w:SetTop("Knome")
	w:Run(3)
	t.Check(Rig.StolenText(k) == "Knome has stolen your Balenciaga", "Kain's test: the rogue is named (got: " .. tostring(Rig.StolenText(k)) .. ")")
	w:ClearTexts()
	w:SetTop("Kain")
	w:Run(6)
	w:SetTop("Brock")
	w:Run(3)
	t.Check(Rig.StolenText(k) == "Brock has stolen your Balenciaga", "Kain's test: the warrior is named (got: " .. tostring(Rig.StolenText(k)) .. ")")
	t.Check(#w.errors == 0, "Kain's test: no Lua errors" .. (w.errors[1] and (": " .. w.errors[1]) or ""))
end

t.Finish()
