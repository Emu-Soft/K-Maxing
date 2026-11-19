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

t.Finish()
