--[[
BalenciagaMaxing: Core.lua

Watches Forever's built-in DamageMeter (C_DamageMeter / DamageMeterSessionWindow1)
for the moment the player becomes the #1 damage dealer in combat. While #1: plays music, 
pulses logo to track loudness, and updates a timer. On loss: smooth 2s audio 
and red timer fadeout.

Includes "Avada Balenciaga" takeover detection via Addon Comm Channels.
--]]

local addonName, ns = ...

-----------------------------------------------------------------------
-- Config & DB Init
-----------------------------------------------------------------------

local ANNOUNCE_ENABLED = false 
local ANNOUNCE_COOLDOWN = 300 
local POLL_INTERVAL = 0.5 
local BEAT_PERIOD = 60 / 126.05 
local COLOR_CYCLE_SECONDS = 0.6 
local COMBAT_GRACE_PERIOD = 5 
local FADE_OUT_DURATION = 2.0 
local STOLEN_FADE_OUT_DURATION = 0.5
local SNAP_THRESHOLD = 25 

local COMM_PREFIX = "BALENCIAGA_PING"

local LOGO_TEXCOORD_LEFT = 0.15771484
local LOGO_TEXCOORD_RIGHT = 0.84277344
local LOGO_TEXCOORD_TOP = 0.31152344
local LOGO_TEXCOORD_BOTTOM = 0.78710938
local LOGO_ASPECT = 1403 / 487 

local LOGO_WIDTH_MIN = 220
local LOGO_WIDTH_MAX = 420
local GLOW_SCALE_OF_LOGO = 1.6

local RADICAL_COLORS = {
	{ 1.00, 0.08, 0.58 }, -- hot pink
	{ 0.00, 1.00, 1.00 }, -- cyan
	{ 0.60, 1.00, 0.00 }, -- neon lime
	{ 1.00, 0.50, 0.00 }, -- neon orange
	{ 0.70, 0.00, 1.00 }, -- electric purple
}

if math.randomseed then
	math.randomseed(GetTime())
end

-----------------------------------------------------------------------
-- Addon Comm Network (K-Targeter Compatible Communication System)
-----------------------------------------------------------------------

local balenciagaUsers = {}

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
	C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
elseif RegisterAddonMessagePrefix then
	RegisterAddonMessagePrefix(COMM_PREFIX)
end

local function SendComm(message)
	local sendFunc = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
	if not sendFunc then return end

	if IsInRaid and IsInRaid() then
		sendFunc(COMM_PREFIX, message, "RAID")
	elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
		sendFunc(COMM_PREFIX, message, "PARTY")
	end
end

local function BroadcastPresence()
	SendComm("PING")
end

-----------------------------------------------------------------------
-- Strobe effects
-----------------------------------------------------------------------

local STROBE_SEQUENTIAL = 1
local STROBE_RANDOM_JUMP = 2
local STROBE_FLASH = 3
local STROBE_RAINBOW = 4

local STROBE_MODE_SWITCH_INTERVAL = 4

local function PickStrobeMode(intensity)
	local roll = math.random()
	if intensity < 0.35 then
		return STROBE_SEQUENTIAL
	elseif intensity < 0.6 then
		return (roll < 0.5) and STROBE_SEQUENTIAL or STROBE_RANDOM_JUMP
	elseif intensity < 0.8 then
		if roll < 0.34 then return STROBE_RANDOM_JUMP
		elseif roll < 0.67 then return STROBE_RAINBOW
		else return STROBE_FLASH end
	else
		return (roll < 0.6) and STROBE_FLASH or STROBE_RAINBOW
	end
end

local function HSVtoRGB(h, s, v)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local u = v * (1 - (1 - f) * s)
	if i == 0 then return v, u, p
	elseif i == 1 then return q, v, p
	elseif i == 2 then return p, q, v
	elseif i == 3 then return p, q, v
	elseif i == 4 then return u, p, v
	else return v, p, q end
end

-----------------------------------------------------------------------
-- Real, measured loudness envelope of the track
-----------------------------------------------------------------------

local ENERGY_ENVELOPE = {
	0.000, 0.142, 0.135, 0.188, 0.175, 0.135, 0.244, 0.192, 0.095, 0.225,
	0.282, 0.128, 0.074, 0.220, 0.379, 0.089, 0.300, 0.322, 0.425, 0.158,
	0.426, 0.436, 0.135, 0.259, 0.455, 0.610, 0.694, 0.149, 0.152, 0.181,
	0.240, 0.181, 0.283, 0.327, 0.280, 0.114, 0.226, 0.263, 0.164, 0.316,
	0.374, 0.343, 0.669, 0.996, 0.916, 0.883, 0.715, 0.623, 0.426, 0.430,
	0.430, 0.459, 0.397, 0.395, 0.745, 0.838, 0.363, 0.254, 0.249, 0.238,
	0.281, 0.294, 0.232, 0.278, 0.326, 0.144, 0.189, 0.256, 0.094, 0.407,
	0.722, 0.524, 0.519, 0.514, 0.486, 0.411, 0.362, 0.381, 0.542, 0.734,
	0.961, 0.916, 0.766, 0.585, 0.080, 0.397, 0.639, 0.766, 0.228, 0.155,
	0.304, 0.340, 0.243, 0.318, 0.301, 0.300, 0.293, 0.160, 0.149, 0.218,
	0.292, 0.423, 0.557, 0.881, 1.000, 0.916, 0.707, 0.510, 0.609, 0.461,
	0.560, 0.548, 0.491, 0.144, 0.602, 0.583, 0.971, 0.615, 0.255, 0.142,
	0.100, 0.087, 0.039, 0.268, 0.299, 0.183, 0.478, 0.825, 0.866, 0.824,
	0.704, 0.489, 0.659, 0.117, 0.289, 0.256, 0.150, 0.159, 0.036, 0.470,
	0.636, 0.608, 0.187, 0.183, 0.419, 0.116, 0.108, 0.078, 0.197, 0.173,
	0.401, 0.432, 0.548, 0.415, 0.386, 0.336,
}

local function EnergyAt(t)
	local n = #ENERGY_ENVELOPE
	if n == 0 then return 0.3 end
	if t <= 0 then return ENERGY_ENVELOPE[1] end
	local lastSampleTime = n - 1
	if t >= lastSampleTime then return ENERGY_ENVELOPE[n] end
	local i0 = math.floor(t)
	local frac = t - i0
	local v0 = ENERGY_ENVELOPE[i0 + 1]
	local v1 = ENERGY_ENVELOPE[i0 + 2] or v0
	return v0 + (v1 - v0) * frac
end

-----------------------------------------------------------------------
-- Built-in DamageMeter integration (Forever)
--
-- Confirmed via /dmdump against DamageMeterSessionWindow1: the ScrollBox's
-- DataProvider entries carry an `isLocalPlayer` flag directly, so we don't
-- need to name-match against UnitName("player")/realm suffixes at all --
-- the game tells us which row is us.
-----------------------------------------------------------------------

local function GetMeterDataProvider()
	if not (C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and C_DamageMeter.IsDamageMeterAvailable()) then
		return nil
	end
	local win = _G.DamageMeterSessionWindow1
	if not win or type(win.GetScrollBox) ~= "function" then return nil end
	local scrollBoxOk, scrollBox = pcall(win.GetScrollBox, win)
	if not scrollBoxOk or not scrollBox then return nil end
	if type(scrollBox.HasDataProvider) == "function" then
		local hasOk, has = pcall(scrollBox.HasDataProvider, scrollBox)
		if not hasOk or not has then return nil end
	end
	local providerOk, provider = pcall(scrollBox.GetDataProvider, scrollBox)
	if not providerOk or not provider then return nil end
	return provider
end

local function GetTopDamagePlayerName()
	local provider = GetMeterDataProvider()
	if not provider or type(provider.Enumerate) ~= "function" then return nil end

	-- The top row = the one Blizzard's meter ranks first. Confirmed with
	-- /bmdiag: IN COMBAT (even in the open world on Forever) the amounts,
	-- names and GUIDs are SECRET -- comparing totalAmount errored ("attempt
	-- to compare ... a secret number value"), the pcall here swallowed it,
	-- and the addon never saw the player as #1. But the meter already sorts
	-- its rows by the (secret) amounts, and each row's `index` (its
	-- position; 1 = top) and `isLocalPlayer` stay readable. So: take the row
	-- with index 1 -- or, if index is ever missing, the first row in the
	-- provider's order, which is the displayed order -- and ask whether it's
	-- us. No amounts are compared at all.
	--
	-- Returns: topName (may be a SECRET string in combat -- only display it,
	-- never compare/index with it), topIsLocal (true/false, or nil if
	-- unknown).
	local topEntry, firstEntry
	local ok = pcall(function()
		for _, entry in provider:Enumerate() do
			if not firstEntry then firstEntry = entry end
			local index = entry.index
			if index ~= nil and not (issecretvalue and issecretvalue(index)) and index == 1 then
				topEntry = entry
				break
			end
		end
	end)
	if not ok then return nil end
	topEntry = topEntry or firstEntry
	if not topEntry then return nil end
	local isLocal = topEntry.isLocalPlayer
	if isLocal ~= nil and issecretvalue and issecretvalue(isLocal) then isLocal = nil end
	return topEntry.name, isLocal
end

local combatStartTime = nil
local inDungeon = false

local function AmITopDamage()
	if not (UnitAffectingCombat and UnitAffectingCombat("player")) then
		return false
	end

	local topName, topIsLocal = GetTopDamagePlayerName()
	if topIsLocal == nil then return false end -- no rows, or can't tell
	return topIsLocal and true or false, topName
end

-----------------------------------------------------------------------
-- Visual display & Draggable Frames
-----------------------------------------------------------------------

local isUnlocked = false
local isCurrentlyTop = false
local testModeActive = false

local LOGO_BASE_WIDTH = LOGO_WIDTH_MIN
local LOGO_BASE_HEIGHT = LOGO_BASE_WIDTH / LOGO_ASPECT
local GLOW_BASE_WIDTH = LOGO_BASE_WIDTH * GLOW_SCALE_OF_LOGO
local GLOW_BASE_HEIGHT = LOGO_BASE_HEIGHT * GLOW_SCALE_OF_LOGO

local logoFrame = nil
local timerFrame = nil
local stolenFrame = nil
local stolenTextFrame = nil

local function SaveFramePosition(frame)
	if not BalenciagaMaxingDB then BalenciagaMaxingDB = {} end
	local key = "logoPos"
	if frame == timerFrame then key = "timerPos"
	elseif frame == stolenFrame then key = "stolenPos" 
	elseif frame == stolenTextFrame then key = "stolenTextPos" end

	local cx, cy = frame:GetCenter()
	if cx and cy then
		BalenciagaMaxingDB[key] = { x = cx, y = cy }
	end
end

local function SetupDraggableFrame(frame, titleText, isTopLabel)
	frame:SetClampedToScreen(false)

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	-- Forever/retail no longer treats numeric args to SetTexture() as a color
	-- fill (they're read as a texture fileID instead) -- SetColorTexture is
	-- the modern call for a flat rgba fill. SetTexture(0,0,0,0.6) here would
	-- silently fail to draw anything on Forever.
	bg:SetColorTexture(0, 0, 0, 0.6)
	bg:Hide()
	frame.dragBg = bg

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if isTopLabel then
		label:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	else
		label:SetPoint("TOP", frame, "BOTTOM", 0, -4)
	end
	label:SetText(titleText)
	label:Hide()
	frame.dragLabel = label

	frame:SetScript("OnMouseDown", function(self, button)
		if isUnlocked and button == "LeftButton" then
			local scale = UIParent:GetEffectiveScale()
			local x, y = GetCursorPosition()
			self.dragStartX = x / scale
			self.dragStartY = y / scale
			
			local cx, cy = self:GetCenter()
			self.frameStartX = cx
			self.frameStartY = cy
			self.isDragging = true
		end
	end)

	frame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.isDragging then
			self.isDragging = false
			SaveFramePosition(self)
		end
	end)

	frame:SetScript("OnUpdate", function(self)
		if self.isDragging then
			local scale = UIParent:GetEffectiveScale()
			local curX, curY = GetCursorPosition()
			curX = curX / scale
			curY = curY / scale

			local deltaX = curX - self.dragStartX
			local deltaY = curY - self.dragStartY

			local targetX = self.frameStartX + deltaX
			local targetY = self.frameStartY + deltaY

			local framesToSnap = { logoFrame, timerFrame, stolenFrame, stolenTextFrame }
			for _, otherFrame in ipairs(framesToSnap) do
				if otherFrame ~= self and otherFrame:IsShown() then
					local otherTop = otherFrame:GetTop()
					local otherBottom = otherFrame:GetBottom()
					local otherX = otherFrame:GetCenter()
					local myHeight = self:GetHeight()

					if otherBottom and math.abs((targetY + myHeight/2) - otherBottom) <= SNAP_THRESHOLD then
						targetY = otherBottom - (myHeight / 2)
					elseif otherTop and math.abs((targetY - myHeight/2) - otherTop) <= SNAP_THRESHOLD then
						targetY = otherTop + (myHeight / 2)
					end

					if otherX and math.abs(targetX - otherX) <= SNAP_THRESHOLD then
						targetX = otherX
					end
				end
			end

			if IsAltKeyDown() then
				local screenCenterX = GetScreenWidth() / 2
				targetX = screenCenterX
				for _, otherFrame in ipairs(framesToSnap) do
					if otherFrame ~= self and otherFrame:IsShown() then
						local otherX = otherFrame:GetCenter()
						if otherX and math.abs(otherX - screenCenterX) <= SNAP_THRESHOLD then
							targetX = otherX
						end
					end
				end
			end

			self:ClearAllPoints()
			self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", targetX, targetY)
		end
	end)
end

-- 1. Logo Frame Anchor
logoFrame = CreateFrame("Frame", "BalenciagaLogoFrame", UIParent)
logoFrame:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
logoFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
logoFrame:SetFrameStrata("HIGH")
logoFrame:Hide()
SetupDraggableFrame(logoFrame, "Logo Anchor\n(Drag to snap, hold Alt for center axis)", true)

local headline = CreateFrame("Frame", nil, logoFrame)
headline:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
headline:SetPoint("CENTER", logoFrame, "CENTER", 0, 0)

local glowTexture = headline:CreateTexture(nil, "BACKGROUND")
glowTexture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Glow.tga")
glowTexture:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
glowTexture:SetPoint("CENTER", headline, "CENTER", 0, 0)
glowTexture:SetBlendMode("ADD")
glowTexture:SetVertexColor(1, 1, 1, 0.8)

local logoTexture = headline:CreateTexture(nil, "ARTWORK")
logoTexture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\BalenciagaMaxingLogo.tga")
logoTexture:SetTexCoord(LOGO_TEXCOORD_LEFT, LOGO_TEXCOORD_RIGHT, LOGO_TEXCOORD_TOP, LOGO_TEXCOORD_BOTTOM)
logoTexture:SetSize(LOGO_BASE_WIDTH, LOGO_BASE_HEIGHT)
logoTexture:SetPoint("CENTER", headline, "CENTER", 0, 0)

-- 2. Timer Frame Anchor
timerFrame = CreateFrame("Frame", "BalenciagaTimerFrame", UIParent)
timerFrame:SetSize(250, 40)
timerFrame:SetPoint("TOP", UIParent, "TOP", 0, -430)
timerFrame:SetFrameStrata("HIGH")
timerFrame:Hide()
SetupDraggableFrame(timerFrame, "Timer Anchor\n(Drag to snap, hold Alt for center axis)", false)

local timerText = timerFrame:CreateFontString(nil, "OVERLAY")
timerText:SetFont("Fonts\\SKURRI.TTF", 22, "OUTLINE")
timerText:SetPoint("CENTER", timerFrame, "CENTER", 0, 0)
timerText:SetTextColor(1, 1, 1)

-- 3. Stolen Image Frame Anchor
stolenFrame = CreateFrame("Frame", "BalenciagaStolenFrame", UIParent)
stolenFrame:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
stolenFrame:SetPoint("TOP", UIParent, "TOP", 0, -250)
stolenFrame:SetFrameStrata("HIGH")
stolenFrame:Hide()
SetupDraggableFrame(stolenFrame, "Stolen Image Anchor\n(Drag to snap, hold Alt for center axis)", true)

local stolenHeadline = CreateFrame("Frame", nil, stolenFrame)
stolenHeadline:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
stolenHeadline:SetPoint("CENTER", stolenFrame, "CENTER", 0, 0)

local stolenGlow = stolenHeadline:CreateTexture(nil, "BACKGROUND")
stolenGlow:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Glow.tga")
stolenGlow:SetSize(GLOW_BASE_WIDTH, GLOW_BASE_HEIGHT)
stolenGlow:SetPoint("CENTER", stolenHeadline, "CENTER", 0, 0)
stolenGlow:SetBlendMode("ADD")
stolenGlow:SetVertexColor(0.34, 0.85, 0.05, 0.9)

local stolenTexture = stolenHeadline:CreateTexture(nil, "ARTWORK")
stolenTexture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Avada_Balenciaga.tga")
stolenTexture:SetTexCoord(0, 1, 0, 1)
stolenTexture:SetSize(LOGO_BASE_WIDTH, LOGO_BASE_HEIGHT)
stolenTexture:SetPoint("CENTER", stolenHeadline, "CENTER", 0, 0)

-- 4. Stolen Text Frame Anchor
stolenTextFrame = CreateFrame("Frame", "BalenciagaStolenTextFrame", UIParent)
stolenTextFrame:SetSize(350, 40)
stolenTextFrame:SetPoint("TOP", UIParent, "TOP", 0, -400)
stolenTextFrame:SetFrameStrata("HIGH")
stolenTextFrame:Hide()
SetupDraggableFrame(stolenTextFrame, "Stolen Text Anchor\n(Drag to snap, hold Alt for center axis)", false)

local stolenText = stolenTextFrame:CreateFontString(nil, "OVERLAY")
stolenText:SetFont("Fonts\\SKURRI.TTF", 20, "OUTLINE")
stolenText:SetPoint("CENTER", stolenTextFrame, "CENTER", 0, 0)
stolenText:SetTextColor(1, 0.2, 0.2)

-----------------------------------------------------------------------
-- Font options
-----------------------------------------------------------------------

local LSM = nil
if LibStub then
	LSM = LibStub("LibSharedMedia-3.0", true)
end

local FALLBACK_FONTS = {
	{ name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Skurri (Battleground)", path = "Fonts\\SKURRI.TTF" },
	{ name = "Morpheus (Quest)", path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
}

local DEFAULT_FONT_PATH = "Fonts\\SKURRI.TTF"

local FONT_SLOTS = {
	timer = { dbKey = "timerFont", getTarget = function() return timerText end, size = 22 },
	stolen = { dbKey = "stolenFont", getTarget = function() return stolenText end, size = 20 },
}

local function GetAvailableFonts()
	if LSM then
		local list = {}
		for _, fontName in ipairs(LSM:List(LSM.MediaType.FONT)) do
			table.insert(list, { name = fontName, path = LSM:Fetch(LSM.MediaType.FONT, fontName) })
		end
		return list
	end
	return FALLBACK_FONTS
end

local function GetSelectedFontPath(slotKey)
	local slot = FONT_SLOTS[slotKey]
	local stored = BalenciagaMaxingDB and BalenciagaMaxingDB[slot.dbKey]
	if not stored then
		return DEFAULT_FONT_PATH
	end
	if LSM then
		local path = LSM:Fetch(LSM.MediaType.FONT, stored)
		if path then return path end
		return DEFAULT_FONT_PATH
	end
	return stored
end

local function ApplyFontSlot(slotKey)
	local slot = FONT_SLOTS[slotKey]
	local target = slot.getTarget()
	local path = GetSelectedFontPath(slotKey)
	local ok = pcall(function() target:SetFont(path, slot.size, "OUTLINE") end)
	if not ok then
		target:SetFont(DEFAULT_FONT_PATH, slot.size, "OUTLINE")
	end
end

local function ApplyAllFontSlots()
	ApplyFontSlot("timer")
	ApplyFontSlot("stolen")
end

-----------------------------------------------------------------------
-- Options window -- /kmax
-----------------------------------------------------------------------

local optionsFrame = CreateFrame("Frame", "BalenciagaOptionsFrame", UIParent)
optionsFrame:SetSize(340, 480)
optionsFrame:SetPoint("CENTER")
optionsFrame:SetFrameStrata("DIALOG")
optionsFrame:EnableMouse(true)
optionsFrame:SetMovable(true)
optionsFrame:RegisterForDrag("LeftButton")
optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
optionsFrame:Hide()

local optBg = optionsFrame:CreateTexture(nil, "BACKGROUND")
optBg:SetAllPoints()
optBg:SetColorTexture(0, 0, 0, 0.8) -- see note above re: SetTexture color fills on Forever

local optTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
optTitle:SetPoint("TOP", 0, -14)
optTitle:SetText("Balenciaga Maxing Options")

local function TryPreviewFontOnButton(level, index, fontPath)
	pcall(function()
		local buttonName = "DropDownList" .. level .. "Button" .. index
		local fontString = _G[buttonName .. "NormalText"]
		if fontString then
			fontString:SetFont(fontPath, 14, "")
		end
	end)
end

local function CreateFontDropdown(slotKey, label, yOffset)
	local slot = FONT_SLOTS[slotKey]

	local optLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	optLabel:SetPoint("TOPLEFT", 20, yOffset)
	optLabel:SetText(label)

	local dropdown = CreateFrame("Frame", "BalenciagaFontDropdown_" .. slotKey, optionsFrame, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", optLabel, "BOTTOMLEFT", -16, -4)
	UIDropDownMenu_SetWidth(dropdown, 220)

	local function SelectFont(fontEntry)
		if not BalenciagaMaxingDB then BalenciagaMaxingDB = {} end
		BalenciagaMaxingDB[slot.dbKey] = LSM and fontEntry.name or fontEntry.path
		ApplyFontSlot(slotKey)
		UIDropDownMenu_SetText(dropdown, fontEntry.name)
	end

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		local fonts = GetAvailableFonts()
		for i, fontEntry in ipairs(fonts) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = fontEntry.name
			info.func = function() SelectFont(fontEntry) end
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)
			TryPreviewFontOnButton(level, i, fontEntry.path)
		end
	end)

	return dropdown
end

local function CreateScaleSlider(dbKey, labelText, yOffset, targetFrame)
	local slider = CreateFrame("Slider", "BalenciagaSlider_"..dbKey, optionsFrame, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 20, yOffset)
	slider:SetMinMaxValues(0.5, 3.0)
	slider:SetValueStep(0.05)
	slider:SetWidth(300)
	
	_G[slider:GetName() .. "Low"]:SetText("0.5x")
	_G[slider:GetName() .. "High"]:SetText("3.0x")
	_G[slider:GetName() .. "Text"]:SetText(labelText)

	slider:SetScript("OnValueChanged", function(self, value)
		local step = 0.05
		local roundedValue = math.floor((value / step) + 0.5) * step
		
		if not BalenciagaMaxingDB then BalenciagaMaxingDB = {} end
		BalenciagaMaxingDB[dbKey] = roundedValue
		targetFrame:SetScale(roundedValue)
	end)
	return slider
end

local timerFontDropdown = CreateFontDropdown("timer", "Timer Font:", -45)
local timerScaleSlider = CreateScaleSlider("timerScale", "Timer Text Scale", -125, timerFrame)

local stolenFontDropdown = CreateFontDropdown("stolen", "\"Stole Your Balenciaga\" Font:", -175)
local stolenTextScaleSlider = CreateScaleSlider("stolenTextScale", "Stolen Text Scale", -255, stolenTextFrame)

-- GUI Buttons
local previewTimerButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
previewTimerButton:SetSize(140, 22)
previewTimerButton:SetPoint("TOPLEFT", 20, -300)
previewTimerButton:SetText("Preview Timer")

local previewStolenButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
previewStolenButton:SetSize(140, 22)
previewStolenButton:SetPoint("TOPLEFT", 170, -300)
previewStolenButton:SetText("Preview Banner")

local previewStealButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
previewStealButton:SetSize(140, 22)
previewStealButton:SetPoint("TOPLEFT", 20, -330)
previewStealButton:SetText("Test 3s Steal")

local previewStopButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
previewStopButton:SetSize(140, 22)
previewStopButton:SetPoint("TOPLEFT", 170, -330)
previewStopButton:SetText("Stop Preview")

local unlockUIButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
unlockUIButton:SetSize(140, 22)
unlockUIButton:SetPoint("TOP", 0, -370)
unlockUIButton:SetText("Unlock Frames")

local optCloseButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
optCloseButton:SetSize(90, 22)
optCloseButton:SetPoint("BOTTOM", 0, 16)
optCloseButton:SetText("Close")
optCloseButton:SetScript("OnClick", function() optionsFrame:Hide() end)

-- Purge global dropdown changes when hiding the options menu so unit frames remain untouched
optionsFrame:SetScript("OnHide", function()
	pcall(function()
		for level = 1, 3 do
			for index = 1, 30 do
				local buttonName = "DropDownList" .. level .. "Button" .. index
				local fontString = _G[buttonName .. "NormalText"]
				if fontString then
					fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
				end
			end
		end
	end)
end)

local function FindFontDisplayName(slotKey)
	local slot = FONT_SLOTS[slotKey]
	local stored = BalenciagaMaxingDB and BalenciagaMaxingDB[slot.dbKey]
	if not stored then return nil end
	if LSM then
		return stored 
	end
	for _, fontEntry in ipairs(FALLBACK_FONTS) do
		if fontEntry.path == stored then return fontEntry.name end
	end
	return nil
end

local function OpenOptions()
	UIDropDownMenu_SetText(timerFontDropdown, FindFontDisplayName("timer") or "(default)")
	UIDropDownMenu_SetText(stolenFontDropdown, FindFontDisplayName("stolen") or "(default)")
	
	local tScale = (BalenciagaMaxingDB and BalenciagaMaxingDB.timerScale) or 1.0
	local sScale = (BalenciagaMaxingDB and BalenciagaMaxingDB.stolenTextScale) or 1.0
	timerScaleSlider:SetValue(tScale)
	stolenTextScaleSlider:SetValue(sScale)
	
	optionsFrame:Show()
end

-----------------------------------------------------------------------
-- Combined Audio & Fade-Out Controllers
-----------------------------------------------------------------------

local originalMusicVolume = nil
local faderFrame = CreateFrame("Frame")
local isFading = false
local fadeTimer = 0
local activeFadeDuration = FADE_OUT_DURATION

local function StartFadeOut(duration)
	if isFading then return end
	originalMusicVolume = tonumber(GetCVar("Sound_MusicVolume")) or 1.0
	fadeTimer = 0
	activeFadeDuration = duration or FADE_OUT_DURATION
	isFading = true
	faderFrame:Show()
end

local function StopFadeImmediate()
	faderFrame:Hide()
	isFading = false
	if originalMusicVolume then
		SetCVar("Sound_MusicVolume", originalMusicVolume)
		originalMusicVolume = nil
	end
	timerFrame:SetAlpha(1.0)
	stolenFrame:SetAlpha(1.0)
	stolenTextFrame:SetAlpha(1.0)
	StopMusic()
end

faderFrame:SetScript("OnUpdate", function(self, elapsed)
	if not isFading then return end
	fadeTimer = fadeTimer + elapsed
	local progress = fadeTimer / activeFadeDuration
	if progress >= 1.0 then
		StopFadeImmediate()
		if not isUnlocked then
			if not isCurrentlyTop then timerFrame:Hide() end
			stolenFrame:Hide()
			stolenTextFrame:Hide()
		end
	else
		local alphaRemaining = 1.0 - progress
		local newVol = (originalMusicVolume or 1.0) * alphaRemaining
		SetCVar("Sound_MusicVolume", newVol)
		if not isCurrentlyTop then timerFrame:SetAlpha(alphaRemaining) end
		stolenFrame:SetAlpha(alphaRemaining)
		stolenTextFrame:SetAlpha(alphaRemaining)
	end
end)

-----------------------------------------------------------------------
-- Stolen Event Handler
-----------------------------------------------------------------------

local stolenTimerFrame = CreateFrame("Frame")
local isStolenActive = false
local stolenTimeElapsed = 0
local STOLEN_AUDIO_DURATION = 4.0

local function TriggerBalenciagaStolen(thiefName)
	StopFadeImmediate()
	isCurrentlyTop = false

	logoFrame:Hide()
	timerFrame:Hide()

	stolenText:SetText(thiefName .. " has stolen your Balenciaga")
	
	stolenFrame:SetAlpha(1.0)
	stolenFrame:Show()
	stolenTextFrame:SetAlpha(1.0)
	stolenTextFrame:Show()

	PlaySoundFile("Interface\\AddOns\\" .. addonName .. "\\Music\\Avada_Balenciaga.mp3", "Master")

	stolenTimeElapsed = 0
	isStolenActive = true
	stolenTimerFrame:Show()
end

stolenTimerFrame:SetScript("OnUpdate", function(self, elapsed)
	if not isStolenActive then return end
	stolenTimeElapsed = stolenTimeElapsed + elapsed
	if stolenTimeElapsed >= STOLEN_AUDIO_DURATION then
		isStolenActive = false
		stolenTimerFrame:Hide()
		StartFadeOut(STOLEN_FADE_OUT_DURATION)
	end
end)

-----------------------------------------------------------------------
-- Timer Tick & Beat Logic
-----------------------------------------------------------------------

local topSince = nil
local frozenTime = nil
local colorIndex = 1
local colorTimer = 0
local pulsePhase = 0

local currentStrobeMode = STROBE_SEQUENTIAL
local strobeModeTimer = 0
local flashIsWhite = false
local rainbowHue = 0

local function ApplyStrobeColor(intensity, elapsed)
	if currentStrobeMode == STROBE_RAINBOW then
		rainbowHue = (rainbowHue + elapsed * (0.15 + intensity * 0.6)) % 1
		local r, g, b = HSVtoRGB(rainbowHue, 1, 1)
		glowTexture:SetVertexColor(r, g, b, 0.8)
		return
	end

	colorTimer = colorTimer + elapsed
	local effectiveCycleSeconds = COLOR_CYCLE_SECONDS / (0.5 + intensity * 1.5)
	if colorTimer < effectiveCycleSeconds then return end
	colorTimer = 0

	if currentStrobeMode == STROBE_SEQUENTIAL then
		colorIndex = (colorIndex % #RADICAL_COLORS) + 1
	elseif currentStrobeMode == STROBE_RANDOM_JUMP then
		colorIndex = math.random(1, #RADICAL_COLORS)
	elseif currentStrobeMode == STROBE_FLASH then
		flashIsWhite = not flashIsWhite
		if flashIsWhite then
			glowTexture:SetVertexColor(1, 1, 1, 0.8)
			return
		end
		colorIndex = math.random(1, #RADICAL_COLORS)
	end

	local c = RADICAL_COLORS[colorIndex]
	glowTexture:SetVertexColor(c[1], c[2], c[3], 0.8)
end

local timerTickerFrame = CreateFrame("Frame")
timerTickerFrame:SetScript("OnUpdate", function(self, elapsed)
	if frozenTime then
		local mins = math.floor(frozenTime / 60)
		local secs = frozenTime % 60
		timerText:SetText(string.format("%d:%06.3f", mins, secs))
		return
	end

	if not topSince then return end
	local t = GetTime() - topSince

	local intensity = EnergyAt(t)
	local smoothedIntensity = math.pow(intensity, 0.7)

	local effectivePeriod = BEAT_PERIOD / (0.6 + smoothedIntensity * 0.8)
	local amplitude = 0.08 + smoothedIntensity * 0.12
	pulsePhase = pulsePhase + (elapsed / effectivePeriod) * (2 * math.pi)

	local baseWidth = LOGO_WIDTH_MIN + smoothedIntensity * (LOGO_WIDTH_MAX - LOGO_WIDTH_MIN)
	local swingPx = baseWidth * amplitude
	local targetWidth = baseWidth + swingPx * math.sin(pulsePhase)

	headline:SetScale(targetWidth / LOGO_BASE_WIDTH)

	strobeModeTimer = strobeModeTimer + elapsed
	if strobeModeTimer >= STROBE_MODE_SWITCH_INTERVAL then
		strobeModeTimer = 0
		currentStrobeMode = PickStrobeMode(intensity)
	end
	ApplyStrobeColor(intensity, elapsed)

	local mins = math.floor(t / 60)
	local secs = t % 60
	timerText:SetText(string.format("%d:%06.3f", mins, secs))
end)

-----------------------------------------------------------------------
-- State Machine
-----------------------------------------------------------------------

local lastAnnounceTime = 0
local pollTimer = 0

local function LocalMusicPath()
	return "Interface\\AddOns\\" .. addonName .. "\\Music\\balenciaga.mp3"
end

local function OnBecameTop()
	StopFadeImmediate()
	isStolenActive = false
	stolenFrame:Hide()
	stolenTextFrame:Hide()

	isCurrentlyTop = true
	topSince = GetTime()
	frozenTime = nil
	colorTimer = 0
	colorIndex = 1
	pulsePhase = 0
	currentStrobeMode = STROBE_SEQUENTIAL
	strobeModeTimer = 0
	flashIsWhite = false
	rainbowHue = 0

	timerFrame:SetAlpha(1.0)
	timerText:SetTextColor(1, 1, 1)
	headline:SetScale(LOGO_WIDTH_MIN / LOGO_BASE_WIDTH)
	
	logoFrame:Show()
	timerFrame:Show()

	PlayMusic(LocalMusicPath())

	if ANNOUNCE_ENABLED then
		local now = GetTime()
		if now - lastAnnounceTime >= ANNOUNCE_COOLDOWN then
			lastAnnounceTime = now
			SendChatMessage("is Balenciaga Maxing", "EMOTE")
		end
	end
end

local function OnLostTop(newTopName)
	local wasTop = isCurrentlyTop
	isCurrentlyTop = false

	if topSince and not frozenTime then
		frozenTime = GetTime() - topSince
	end
	topSince = nil
	timerText:SetTextColor(1.0, 0.2, 0.2)

	if not isUnlocked then
		logoFrame:Hide()
	end
	headline:SetScale(1)
	glowTexture:SetVertexColor(1, 1, 1, 0.8)

	-- In combat the new top player's name is a SECRET string: it can't be
	-- used as a table key (that errors), so the "stolen" check can't run --
	-- fall back to the normal fade-out. Out of combat it works as before.
	local thiefKnown = newTopName ~= nil and not (issecretvalue and issecretvalue(newTopName))
		and balenciagaUsers[newTopName]
	if wasTop and thiefKnown then
		TriggerBalenciagaStolen(newTopName)
	else
		StartFadeOut(FADE_OUT_DURATION)
	end
end

-----------------------------------------------------------------------
-- Commands, GUI Actions & Drag Controls
-----------------------------------------------------------------------

local testSequenceFrame = CreateFrame("Frame")
local isTestStealActive = false
local testStealElapsed = 0

testSequenceFrame:SetScript("OnUpdate", function(self, elapsed)
	if not isTestStealActive then return end
	testStealElapsed = testStealElapsed + elapsed
	if testStealElapsed >= 3.0 then
		isTestStealActive = false
		testSequenceFrame:Hide()
		TriggerBalenciagaStolen("TestPlayer")
	end
end)

local function SetUnlockState(unlock)
	isUnlocked = unlock
	logoFrame:EnableMouse(unlock)
	timerFrame:EnableMouse(unlock)
	stolenFrame:EnableMouse(unlock)
	stolenTextFrame:EnableMouse(unlock)

	if unlockUIButton then
		if unlock then
			unlockUIButton:SetText("Lock Frames")
		else
			unlockUIButton:SetText("Unlock Frames")
		end
	end

	if unlock then
		StopFadeImmediate()
		logoFrame.dragBg:Show()
		logoFrame.dragLabel:Show()
		timerFrame.dragBg:Show()
		timerFrame.dragLabel:Show()
		stolenFrame.dragBg:Show()
		stolenFrame.dragLabel:Show()
		stolenTextFrame.dragBg:Show()
		stolenTextFrame.dragLabel:Show()

		logoFrame:Show()
		timerFrame:Show()
		stolenFrame:Show()
		stolenTextFrame:Show()
		timerFrame:SetAlpha(1.0)
		stolenFrame:SetAlpha(1.0)
		stolenTextFrame:SetAlpha(1.0)
		stolenText:SetText("Target Player has stolen your Balenciaga")
		timerText:SetTextColor(1, 1, 1)
		timerText:SetText("0:00.000")
		print("|cffff69b4Balenciaga Maxing:|r Frames UNLOCKED. Drag to snap elements, hold Alt to lock to center axis.")
	else
		logoFrame.dragBg:Hide()
		logoFrame.dragLabel:Hide()
		timerFrame.dragBg:Hide()
		timerFrame.dragLabel:Hide()
		stolenFrame.dragBg:Hide()
		stolenFrame.dragLabel:Hide()
		stolenTextFrame.dragBg:Hide()
		stolenTextFrame:Hide()

		stolenFrame:Hide()
		stolenTextFrame:Hide()
		if not isCurrentlyTop and not testModeActive then
			logoFrame:Hide()
			if not frozenTime or not isFading then
				timerFrame:Hide()
			end
		end
		print("|cffff69b4Balenciaga Maxing:|r Frames LOCKED.")
	end
end

-- Wire GUI Buttons
previewTimerButton:SetScript("OnClick", function()
	testModeActive = true
	OnBecameTop()
end)

previewStolenButton:SetScript("OnClick", function()
	TriggerBalenciagaStolen("TestPlayer")
end)

previewStealButton:SetScript("OnClick", function()
	print("|cffff69b4Balenciaga Maxing:|r Beginning 3s #1 test... get ready to be stolen!")
	OnBecameTop()
	testStealElapsed = 0
	isTestStealActive = true
	testSequenceFrame:Show()
end)

previewStopButton:SetScript("OnClick", function()
	if testModeActive then
		testModeActive = false
		OnLostTop(nil)
	end
	if isTestStealActive then
		isTestStealActive = false
		testSequenceFrame:Hide()
		StopFadeImmediate()
	end
end)

unlockUIButton:SetScript("OnClick", function()
	SetUnlockState(not isUnlocked)
end)


SLASH_KMAX1 = "/kmax"
SlashCmdList["KMAX"] = function(msg)
	OpenOptions()
end

print("|cffff69b4Balenciaga Maxing:|r loaded. Type |cffffffff/kmax|r to open the options menu.")

-----------------------------------------------------------------------
-- Event & Comm Handling
-----------------------------------------------------------------------

local lostTopTimer = 0
local LOST_TOP_THRESHOLD = 1.5

local eventsFrame = CreateFrame("Frame")
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventsFrame:RegisterEvent("CHAT_MSG_ADDON")

eventsFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
	if event == "ADDON_LOADED" and prefix == addonName then
		if not BalenciagaMaxingDB then BalenciagaMaxingDB = {} end

		if BalenciagaMaxingDB.logoPos then
			logoFrame:ClearAllPoints()
			logoFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", BalenciagaMaxingDB.logoPos.x, BalenciagaMaxingDB.logoPos.y)
		end

		if BalenciagaMaxingDB.timerPos then
			timerFrame:ClearAllPoints()
			timerFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", BalenciagaMaxingDB.timerPos.x, BalenciagaMaxingDB.timerPos.y)
		end

		if BalenciagaMaxingDB.stolenPos then
			stolenFrame:ClearAllPoints()
			stolenFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", BalenciagaMaxingDB.stolenPos.x, BalenciagaMaxingDB.stolenPos.y)
		end
		
		if BalenciagaMaxingDB.stolenTextPos then
			stolenTextFrame:ClearAllPoints()
			stolenTextFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", BalenciagaMaxingDB.stolenTextPos.x, BalenciagaMaxingDB.stolenTextPos.y)
		end
		
		if BalenciagaMaxingDB.timerScale then
			timerFrame:SetScale(BalenciagaMaxingDB.timerScale)
		end
		
		if BalenciagaMaxingDB.stolenTextScale then
			stolenTextFrame:SetScale(BalenciagaMaxingDB.stolenTextScale)
		end

		ApplyAllFontSlots()

	elseif event == "PLAYER_REGEN_DISABLED" then
		combatStartTime = GetTime()
	elseif event == "PLAYER_REGEN_ENABLED" then
		combatStartTime = nil
	elseif event == "PLAYER_ENTERING_WORLD" then
		local inInstance, instanceType = IsInInstance()
		inDungeon = inInstance and instanceType == "party"

		if isCurrentlyTop then
			PlayMusic(LocalMusicPath())
		end
		BroadcastPresence()

	elseif event == "CHAT_MSG_ADDON" and prefix == COMM_PREFIX then
		if msg == "PING" then
			local senderShort = (sender:match("([^-]+)")) or sender
			balenciagaUsers[senderShort] = true
			if senderShort ~= UnitName("player") then
				SendComm("PONG")
			end
		elseif msg == "PONG" then
			local senderShort = (sender:match("([^-]+)")) or sender
			balenciagaUsers[senderShort] = true
		end
	end
end)

do
	local inInstance, instanceType = IsInInstance()
	inDungeon = inInstance and instanceType == "party"
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, elapsed)
	pollTimer = pollTimer + elapsed
	if pollTimer < POLL_INTERVAL then return end
	pollTimer = 0

	if testModeActive or isUnlocked then return end

	if not inDungeon then
		if isCurrentlyTop then OnLostTop(nil) end
		return
	end

	local amTop, topPlayerName = AmITopDamage()

	if amTop then
		lostTopTimer = 0
		if not isCurrentlyTop then
			OnBecameTop()
		end
	elseif isCurrentlyTop then
		lostTopTimer = lostTopTimer + POLL_INTERVAL
		if lostTopTimer >= LOST_TOP_THRESHOLD then
			lostTopTimer = 0
			OnLostTop(topPlayerName)
		end
	end
end)

-----------------------------------------------------------------------
-- /bmdiag -- damage meter diagnostic (temporary; read-only)
--
-- Walks the same path GetTopDamagePlayerName() takes and prints what it
-- finds at each step, instead of letting a pcall swallow the failure.
-- Run it MID-COMBAT, once in the open world and once in a dungeon, and
-- compare. Changes nothing about how the addon behaves.
-----------------------------------------------------------------------

local function DiagState(v)
	if v == nil then return "nil" end
	if issecretvalue and issecretvalue(v) then return "SECRET" end
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" then return t .. " (" .. tostring(v) .. ")" end
	return t
end

local function DiagPrint(msg)
	print("|cffff69b4[bmdiag]|r " .. msg)
end

local function RunMeterDiagnostic()
	DiagPrint("---- damage meter diagnostic ----")

	-- 1. The conditions the poll loop checks before it even looks.
	local inInstance, instanceType = IsInInstance()
	DiagPrint(string.format("instance: %s, type: %s -> counts as party dungeon: %s (the addon only checks inside one)",
		tostring(inInstance), tostring(instanceType), tostring(inInstance and instanceType == "party")))
	DiagPrint("in combat (UnitAffectingCombat): " .. DiagState(UnitAffectingCombat and UnitAffectingCombat("player")))

	-- 2. The API itself, and every function it offers.
	if not C_DamageMeter then
		DiagPrint("C_DamageMeter: MISSING on this client")
	else
		local okAvail, avail = pcall(function() return C_DamageMeter.IsDamageMeterAvailable() end)
		DiagPrint("C_DamageMeter.IsDamageMeterAvailable(): " .. (okAvail and DiagState(avail) or "errored"))
		local fns = {}
		for k, v in pairs(C_DamageMeter) do fns[#fns + 1] = k .. (type(v) == "function" and "()" or "") end
		table.sort(fns)
		DiagPrint("C_DamageMeter offers: " .. table.concat(fns, ", "))
	end
	for _, enumName in ipairs({ "DamageMeterType", "DamageMeterSessionType" }) do
		local e = Enum and Enum[enumName]
		if e then
			local parts = {}
			for k, v in pairs(e) do parts[#parts + 1] = k .. "=" .. tostring(v) end
			table.sort(parts)
			DiagPrint("Enum." .. enumName .. ": " .. table.concat(parts, ", "))
		end
	end

	-- 3. The window the addon reads from.
	local win = _G.DamageMeterSessionWindow1
	if not win then
		DiagPrint("DamageMeterSessionWindow1: MISSING (window not created/open?)")
	else
		local okShown, shown = pcall(function() return win:IsShown() end)
		DiagPrint("DamageMeterSessionWindow1: exists, shown: " .. (okShown and tostring(shown) or "?"))
		-- Any field that looks like the window's mode (damage vs healing,
		-- current vs overall) -- names vary, so list likely candidates.
		local modeParts = {}
		for k, v in pairs(win) do
			if type(k) == "string" and (k:lower():find("type") or k:lower():find("session") or k:lower():find("mode")) then
				if type(v) ~= "function" and type(v) ~= "table" then modeParts[#modeParts + 1] = k .. "=" .. DiagState(v) end
			end
		end
		if #modeParts > 0 then DiagPrint("window mode fields: " .. table.concat(modeParts, ", ")) end
	end

	-- 4. The rows, exactly as the addon gets them.
	local provider = GetMeterDataProvider()
	if not provider then
		DiagPrint("data provider: NOT AVAILABLE (meter unavailable, window missing, or no data yet)")
	else
		local count, shownRows = 0, 0
		local okEnum, enumErr = pcall(function()
			for _, entry in provider:Enumerate() do
				count = count + 1
				if shownRows < 3 then
					shownRows = shownRows + 1
					DiagPrint(string.format("row %d: name=%s totalAmount=%s isLocalPlayer=%s",
						count, DiagState(entry.name), DiagState(entry.totalAmount), DiagState(entry.isLocalPlayer)))
					-- Every plain field on the first row, in case a name changed.
					if count == 1 then
						local keys = {}
						for k, v in pairs(entry) do
							if type(k) == "string" and type(v) ~= "function" then keys[#keys + 1] = k .. "=" .. DiagState(v) end
						end
						table.sort(keys)
						DiagPrint("row 1 all fields: " .. table.concat(keys, ", "))
					end
				end
			end
		end)
		DiagPrint("rows: " .. count .. (okEnum and "" or ("  |cffff5555enumerate errored:|r " .. tostring(enumErr))))
	end

	-- 5. The ranking itself, WITHOUT the swallowing pcall's silence.
	local okRank, a, b = pcall(GetTopDamagePlayerName)
	if not okRank then
		DiagPrint("|cffff5555ranking errored:|r " .. tostring(a))
	else
		DiagPrint("ranking result: top=" .. DiagState(a) .. ", isLocalPlayer=" .. DiagState(b)
			.. (a == nil and "  (nil = the ranking's internal pcall failed or there were no rows)" or ""))
	end
	-- Re-run the comparison loop unprotected-but-caught, to surface the
	-- error the ranking's own pcall hides.
	if provider then
		local okCmp, cmpErr = pcall(function()
			local best = -1
			for _, entry in provider:Enumerate() do
				local amount = entry.totalAmount or 0
				if amount > best then best = amount end
			end
		end)
		DiagPrint("amount comparison: " .. (okCmp and "OK (amounts are comparable)" or ("|cffff5555FAILS:|r " .. tostring(cmpErr))))
	end
	DiagPrint("---- end ----")
end

SLASH_BMDIAG1 = "/bmdiag"
SlashCmdList["BMDIAG"] = function() RunMeterDiagnostic() end
