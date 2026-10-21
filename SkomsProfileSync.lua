-- SkomsProfileSync: set up one character, then copy its action bars, keybinds, macros, BindPad profile and addon
-- profiles to your other characters (same account). 3.3.5a.
local ADDON = ...

local db
local PREFIX = "|cff33ff99SkomsProfileSync|r: "
local function Say(m) print(PREFIX .. m) end

local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or 36
local MAX_CHAR = MAX_CHARACTER_MACROS or 18
local NUM_SLOTS = 120

local DEFAULT_OPTS = {
	bars = true, clearEmptySlots = false,
	keybinds = true, keepOtherKeybinds = false,
	macros = true, generalMacros = false, deleteOtherMacros = false,
	bindpad = true,
	profiles = true,
}

local function Copy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = Copy(x) end
	return t
end

local function CountKeys(t)
	local n = 0
	if t then for _ in pairs(t) do n = n + 1 end end
	return n
end

local function PlayerKey() return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?") end

-- ---------------------------------------------------------------------------------------------------------
-- read the current character
-- ---------------------------------------------------------------------------------------------------------
local function ReadBindings()
	local list = {}
	for i = 1, GetNumBindings() do
		local cmd = GetBinding(i)
		if cmd then
			local keys = { GetBindingKey(cmd) }
			if #keys > 0 then list[#list + 1] = { cmd = cmd, keys = keys } end
		end
	end
	return list
end

local function ReadMacros()
	local list = {}
	local numAccount, numChar = GetNumMacros()
	local function add(index, perChar)
		local name, icon, body = GetMacroInfo(index)
		if name then list[#list + 1] = { name = name, icon = icon, body = body or "", perChar = perChar } end
	end
	for i = 1, numAccount do add(i, false) end
	for i = 1, numChar do add(MAX_ACCOUNT + i, true) end
	return list
end

local function ReadBars()
	local bars = {}
	for slot = 1, NUM_SLOTS do
		if HasAction(slot) then
			local kind, id, sub = GetActionInfo(slot)
			if kind == "spell" and id then
				local name = GetSpellInfo(id)
				if name then bars[slot] = { t = "spell", name = name, id = id } end
			elseif kind == "macro" and id then
				local name = GetMacroInfo(id)
				if name then bars[slot] = { t = "macro", name = name } end
			elseif kind == "item" and id then
				bars[slot] = { t = "item", id = id, name = GetItemInfo(id) }
			elseif kind == "companion" and id then
				bars[slot] = { t = "companion", id = id, sub = sub, name = GetSpellInfo(id) }
			end
		end
	end
	return bars
end

-- the global name of a saved variables table
local function SVName(sv)
	for k, v in pairs(_G) do
		if v == sv and type(k) == "string" then return k end
	end
end

local function ReadProfiles()
	local list = {}
	local AceDB = LibStub and LibStub("AceDB-3.0", true)
	if AceDB and AceDB.db_registry then
		for dbo in pairs(AceDB.db_registry) do
			if type(dbo) == "table" and not dbo.parent and dbo.sv and dbo.GetCurrentProfile then
				local svn = SVName(dbo.sv)
				if svn then list[svn] = dbo:GetCurrentProfile() end
			end
		end
	end
	return list
end

local function BindPadKey()
	if BindPadCore and BindPadCore.character then return BindPadCore.character end
	return (GetRealmName() or "") .. "_" .. (UnitName("player") or "")
end

local function ReadBindPad()
	if not BindPadVars then return nil end
	local data = BindPadVars[BindPadKey()]
	if type(data) == "table" then return Copy(data) end
end

local function Save(name)
	local _, class = UnitClass("player")
	local snap = {
		class = class, char = PlayerKey(), date = date("%Y-%m-%d %H:%M"),
		bindings = ReadBindings(), macros = ReadMacros(), bars = ReadBars(),
		profiles = ReadProfiles(), bindpad = ReadBindPad(),
	}
	db.snapshots[name] = snap
	db.selected = name
	return snap
end

local function Summary(snap)
	local charMacros = 0
	for _, m in ipairs(snap.macros) do if m.perChar then charMacros = charMacros + 1 end end
	return ("%d action slots, %d keybinds, %d macros (%d of the character), %d addon profiles%s"):format(
		CountKeys(snap.bars), #snap.bindings, #snap.macros, charMacros, CountKeys(snap.profiles), snap.bindpad and ", a BindPad profile" or "")
end

-- ---------------------------------------------------------------------------------------------------------
-- apply to the current character (in small steps, one per frame)
-- ---------------------------------------------------------------------------------------------------------
local steps, report = {}, {}
local runner = CreateFrame("Frame")
runner:Hide()
local function Report(m) report[#report + 1] = m end

local function Finish()
	for _, line in ipairs(report) do Say(line) end
	db.lastResult = table.concat(report, "\n")
	Say("Done. A /reload is needed for BindPad and some addon profiles.")
	LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON)
end

runner:SetScript("OnUpdate", function(self)
	local step = table.remove(steps, 1)
	if step then
		local ok, err = pcall(step)
		if not ok then Report("error: " .. tostring(err)) end
	end
	if #steps == 0 then self:Hide(); Finish() end
end)

local function IconIndex(texture)
	if not texture or not GetNumMacroIcons then return 1 end
	local want = texture:lower():gsub("^interface[\\/]icons[\\/]", "")
	for i = 1, GetNumMacroIcons() do
		local t = GetMacroIconInfo(i)
		if t and t:lower():gsub("^interface[\\/]icons[\\/]", "") == want then return i end
	end
	return 1
end

local function ApplyMacros(snap, o)
	local made, edited, failed = 0, 0, 0
	local wanted = {}
	for _, m in ipairs(snap.macros) do
		if m.perChar or o.generalMacros then
			wanted[m.name] = true
			local index = GetMacroIndexByName(m.name)
			if index and index > 0 then
				pcall(EditMacro, index, m.name, m.icon, m.body)
				if select(3, GetMacroInfo(index)) ~= m.body then pcall(EditMacro, index, m.name, IconIndex(m.icon), m.body) end
				edited = edited + 1
			else
				local ok = pcall(CreateMacro, m.name, m.icon, m.body, nil, m.perChar and 1 or nil)
				local idx = GetMacroIndexByName(m.name)
				if not (ok and idx and idx > 0) then
					ok = pcall(CreateMacro, m.name, IconIndex(m.icon), m.body, nil, m.perChar and 1 or nil)
					idx = GetMacroIndexByName(m.name)
				end
				if ok and idx and idx > 0 then
					if m.perChar and idx <= MAX_ACCOUNT then
						-- created as a general macro by mistake: redo it as a character macro
						DeleteMacro(idx)
						pcall(CreateMacro, m.name, m.icon, m.body, 1)
						idx = GetMacroIndexByName(m.name)
					end
					made = made + 1
				else
					failed = failed + 1
				end
			end
		end
	end
	local deleted = 0
	if o.deleteOtherMacros then
		local _, numChar = GetNumMacros()
		for i = MAX_ACCOUNT + numChar, MAX_ACCOUNT + 1, -1 do
			local name = GetMacroInfo(i)
			if name and not wanted[name] then DeleteMacro(i); deleted = deleted + 1 end
		end
	end
	Report(("Macros: %d created, %d updated%s%s."):format(made, edited, failed > 0 and (", " .. failed .. " failed (full?)") or "",
		deleted > 0 and (", " .. deleted .. " deleted") or ""))
end

local function ApplyBindings(snap, o)
	if not o.keepOtherKeybinds then
		local all = {}
		for i = 1, GetNumBindings() do
			local cmd = GetBinding(i)
			if cmd then
				for _, key in ipairs({ GetBindingKey(cmd) }) do all[#all + 1] = key end
			end
		end
		for _, key in ipairs(all) do SetBinding(key) end
	end
	local n = 0
	for _, b in ipairs(snap.bindings) do
		for _, key in ipairs(b.keys) do
			if SetBinding(key, b.cmd) then n = n + 1 end
		end
	end
	SaveBindings(GetCurrentBindingSet())
	Report(("Keybinds: %d keys set."):format(n))
end

local function SpellBookMap()
	local map = {}
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for i = offset + 1, offset + count do
			local name = GetSpellName(i, BOOKTYPE_SPELL)
			if name then map[name] = i end   -- higher ranks come later and win
		end
	end
	return map
end

local function CompanionIndex(kind, spellId)
	for i = 1, (GetNumCompanions(kind) or 0) do
		local _, _, sid = GetCompanionInfo(kind, i)
		if sid == spellId then return i end
	end
end

local function SlotAlready(slot, e)
	if not HasAction(slot) then return false end
	local kind, id = GetActionInfo(slot)
	if e.t == "spell" and kind == "spell" then return GetSpellInfo(id) == e.name end
	if e.t == "macro" and kind == "macro" then return GetMacroInfo(id) == e.name end
	if e.t == "item" and kind == "item" then return id == e.id end
	return false
end

local stats
local function ApplySlots(snap, o, book, from, to)
	for slot = from, to do
		local e = snap.bars[slot]
		ClearCursor()
		if e then
			if SlotAlready(slot, e) then
				stats.same = stats.same + 1
			else
				if e.t == "spell" then
					if book[e.name] then PickupSpell(book[e.name], BOOKTYPE_SPELL) end
				elseif e.t == "macro" then
					local idx = GetMacroIndexByName(e.name)
					if idx and idx > 0 then PickupMacro(idx) end
				elseif e.t == "item" then
					PickupItem(e.id)
				elseif e.t == "companion" then
					local kind = (e.sub == "CRITTER") and "CRITTER" or "MOUNT"
					local idx = CompanionIndex(kind, e.id)
					if idx then PickupCompanion(kind, idx) end
				end
				if GetCursorInfo() then
					PlaceAction(slot)
					stats.placed = stats.placed + 1
				else
					stats.missing = stats.missing + 1
					stats.names[#stats.names + 1] = e.name or ("item " .. tostring(e.id))
				end
				ClearCursor()
			end
		elseif o.clearEmptySlots and HasAction(slot) then
			PickupAction(slot)
			ClearCursor()
			stats.cleared = stats.cleared + 1
		end
	end
end

local function ApplyProfiles(snap)
	local AceDB = LibStub and LibStub("AceDB-3.0", true)
	if not AceDB or not AceDB.db_registry then Report("Addon profiles: AceDB not found.") return end
	local switched, skipped = 0, {}
	for dbo in pairs(AceDB.db_registry) do
		if type(dbo) == "table" and not dbo.parent and dbo.sv and dbo.GetCurrentProfile then
			local svn = SVName(dbo.sv)
			local want = svn and snap.profiles[svn]
			if want and not db.profileOff[svn] then
				if dbo:GetCurrentProfile() == want then
					-- already the same
				elseif dbo.sv.profiles and dbo.sv.profiles[want] then
					dbo:SetProfile(want)
					switched = switched + 1
				else
					skipped[#skipped + 1] = svn
				end
			end
		end
	end
	Report(("Addon profiles: %d switched%s."):format(switched, #skipped > 0 and (", not found here: " .. table.concat(skipped, ", ")) or ""))
end

local function Apply(name)
	local snap = db.snapshots[name]
	if not snap then Say("No saved setup called '" .. tostring(name) .. "'.") return end
	if InCombatLockdown() then Say("Not in combat.") return end
	if runner:IsShown() then Say("Already applying.") return end
	local o = db.opts
	local _, class = UnitClass("player")
	local sameClass = (snap.class == class)
	wipe(steps); wipe(report)
	Report(("Applying '%s' (from %s) to %s."):format(name, snap.char, PlayerKey()))

	if o.macros then steps[#steps + 1] = function() ApplyMacros(snap, o) end end
	if o.keybinds then steps[#steps + 1] = function() ApplyBindings(snap, o) end end
	if o.bars then
		if not sameClass then
			Report("Action bars skipped: the setup is from a " .. tostring(snap.class) .. ", this is a " .. tostring(class) .. ".")
		else
			local book
			steps[#steps + 1] = function()
				book = SpellBookMap()
				stats = { placed = 0, same = 0, missing = 0, cleared = 0, names = {} }
			end
			for from = 1, NUM_SLOTS, 20 do
				steps[#steps + 1] = function() ApplySlots(snap, o, book, from, math.min(from + 19, NUM_SLOTS)) end
			end
			steps[#steps + 1] = function()
				local miss = ""
				if stats.missing > 0 then
					local shown = {}
					for i = 1, math.min(6, #stats.names) do shown[i] = stats.names[i] end
					miss = (", %d not available here (%s%s)"):format(stats.missing, table.concat(shown, ", "), #stats.names > 6 and ", ..." or "")
				end
				Report(("Action bars: %d placed, %d already right%s%s."):format(stats.placed, stats.same, miss,
					stats.cleared > 0 and (", " .. stats.cleared .. " cleared") or ""))
			end
		end
	end
	if o.bindpad and snap.bindpad then
		steps[#steps + 1] = function()
			if BindPadVars then
				BindPadVars[BindPadKey()] = Copy(snap.bindpad)
				Report("BindPad: profile copied (visible after /reload).")
			else
				Report("BindPad is not loaded.")
			end
		end
	end
	if o.profiles then steps[#steps + 1] = function() ApplyProfiles(snap) end end
	runner:Show()
end

-- ---------------------------------------------------------------------------------------------------------
-- options window
-- ---------------------------------------------------------------------------------------------------------
local function SnapshotValues()
	local v = {}
	for name, snap in pairs(db.snapshots) do v[name] = ("%s  (%s)"):format(name, snap.char) end
	return v
end

local function Options()
	local opts = db.opts
	local newName = db.newName
	local root = { type = "group", name = "SkomsProfileSync", childGroups = "tab", args = {} }

	-- tab 1: save
	local save = { type = "group", name = "Save a setup", order = 1, args = {} }
	save.args.info = { type = "description", order = 1, fontSize = "medium",
		name = "Set up one character the way you like (action bars, keybinds, macros, BindPad, addon profiles), then save it here. "
			.. "The setup is kept for the whole account, so you can apply it to your other characters.\n\nThis character: " .. PlayerKey() }
	save.args.name = { type = "input", order = 2, name = "Name of the setup", width = "double",
		get = function() return db.newName or select(2, UnitClass("player")) or "Setup" end,
		set = function(_, v) db.newName = strtrim(v or "") end }
	save.args.save = { type = "execute", order = 3, name = "Save this character as a setup",
		confirm = function() return db.snapshots[db.newName or select(2, UnitClass("player")) or "Setup"] and "A setup with this name exists. Replace it?" or false end,
		func = function()
			local name = db.newName
			if not name or name == "" then name = select(2, UnitClass("player")) or "Setup" end
			local snap = Save(name)
			Say(("'%s' saved: %s."):format(name, Summary(snap)))
			LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON)
		end }
	save.args.header = { type = "header", order = 10, name = "Saved setups" }
	local n = 0
	for name, snap in pairs(db.snapshots) do
		n = n + 1
		save.args["s" .. name] = { type = "description", order = 10 + n * 2, fontSize = "medium",
			name = ("|cffffd100%s|r  from %s on %s\n%s"):format(name, snap.char, snap.date, Summary(snap)) }
		save.args["d" .. name] = { type = "execute", order = 11 + n * 2, name = "Delete " .. name, width = "half",
			confirm = true, confirmText = "Delete the setup '" .. name .. "'?",
			func = function() db.snapshots[name] = nil; if db.selected == name then db.selected = nil end end }
	end
	if n == 0 then save.args.none = { type = "description", order = 11, name = "Nothing saved yet." } end
	root.args.save = save

	-- tab 2: apply
	local ap = { type = "group", name = "Apply to this character", order = 2, args = {} }
	local snap = db.selected and db.snapshots[db.selected]
	ap.args.info = { type = "description", order = 1, fontSize = "medium",
		name = "This character: " .. PlayerKey() .. "\nChoose a saved setup and what to copy, then press Apply. Your current choices are replaced." }
	ap.args.select = { type = "select", order = 2, name = "Setup", width = "double", values = SnapshotValues,
		get = function() return db.selected end, set = function(_, v) db.selected = v end }
	local function toggle(key, label, desc, order, disabled)
		ap.args[key] = { type = "toggle", order = order, width = "full", name = label, desc = desc,
			get = function() return opts[key] end, set = function(_, v) opts[key] = v end, disabled = disabled }
	end
	toggle("bars", "Action bars", "Every slot of the bars (also the stance / bonus bars) gets the same spell, macro or item. Spells use your highest rank.", 10)
	toggle("clearEmptySlots", "   Also empty the slots that are empty in the setup", "Off: slots that are empty in the setup keep what they have.", 11, function() return not opts.bars end)
	toggle("keybinds", "Keybinds", "Every key binding of the game, including the ones that point to macros, spells and bar buttons.", 20)
	toggle("keepOtherKeybinds", "   Keep my other keybinds (only add the ones of the setup)", nil, 21, function() return not opts.keybinds end)
	toggle("macros", "Macros of the character", "Created, or updated when a macro with the same name exists. Applied before the bars so the bars can use them.", 30)
	toggle("generalMacros", "   Also the general macros", "General macros already belong to the whole account; this updates them by name.", 31, function() return not opts.macros end)
	toggle("deleteOtherMacros", "   Delete the character macros that are not in the setup", nil, 32, function() return not opts.macros end)
	toggle("bindpad", "BindPad profile of the character", "Copies the BindPad slots (and which profile each talent group uses). Needs /reload.", 40,
		function() return not BindPadVars end)
	toggle("profiles", "Addon profiles (Bartender4, BigDebuffs, DBM ...)", "Switches the addons to the profile used by the master character. The profile must exist; nothing is copied, so a change in one place shows on all characters.", 50)
	if snap and opts.profiles then
		local list = {}
		for svn in pairs(snap.profiles) do list[#list + 1] = svn end
		table.sort(list)
		local grp = { type = "group", name = "Addon profiles to switch", order = 60, inline = true, args = {} }
		for i, svn in ipairs(list) do
			grp.args["p" .. i] = { type = "toggle", order = i, width = "double",
				name = svn .. "  ->  " .. tostring(snap.profiles[svn]),
				get = function() return not db.profileOff[svn] end,
				set = function(_, v) db.profileOff[svn] = (not v) or nil end }
		end
		ap.args.profileList = grp
	end
	ap.args.summary = { type = "description", order = 70, fontSize = "medium",
		name = snap and ("Setup '" .. db.selected .. "': " .. Summary(snap) .. (snap.class ~= select(2, UnitClass("player")) and ("\n|cffff5555This setup is from a " .. tostring(snap.class) .. ": the action bars will be skipped.|r") or "")) or "Save a setup first." }
	ap.args.apply = { type = "execute", order = 71, name = "Apply to this character", disabled = function() return not db.selected or not db.snapshots[db.selected] end,
		confirm = true, confirmText = "Replace the chosen things of this character with the setup?",
		func = function() Apply(db.selected) end }
	ap.args.reload = { type = "execute", order = 72, name = "Reload the interface", func = function() ReloadUI() end }
	if db.lastResult then
		ap.args.resultHeader = { type = "header", order = 80, name = "Last result" }
		ap.args.result = { type = "description", order = 81, name = db.lastResult }
	end
	root.args.apply = ap
	return root
end

-- ---------------------------------------------------------------------------------------------------------
-- start-up and commands
-- ---------------------------------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
	if arg1 ~= ADDON then return end
	SkomsProfileSyncDB = SkomsProfileSyncDB or {}
	db = SkomsProfileSyncDB
	db.snapshots = db.snapshots or {}
	db.profileOff = db.profileOff or {}
	db.opts = db.opts or {}
	for k, v in pairs(DEFAULT_OPTS) do if db.opts[k] == nil then db.opts[k] = v end end
	LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON, Options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON, ADDON)
	self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_SKOMSPROFILESYNC1 = "/sps"
SLASH_SKOMSPROFILESYNC2 = "/skomsprofilesync"
SlashCmdList["SKOMSPROFILESYNC"] = function(msg)
	msg = strtrim(msg or "")
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and cmd:lower()
	if cmd == "save" then
		local name = rest ~= "" and rest or (select(2, UnitClass("player")) or "Setup")
		Say(("'%s' saved: %s."):format(name, Summary(Save(name))))
	elseif cmd == "apply" then
		Apply(rest ~= "" and rest or db.selected)
	elseif cmd == "list" then
		local n = 0
		for name, snap in pairs(db.snapshots) do n = n + 1; Say(("%s  from %s: %s"):format(name, snap.char, Summary(snap))) end
		if n == 0 then Say("nothing saved yet.") end
	else
		LibStub("AceConfigDialog-3.0"):Open(ADDON)
	end
end
