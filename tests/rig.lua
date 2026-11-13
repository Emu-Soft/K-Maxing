-- A small stand-in for the WoW: Forever client, enough to run several copies
-- of Maxing_Core.lua in one party and drive them from a test.
--
--   local Rig = dofile("tests/rig.lua")
--   local world = Rig.NewWorld(core_path, options)
--
-- options (all optional):
--   lockdown       function(world) -> true while addon messages are locked down
--   lockdownMode   "result" (send returns a lockdown code, the default) or
--                  "error" (send raises a Lua error)
--   delay          seconds before a sent message arrives (default 0)
--   secretSender   true: the sender of every received message is a secret value
--   secretOutOfCombat  true: meter names stay secret out of combat too
--   indexSecret    true: the meter's row index is secret
--   plainNames     true: meter names are readable even in combat
--   noNames        true: meter rows have no name at all
--   solo           true: not in a group (only whispers go out)
--   secretClass    true: the meter's class column is secret too
--
-- Group: every client is in the party, plus players added with
-- world:AddPlayer(name, class) who don't run K-Maxing. Classes default to
-- one each from CLASSES; anyone else on the meter is a DRUID.
--
-- Each client records: texts (every SetText), sent (messages that went out),
-- attempts (send calls, including refused ones) and music (PlayMusic calls).
--
-- Secret values wrap the real value. issecretvalue() spots them; the game
-- can still draw them (tostring, so string.format("%s") shows the real
-- text, as SetText does in game), but compares, arithmetic and ".." fail
-- like the real thing.
local Rig = {}

local SecretMT = {
	__tostring = function(v) return tostring(rawget(v, "value")) end,
	__concat = function() error("attempt to concatenate a secret string value") end,
	__eq = function() error("attempt to compare a secret value") end,
	__lt = function() error("attempt to compare a secret value") end,
	__le = function() error("attempt to compare a secret value") end,
	__index = function() error("attempt to index a secret value") end,
}
function Rig.Secret(value) return setmetatable({ value = value }, SecretMT) end
local function IsSecret(v) return type(v) == "table" and getmetatable(v) == SecretMT end

-- The game's string.format takes secrets and gives back a secret string.
local gameString = setmetatable({
	format = function(fmt, ...)
		local args, anySecret = { ... }, false
		for i = 1, select("#", ...) do
			if IsSecret(args[i]) then
				anySecret = true
				args[i] = rawget(args[i], "value")
			end
		end
		local text = string.format(fmt, unpack(args, 1, select("#", ...)))
		return anySecret and Rig.Secret(text) or text
	end,
}, { __index = string })

local CLASSES = { "MAGE", "PRIEST", "ROGUE", "WARRIOR", "HUNTER" }

-- The result codes the rig's SendAddonMessage returns.
local SEND_RESULT = { Success = 0, AddonMessageThrottle = 3, AddonMessageLockdown = 11 }

-- One frame stub for everything: any method (capitalised key) works, SetText
-- and SetScript are recorded. Lower-case keys are plain fields, nil until set.
local function NewFrame(log)
	local f = { scripts = {} }
	return setmetatable(f, { __index = function(_, k)
		if type(k) ~= "string" or not k:find("^%u") then return nil end
		if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
		-- What the player would see: secrets are drawn as their real text.
		if k == "SetText" then
			return function(_, text) log[#log + 1] = IsSecret(text) and rawget(text, "value") or text end
		end
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

function Rig.NewWorld(corePath, options)
	local world = {
		now = 0, combat = false, clients = {}, queue = {},
		options = options or {}, errors = {},
	}
	local opts = world.options

	local function Fire(c, event, ...)
		for _, f in ipairs(c.frames) do
			if f.scripts.OnEvent then
				local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
				if not ok then world.errors[#world.errors + 1] = c.name .. " " .. event .. ": " .. tostring(err) end
			end
		end
	end

	local function LockedDown()
		return opts.lockdown and opts.lockdown(world) or false
	end

	local function Send(c, prefix, msg, channel, target)
		c.attempts = c.attempts + 1
		if opts.solo and channel ~= "WHISPER" then return 9 end -- not in a group
		if LockedDown() then
			if opts.lockdownMode == "error" then error("addon messages are restricted right now") end
			return SEND_RESULT.AddonMessageLockdown
		end
		c.sent[#c.sent + 1] = msg
		world.queue[#world.queue + 1] = {
			at = world.now + (opts.delay or 0), prefix = prefix, msg = msg, from = c.name,
			channel = channel, to = channel == "WHISPER" and target or nil,
		}
		return SEND_RESULT.Success
	end

	local function DeliverDue()
		local keep = {}
		for _, m in ipairs(world.queue) do
			if m.at <= world.now + 1e-9 then
				for _, c in ipairs(world.clients) do
					if not m.to or m.to == c.name then
						local sender = m.from .. "-Realm"
						if opts.secretSender then sender = Rig.Secret(sender) end
						Fire(c, "CHAT_MSG_ADDON", m.prefix, m.msg, m.channel, sender)
					end
				end
			else
				keep[#keep + 1] = m
			end
		end
		world.queue = keep
	end

	world.party, world.classOf = {}, {}

	function world:AddPlayer(name, class)
		self.party[#self.party + 1] = name
		self.classOf[name] = class or CLASSES[#self.party]
	end

	function world:AddClient(name, class)
		self:AddPlayer(name, class)
		local c = { name = name, frames = {}, texts = {}, rows = {}, sent = {}, attempts = 0, music = 0 }
		-- Named child frames from templates (e.g. a slider's "...Low" label) exist on demand.
		local env = setmetatable({}, { __index = function(_, k)
			if _G[k] ~= nil then return _G[k] end
			if type(k) == "string" and k:find("^BalenciagaSlider_") then return NewFrame(c.texts) end
		end })
		env._G = env
		env.issecretvalue = IsSecret
		env.string = gameString
		-- Takes a (secret) GUID, gives the name without the realm, as secret as the GUID.
		env.UnitNameFromGUID = function(guid)
			local plain = IsSecret(guid) and rawget(guid, "value") or guid
			local short = plain:match("^Player%-(.+)$")
			return IsSecret(guid) and Rig.Secret(short) or short
		end
		env.GetTime = function() return world.now end
		env.UIParent = NewFrame(c.texts)
		env.CreateFrame = function(_, frameName)
			local f = NewFrame(c.texts)
			f.name = frameName
			c.frames[#c.frames + 1] = f
			return f
		end
		env.SlashCmdList = {}
		env.Enum = { SendAddonMessageResult = SEND_RESULT }
		env.UnitName = function(unit) if unit == "player" then return name end end
		env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
		-- "partyN" is the Nth other group member.
		local function UnitPlayer(unit)
			if unit == "player" then return name end
			local n = tonumber(unit:match("^party(%d)$") or "")
			if not n then return nil end
			for _, other in ipairs(world.party) do
				if other ~= name then
					n = n - 1
					if n == 0 then return other end
				end
			end
		end
		env.UnitExists = function(unit) return UnitPlayer(unit) ~= nil end
		env.UnitClass = function(unit)
			local who = UnitPlayer(unit)
			if who then return world.classOf[who], world.classOf[who] end
		end
		env.UnitAffectingCombat = function() return world.combat end
		env.IsInInstance = function() return true, "party" end
		env.IsInRaid = function() return false end
		env.IsInGroup = function() return not opts.solo end
		env.C_ChatInfo = {
			RegisterAddonMessagePrefix = function() end,
			SendAddonMessage = function(prefix, msg, channel, target) return Send(c, prefix, msg, channel, target) end,
		}
		env.C_DamageMeter = { IsDamageMeterAvailable = function() return true end }
		local provider = { Enumerate = function() return ipairs(c.rows) end }
		local scrollBox = {
			HasDataProvider = function() return true end,
			GetDataProvider = function() return provider end,
		}
		env.DamageMeterSessionWindow1 = { GetScrollBox = function() return scrollBox end }
		env.PlayMusic = function() c.music = c.music + 1 end
		for _, fn in ipairs({ "StopMusic", "PlaySoundFile", "print", "SendChatMessage", "SetCVar",
			"UIDropDownMenu_SetText", "UIDropDownMenu_SetWidth", "UIDropDownMenu_Initialize",
			"UIDropDownMenu_AddButton" }) do
			env[fn] = function() end
		end
		env.UIDropDownMenu_CreateInfo = function() return {} end
		env.GetCVar = function() return "1" end
		env.GetCursorPosition = function() return 0, 0 end
		env.GetScreenWidth = function() return 1920 end
		env.IsAltKeyDown = function() return false end

		c.env = env
		local chunk = assert(loadfile(corePath))
		setfenv(chunk, env)
		chunk("K-Maxing", {})
		self.clients[#self.clients + 1] = c
		Fire(c, "ADDON_LOADED", "K-Maxing")
		Fire(c, "PLAYER_ENTERING_WORLD")
		DeliverDue()
		return c
	end

	-- Every client's meter shows `topName` at #1. Names are secret in combat
	-- (and out of it with secretOutOfCombat); each client sees only whether
	-- the top row is itself.
	function world:SetTop(topName)
		self.top = topName
		for _, c in ipairs(self.clients) do
			local hidden = (self.combat or opts.secretOutOfCombat) and not opts.plainNames
			local shownName = topName
			-- Party members' names come with their realm; the GUID gives the short name.
			local shownName, guid = topName .. "-Realm", "Player-" .. topName
			if opts.noNames then
				shownName, guid = nil, nil
			elseif hidden then
				shownName, guid = Rig.Secret(shownName), Rig.Secret(guid)
			end
			c.rows = { {
				index = opts.indexSecret and Rig.Secret(1) or 1,
				name = shownName,
				sourceGUID = guid,
				isLocalPlayer = (c.name == topName),
				classFilename = opts.secretClass and Rig.Secret(self.classOf[topName] or "DRUID")
					or (self.classOf[topName] or "DRUID"),
			} }
		end
	end

	function world:SetCombat(on)
		self.combat = on
		for _, c in ipairs(self.clients) do
			Fire(c, on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
		end
		if self.top then self:SetTop(self.top) end
	end

	function world:Run(seconds)
		local step = 0.1
		for _ = 1, math.floor(seconds / step + 0.5) do
			self.now = self.now + step
			DeliverDue()
			for _, c in ipairs(self.clients) do
				for _, f in ipairs(c.frames) do
					if f.scripts.OnUpdate then
						local ok, err = pcall(f.scripts.OnUpdate, f, step)
						if not ok then self.errors[#self.errors + 1] = c.name .. " OnUpdate: " .. tostring(err) end
					end
				end
			end
		end
	end

	-- Runs a slash command on one client, e.g. world:Slash(c, "KMAX", "fake Emu").
	function world:Slash(c, key, msg)
		local ok, err = pcall(c.env.SlashCmdList[key], msg)
		if not ok then self.errors[#self.errors + 1] = c.name .. " /" .. key .. ": " .. tostring(err) end
	end

	function world:ClearTexts()
		for _, c in ipairs(self.clients) do
			for i = #c.texts, 1, -1 do c.texts[i] = nil end
		end
	end

	return world
end

function Rig.StolenText(c)
	for i = #c.texts, 1, -1 do
		local t = c.texts[i]
		if type(t) == "string" and t:find("has stolen your Balenciaga") then return t end
	end
end

function Rig.Checker()
	local checker = { failures = 0 }
	function checker.Check(cond, what)
		print((cond and "ok   " or "FAIL ") .. what)
		if not cond then checker.failures = checker.failures + 1 end
	end
	function checker.Finish()
		if checker.failures > 0 then
			print(checker.failures .. " check(s) failed")
			os.exit(1)
		end
		print("all checks passed")
	end
	return checker
end

return Rig
