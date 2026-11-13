-- Simulates a 5-player dungeon with several K-Maxing clients sharing one
-- party channel, and checks that the steal banner names the thief even when
-- the damage meter hides every name (as it does in combat on Forever).
--
--   lua5.1 tests/steal_sim.lua [path to Maxing_Core.lua]

local CORE = arg[1] or "K-Maxing/Maxing_Core.lua"

local now = 0
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local function issecret(v) return v == SECRET end

-- One frame stub for everything: any method (capitalised key) works, SetText
-- and SetScript are recorded. Lower-case keys are plain fields, nil until set.
local function NewFrame(log)
	local f = { scripts = {} }
	return setmetatable(f, { __index = function(_, k)
		if type(k) ~= "string" or not k:find("^%u") then return nil end
		if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
		if k == "SetText" then return function(_, text) log[#log + 1] = text end end
		if k == "CreateTexture" or k == "CreateFontString" or k == "CreateAnimationGroup"
			or k == "CreateAnimation" then
			return function() return NewFrame(log) end
		end
		if k == "GetName" then return function(self) return rawget(self, "name") end end
		if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12 end end
		if k:find("^Get") then return function() return 1 end end
		return function() end
	end })
end

local clients = {}

local function Deliver(prefix, msg, from)
	for _, c in ipairs(clients) do
		for _, f in ipairs(c.frames) do
			if f.scripts.OnEvent then f.scripts.OnEvent(f, "CHAT_MSG_ADDON", prefix, msg, "PARTY", from .. "-Realm") end
		end
	end
end

local function NewClient(name)
	local c = { name = name, frames = {}, texts = {}, rows = {}, sent = 0 }
	-- Named child frames from templates (e.g. a slider's "...Low" label) exist on demand.
	local env = setmetatable({}, { __index = function(_, k)
		if _G[k] ~= nil then return _G[k] end
		if type(k) == "string" and k:find("^BalenciagaSlider_") then return NewFrame(c.texts) end
	end })
	env._G = env
	env.issecretvalue = issecret
	env.GetTime = function() return now end
	env.UIParent = NewFrame(c.texts)
	env.CreateFrame = function(_, frameName)
		local f = NewFrame(c.texts)
		f.name = frameName
		c.frames[#c.frames + 1] = f
		return f
	end
	env.SlashCmdList = {}
	env.UnitName = function(unit) if unit == "player" then return name end end
	env.UnitAffectingCombat = function() return true end
	env.IsInInstance = function() return true, "party" end
	env.IsInRaid = function() return false end
	env.IsInGroup = function() return true end
	env.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() end,
		SendAddonMessage = function(prefix, msg)
			c.sent = c.sent + 1
			Deliver(prefix, msg, name)
		end,
	}
	env.C_DamageMeter = { IsDamageMeterAvailable = function() return true end }
	local provider = { Enumerate = function() return ipairs(c.rows) end }
	local scrollBox = {
		HasDataProvider = function() return true end,
		GetDataProvider = function() return provider end,
	}
	env.DamageMeterSessionWindow1 = { GetScrollBox = function() return scrollBox end }
	for _, fn in ipairs({ "PlayMusic", "StopMusic", "PlaySoundFile", "print", "SendChatMessage", "SetCVar",
		"UIDropDownMenu_SetText", "UIDropDownMenu_SetWidth", "UIDropDownMenu_Initialize",
		"UIDropDownMenu_AddButton" }) do
		env[fn] = function() end
	end
	env.UIDropDownMenu_CreateInfo = function() return {} end
	env.GetCVar = function() return "1" end
	env.GetCursorPosition = function() return 0, 0 end
	env.GetScreenWidth = function() return 1920 end
	env.IsAltKeyDown = function() return false end

	local chunk = assert(loadfile(CORE))
	setfenv(chunk, env)
	chunk("K-Maxing", {})
	for _, f in ipairs(c.frames) do
		if f.scripts.OnEvent then
			f.scripts.OnEvent(f, "ADDON_LOADED", "K-Maxing")
			f.scripts.OnEvent(f, "PLAYER_ENTERING_WORLD")
		end
	end
	clients[#clients + 1] = c
	return c
end

-- Every client's meter shows `topName` at #1, with every name hidden.
local function SetTop(topName)
	for _, c in ipairs(clients) do
		c.rows = { { index = 1, name = SECRET, isLocalPlayer = (c.name == topName) } }
	end
end

local function Run(seconds)
	local step = 0.1
	for _ = 1, math.floor(seconds / step + 0.5) do
		now = now + step
		for _, c in ipairs(clients) do
			for _, f in ipairs(c.frames) do
				if f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
			end
		end
	end
end

local function StolenText(c)
	for i = #c.texts, 1, -1 do
		local t = c.texts[i]
		if type(t) == "string" and t:find("has stolen your Balenciaga") then return t end
	end
end

local function ClearTexts()
	for _, c in ipairs(clients) do
		for i = #c.texts, 1, -1 do c.texts[i] = nil end
	end
end

local failures = 0
local function Check(cond, what)
	print((cond and "ok   " or "FAIL ") .. what)
	if not cond then failures = failures + 1 end
end

local kain = NewClient("Kain")
local emu = NewClient("Emu")
local other = NewClient("Other")
other.rows = {}

-- 1. Kain takes #1, then Emu (also running K-Maxing) takes it.
SetTop("Kain")
Run(2)
Check(StolenText(kain) == nil, "no steal banner while Kain holds #1")
SetTop("Emu")
Run(3)
Check(StolenText(kain) == "Emu has stolen your Balenciaga", "Kain sees Emu named as the thief")

-- 2. Kain takes it back, then loses it to someone without K-Maxing.
ClearTexts()
SetTop("Kain")
Run(3)
Check(StolenText(emu) == "Kain has stolen your Balenciaga", "Emu sees Kain named as the thief")
SetTop("nobody")
Run(3)
Check(StolenText(kain) == nil, "no steal banner when the new #1 doesn't run K-Maxing")

-- 3. An old claim must not name a thief later on.
ClearTexts()
SetTop("Emu")
Run(1)
SetTop("Kain")
Run(2)
SetTop("nobody")
Run(3)
Check(StolenText(kain) == nil, "a claim made before Kain retook #1 is ignored")

-- 4. Holding #1 sends one message, not one per poll.
local before = kain.sent
SetTop("Kain")
Run(10)
Check(kain.sent - before == 1, "one TOP message per time Kain takes #1")

if failures > 0 then
	print(failures .. " check(s) failed")
	os.exit(1)
end
print("all checks passed")
