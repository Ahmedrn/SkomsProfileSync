-- SkomsProfileSync: set up one character, then copy its action bars, keybinds, macros, BindPad profile and addon
-- profiles to your other characters (same account). 3.3.5a.
local ADDON, ns = ...

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
	cvars = true,
	forceOtherClass = false,
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
				-- in this client the id of a spell action is the place of the spell in the spellbook, not its spell id
				local name = GetSpellName(id, BOOKTYPE_SPELL) or GetSpellInfo(id)
				if name then bars[slot] = { t = "spell", name = name } end
			elseif kind == "macro" and id then
				local name = GetMacroInfo(id)
				if name then
					local perChar = id > MAX_ACCOUNT
					local nth = 0
					for i = perChar and (MAX_ACCOUNT + 1) or 1, id - 1 do
						if GetMacroInfo(i) == name then nth = nth + 1 end
					end
					bars[slot] = { t = "macro", name = name, perChar = perChar, nth = nth }
				end
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

-- a game setting by name; this client raises an error for a name that is not a console variable
local function Get(cv)
	local ok, v = pcall(GetCVar, cv)
	if ok then return v end
end

local function ReadCVars()
	local t = {}
	for _, name in ipairs(ns.CVarNames or {}) do
		local v = Get(name)
		if v ~= nil then t[name] = tostring(v) end
	end
	return t
end

local MOD_CLICKS = { "AUTOLOOTTOGGLE", "SELFCAST", "FOCUSCAST", "PICKUPACTION", "CHATLINK", "COMPAREITEMS", "DRESSUP",
	"SPLITSTACK", "STICKYCAMERA", "SOCKETITEM", "QUESTWATCHTOGGLE", "TOKENWATCHTOGGLE" }

-- the Interface options that are not console variables: show helm / cloak, the extra action bars, the modifier keys
local function ReadMisc()
	local m = { clicks = {} }
	if ShowingHelm then m.helm = ShowingHelm() and 1 or 0 end
	if ShowingCloak then m.cloak = ShowingCloak() and 1 or 0 end
	if GetActionBarToggles then
		local b1, b2, b3, b4 = GetActionBarToggles()
		m.bars = { b1 and 1 or 0, b2 and 1 or 0, b3 and 1 or 0, b4 and 1 or 0 }
	end
	for _, action in ipairs(MOD_CLICKS) do
		local ok, key = pcall(GetModifiedClick, action)
		if ok and key then m.clicks[action] = key end
	end
	return m
end

local function ReadAll()
	local _, class = UnitClass("player")
	return {
		class = class, char = PlayerKey(), date = date("%Y-%m-%d %H:%M"),
		bindings = ReadBindings(), macros = ReadMacros(), bars = ReadBars(),
		profiles = ReadProfiles(), bindpad = ReadBindPad(), cvars = ReadCVars(), misc = ReadMisc(),
	}
end

local function KeepVersions() return db.keepVersions or 5 end
local function KeepBackups() return db.keepBackups or 8 end

-- rough size of a table in the saved file (about 16 bytes per value or key)
local function Nodes(t, seen)
	if type(t) ~= "table" then return 1 end
	seen = seen or {}
	if seen[t] then return 0 end
	seen[t] = true
	local n = 1
	for _, v in pairs(t) do n = n + 2 + Nodes(v, seen) - 1 end
	return n
end

local function DeepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not DeepEqual(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

local function EachDB(fn)
	local AceDB = LibStub and LibStub("AceDB-3.0", true)
	if not (AceDB and AceDB.db_registry) then return end
	for dbo in pairs(AceDB.db_registry) do
		if type(dbo) == "table" and not dbo.parent and dbo.sv and dbo.GetCurrentProfile then
			local svn = SVName(dbo.sv)
			if svn then fn(dbo, svn) end
		end
	end
end

-- a frozen copy of a profile (and of its part in every namespace): the saved setup keeps its own, later changes of the character do not touch it
local function CopyProfileData(dbo, from, to)
	local sv = dbo.sv
	sv.profiles = sv.profiles or {}
	sv.profiles[to] = Copy(sv.profiles[from] or {})
	if sv.namespaces then
		for _, nsv in pairs(sv.namespaces) do
			if type(nsv) == "table" and nsv.profiles and nsv.profiles[from] then nsv.profiles[to] = Copy(nsv.profiles[from]) end
		end
	end
end

local function ProfileInUse(svn, pname, dbo)
	if dbo:GetCurrentProfile() == pname then return true end
	for _, v in pairs(dbo.sv.profileKeys or {}) do
		if v == pname then return true end
	end
	local function uses(snap) return snap and snap.profiles and snap.profiles[svn] == pname end
	for _, snap in pairs(db.snapshots) do if uses(snap) then return true end end
	for _, list in pairs(db.history) do
		for _, snap in ipairs(list) do if uses(snap) then return true end end
	end
	for _, snap in ipairs(db.backups) do if uses(snap) then return true end end
	return false
end

-- the frozen profiles of a setup that was removed from the list, when nothing else uses them
local function DropSyncProfiles(snap)
	EachDB(function(dbo, svn)
		local pname = snap.profiles and snap.profiles[svn]
		if pname and pname:find("_sync_", 1, true) and not ProfileInUse(svn, pname, dbo) then
			if dbo.sv.profiles then dbo.sv.profiles[pname] = nil end
			for _, nsv in pairs(dbo.sv.namespaces or {}) do
				if type(nsv) == "table" and nsv.profiles then nsv.profiles[pname] = nil end
			end
		end
	end)
end

local function Save(name)
	local snap = ReadAll()
	snap.name = name
	local stamp = date("%Y%m%d_%H%M")
	local frozen = 0
	local old = db.snapshots[name]
	EachDB(function(dbo, svn)
		local cur = snap.profiles[svn]
		if cur then
			local prev = old and old.profiles and old.profiles[svn]
			local sv = dbo.sv
			local same = prev and prev:find("_sync_", 1, true) and sv.profiles and sv.profiles[prev]
				and DeepEqual(sv.profiles[cur] or {}, sv.profiles[prev])
			if same then
				snap.profiles[svn] = prev      -- nothing changed since the last save: the same frozen profile
			else
				local new = ("%s_sync_%s"):format(name, stamp)
				CopyProfileData(dbo, cur, new)
				snap.profiles[svn] = new
				frozen = frozen + 1
			end
		end
	end)
	snap.frozen = frozen
	if old then
		-- the previous version is kept
		db.history[name] = db.history[name] or {}
		table.insert(db.history[name], 1, old)
		while #db.history[name] > KeepVersions() do DropSyncProfiles(table.remove(db.history[name])) end
	end
	db.snapshots[name] = snap
	db.selected = name
	return snap
end

-- everything of the current character as it is now, taken before an apply
local function PushBackup()
	local b = ReadAll()
	table.insert(db.backups, 1, b)
	while #db.backups > KeepBackups() do table.remove(db.backups) end
	return b
end

-- every frozen profile in the other addons' files; remove = true deletes the ones nothing uses
local function ScanFrozen(remove)
	local total, orphans, nodes = 0, 0, 0
	EachDB(function(dbo, svn)
		for pname in pairs(dbo.sv.profiles or {}) do
			if type(pname) == "string" and pname:find("_sync_", 1, true) then
				total = total + 1
				nodes = nodes + Nodes(dbo.sv.profiles[pname])
				for _, nsv in pairs(dbo.sv.namespaces or {}) do
					if type(nsv) == "table" and nsv.profiles and nsv.profiles[pname] then nodes = nodes + Nodes(nsv.profiles[pname]) end
				end
				if not ProfileInUse(svn, pname, dbo) then
					orphans = orphans + 1
					if remove then
						dbo.sv.profiles[pname] = nil
						for _, nsv in pairs(dbo.sv.namespaces or {}) do
							if type(nsv) == "table" and nsv.profiles then nsv.profiles[pname] = nil end
						end
					end
				end
			end
		end
	end)
	return total, orphans, nodes
end

-- apply the limits to what is stored
local function Trim()
	for _, list in pairs(db.history) do
		while #list > KeepVersions() do DropSyncProfiles(table.remove(list)) end
	end
	while #db.backups > KeepBackups() do table.remove(db.backups) end
end

local function GetSnap(key)
	if not key then return nil end
	if db.snapshots[key] then return db.snapshots[key] end
	local n, i = key:match("^(.*)#(%d+)$")
	return n and db.history[n] and db.history[n][tonumber(i)] or nil
end

local function Summary(snap)
	local charMacros = 0
	for _, m in ipairs(snap.macros) do if m.perChar then charMacros = charMacros + 1 end end
	return ("%d action slots, %d keybinds, %d macros (%d of the character), %d addon profiles, %d game settings%s"):format(
		CountKeys(snap.bars), #snap.bindings, #snap.macros, charMacros, CountKeys(snap.profiles), CountKeys(snap.cvars), snap.bindpad and ", a BindPad profile" or "")
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

-- the macro called name: perChar true = character macros, false = general, nil = any; nth = which one if several share the name
local function FindMacro(name, perChar, nth)
	local first, last = 1, MAX_ACCOUNT + MAX_CHAR
	if perChar == true then first = MAX_ACCOUNT + 1 elseif perChar == false then last = MAX_ACCOUNT end
	local seen = 0
	for i = first, last do
		if GetMacroInfo(i) == name then
			if seen == (nth or 0) then return i end
			seen = seen + 1
		end
	end
end

local function ApplyMacros(snap, o)
	local made, edited, same, failed, deleted = 0, 0, 0, 0, 0
	local claimed = {}
	local function range(perChar)
		if perChar then return MAX_ACCOUNT + 1, MAX_ACCOUNT + MAX_CHAR end
		return 1, MAX_ACCOUNT
	end
	-- an existing macro of the same name that no earlier macro of the setup has taken (same body first)
	local function Find(m)
		local first, last = range(m.perChar)
		for i = first, last do
			local n, _, b = GetMacroInfo(i)
			if n == m.name and b == m.body and not claimed[i] then return i, true end
		end
		for i = first, last do
			local n = GetMacroInfo(i)
			if n == m.name and not claimed[i] then return i, false end
		end
	end
	-- the macros are local ones (kept in macros-cache.txt); the second variant is for clients with the other argument order
	local function Create(m)
		local perChar = m.perChar and 1 or nil
		local variants = {
			function(icon) return CreateMacro(m.name, icon, m.body, 1, perChar) end,
			function(icon) return CreateMacro(m.name, icon, m.body, nil, perChar) end,
		}
		for _, variant in ipairs(variants) do
			for _, icon in ipairs({ m.icon or "INV_Misc_QuestionMark", IconIndex(m.icon) }) do
				local a1, c1 = GetNumMacros()
				pcall(variant, icon)
				local a2, c2 = GetNumMacros()
				if (m.perChar and c2 > c1) or (not m.perChar and a2 > a1) then
					local idx = Find(m)
					if idx then return idx end
				elseif c2 > c1 and not m.perChar then
					DeleteMacro(MAX_ACCOUNT + c2)      -- made a character macro by mistake
				elseif a2 > a1 and m.perChar then
					DeleteMacro(a2)                    -- made a general macro by mistake
				end
			end
		end
	end
	for _, m in ipairs(snap.macros) do
		if m.perChar or o.generalMacros then
			local idx, exact = Find(m)
			if idx then
				claimed[idx] = true
				if exact then
					same = same + 1
				else
					pcall(EditMacro, idx, m.name, m.icon, m.body)
					if select(3, GetMacroInfo(idx)) ~= m.body then pcall(EditMacro, idx, m.name, IconIndex(m.icon), m.body) end
					edited = edited + 1
				end
			else
				idx = Create(m)
				if idx then claimed[idx] = true; made = made + 1 else failed = failed + 1 end
			end
		end
	end
	if o.deleteOtherMacros then
		local _, numChar = GetNumMacros()
		for i = MAX_ACCOUNT + numChar, MAX_ACCOUNT + 1, -1 do
			if GetMacroInfo(i) and not claimed[i] then DeleteMacro(i); deleted = deleted + 1 end
		end
	end
	Report(("Macros: %d created, %d updated, %d already right%s%s."):format(made, edited, same,
		failed > 0 and (", " .. failed .. " could not be created (full?)") or "", deleted > 0 and (", " .. deleted .. " deleted") or ""))
end

local function ApplyBindings(snap, o)
	-- always the character's own set: the account set belongs to every character that has none of its own
	LoadBindings(2)
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
	SaveBindings(2)
	Report(("Keybinds: %d keys set (for this character only)."):format(n))
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
	if e.t == "spell" and kind == "spell" then return (GetSpellName(id, BOOKTYPE_SPELL) or GetSpellInfo(id)) == e.name end
	if e.t == "macro" and kind == "macro" then return id == FindMacro(e.name, e.perChar, e.nth) end
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
					local idx = FindMacro(e.name, e.perChar, e.nth)
					if idx then PickupMacro(idx) end
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

local function ApplyProfiles(snap, all)
	local AceDB = LibStub and LibStub("AceDB-3.0", true)
	if not AceDB or not AceDB.db_registry then Report("Addon profiles: AceDB not found.") return end
	local switched, skipped = 0, {}
	for dbo in pairs(AceDB.db_registry) do
		if type(dbo) == "table" and not dbo.parent and dbo.sv and dbo.GetCurrentProfile then
			local svn = SVName(dbo.sv)
			local want = svn and snap.profiles[svn]
			if want and (all or not db.profileOff[svn]) then
				if dbo:GetCurrentProfile() == want then
					-- already the same
				else
					local ok = pcall(dbo.SetProfile, dbo, want)
					if ok then switched = switched + 1 else skipped[#skipped + 1] = svn end
				end
			end
		end
	end
	Report(("Addon profiles: %d switched%s."):format(switched, #skipped > 0 and (", failed: " .. table.concat(skipped, ", ")) or ""))
end

local RESTORE_OPTS = { bars = true, clearEmptySlots = true, keybinds = true, keepOtherKeybinds = false, macros = true,
	generalMacros = true, deleteOtherMacros = true, bindpad = true, profiles = true, cvars = true }

local function ApplySnap(snap, label, o, isRestore)
	if InCombatLockdown() then Say("Not in combat.") return end
	if runner:IsShown() then Say("Already applying.") return end
	local _, class = UnitClass("player")
	local sameClass = (snap.class == class)
	wipe(steps); wipe(report)
	if not isRestore then PushBackup() end
	Report(("%s '%s' (from %s) on %s."):format(isRestore and "Restoring" or "Applying", label, snap.char, PlayerKey()))

	-- bars, macros and BindPad belong to a class: from another class they are only copied when the user forces it
	local allowed = sameClass or o.forceOtherClass
	if not allowed then
		Report(("Skipped because the setup is from a %s and this is a %s: action bars, macros and BindPad (you can force it in /sps, Apply tab)."):format(
			tostring(snap.class), tostring(class)))
	end

	if o.macros and allowed then steps[#steps + 1] = function() ApplyMacros(snap, o) end end
	if o.keybinds then steps[#steps + 1] = function() ApplyBindings(snap, o) end end
	if o.bars and allowed then
		do
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
	if o.bindpad and allowed and snap.bindpad then
		steps[#steps + 1] = function()
			if BindPadVars then
				BindPadVars[BindPadKey()] = Copy(snap.bindpad)
				Report("BindPad: profile copied (visible after /reload).")
			else
				Report("BindPad is not loaded.")
			end
		end
	end
	if o.cvars and snap.cvars then
		steps[#steps + 1] = function()
			local n = 0
			for name, v in pairs(snap.cvars) do
				local cur = Get(name)
				if cur ~= nil and tostring(cur) ~= v then pcall(SetCVar, name, v); n = n + 1 end
			end
			local extra = {}
			local m = snap.misc
			if m then
				if m.helm ~= nil and pcall(ShowHelm, m.helm) then extra[#extra + 1] = "helm" end
				if m.cloak ~= nil and pcall(ShowCloak, m.cloak) then extra[#extra + 1] = "cloak" end
				if m.bars and SetActionBarToggles then
					local always = snap.cvars and snap.cvars.alwaysShowActionBars == "1" and 1 or nil
					if pcall(SetActionBarToggles, m.bars[1] == 1 and 1 or nil, m.bars[2] == 1 and 1 or nil, m.bars[3] == 1 and 1 or nil,
						m.bars[4] == 1 and 1 or nil, always) then
						extra[#extra + 1] = "extra bars"
						if MultiActionBar_Update then pcall(MultiActionBar_Update) end
						if UIParent_ManageFramePositions then pcall(UIParent_ManageFramePositions) end
					end
				end
				local clicks = 0
				for action, key in pairs(m.clicks or {}) do
					if pcall(SetModifiedClick, action, key) then clicks = clicks + 1 end
				end
				if clicks > 0 then
					pcall(SaveBindings, GetCurrentBindingSet())
					extra[#extra + 1] = clicks .. " modifier keys"
				end
			end
			Report(("Game settings: %d changed%s."):format(n, #extra > 0 and (", plus " .. table.concat(extra, ", ")) or ""))
		end
	end
	if o.profiles then steps[#steps + 1] = function() ApplyProfiles(snap, isRestore) end end
	if not isRestore then
		steps[#steps + 1] = function() Report("To undo everything: /sps restore, or Undo in the options.") end
	end
	runner:Show()
end

local function Apply(key)
	local snap = GetSnap(key)
	if not snap then Say("No saved setup called '" .. tostring(key) .. "'.") return end
	ApplySnap(snap, snap.name or key, db.opts)
end

local function RestoreBackup(index)
	local b = db.backups[index or 1]
	if not b then Say("No backup yet.") return end
	ApplySnap(b, "backup of " .. b.date, RESTORE_OPTS, true)
end

-- ---------------------------------------------------------------------------------------------------------
-- options window
-- ---------------------------------------------------------------------------------------------------------
local function SnapshotValues()
	local v = {}
	for name, snap in pairs(db.snapshots) do v[name] = ("%s  (%s)"):format(name, snap.char) end
	for name, list in pairs(db.history) do
		for i, snap in ipairs(list) do v[name .. "#" .. i] = ("%s  older version, %s"):format(name, snap.date or "?") end
	end
	if next(v) == nil then v["_none"] = "Nothing saved yet" end
	return v
end

local function BackupValues()
	local v = {}
	for i, b in ipairs(db.backups) do v[i] = ("%s  %s"):format(b.date or "?", b.char or "?") end
	if next(v) == nil then v[0] = "No backup yet" end
	return v
end

local function Options()
	local opts = db.opts
	local newName = db.newName
	local root = { type = "group", name = "SkomsProfileSync", childGroups = "tab", args = {} }

	-- tab 1: save
	local save = { type = "group", name = "Save a setup", order = 1, args = {} }
	save.args.info = { type = "description", order = 1, fontSize = "medium",
		name = "Set up one character the way you like (action bars, keybinds, macros, BindPad, addon profiles, game settings), then save it here. "
			.. "The setup is kept for the whole account, so you can apply it to your other characters.\n\n"
			.. "Every save also makes a frozen copy of each addon profile, called <name>_sync_<date>_<time>, so later changes to this character do not change the setup. "
			.. "The previous version of a setup is kept (the last " .. KeepVersions() .. ").\n\nThis character: " .. PlayerKey() }
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
			confirm = true, confirmText = "Delete the setup '" .. name .. "' with its older versions and frozen addon profiles?",
			func = function()
				local old = db.snapshots[name]
				db.snapshots[name] = nil
				local hist = db.history[name]
				db.history[name] = nil
				if db.selected and (db.selected == name or db.selected:sub(1, #name + 1) == name .. "#") then db.selected = nil end
				if old then DropSyncProfiles(old) end
				for _, h in ipairs(hist or {}) do DropSyncProfiles(h) end
			end }
	end
	if n == 0 then save.args.none = { type = "description", order = 11, name = "Nothing saved yet." } end
	root.args.save = save

	-- tab 2: apply
	local ap = { type = "group", name = "Apply to this character", order = 2, args = {} }
	local snap = GetSnap(db.selected)
	ap.args.info = { type = "description", order = 1, fontSize = "medium",
		name = "This character: " .. PlayerKey() .. "\nChoose a saved setup and what to copy, then press Apply. Your current choices are replaced." }
	ap.args.select = { type = "select", order = 2, name = "Setup", width = "double", values = SnapshotValues,
		get = function() return db.selected end, set = function(_, v) if v ~= "_none" then db.selected = v end end,
		disabled = function() return next(db.snapshots) == nil end }
	local function toggle(key, label, desc, order, disabled)
		ap.args[key] = { type = "toggle", order = order, width = "full", name = label, desc = desc,
			get = function() return opts[key] end, set = function(_, v) opts[key] = v end, disabled = disabled }
	end
	toggle("forceOtherClass", "Copy bars, macros and BindPad even if the setup is from another class", "Off (default): when the class of the setup is not the class of this character, the action bars, the macros and the BindPad profile are skipped; keybinds, addon profiles and game settings are still copied.", 5)
	toggle("bars", "Action bars", "Every slot of the bars (also the stance / bonus bars) gets the same spell, macro or item. Spells use your highest rank.", 10)
	toggle("clearEmptySlots", "   Also empty the slots that are empty in the setup", "Off: slots that are empty in the setup keep what they have.", 11, function() return not opts.bars end)
	toggle("keybinds", "Keybinds", "Every key binding of the game, including the ones that point to macros, spells and bar buttons.", 20)
	toggle("keepOtherKeybinds", "   Keep my other keybinds (only add the ones of the setup)", nil, 21, function() return not opts.keybinds end)
	toggle("macros", "Macros of the character", "Created, or updated when a macro with the same name exists. Applied before the bars so the bars can use them.", 30)
	toggle("generalMacros", "   Also the general macros", "General macros already belong to the whole account; this updates them by name.", 31, function() return not opts.macros end)
	toggle("deleteOtherMacros", "   Delete the character macros that are not in the setup", nil, 32, function() return not opts.macros end)
	toggle("bindpad", "BindPad profile of the character", "Copies the BindPad slots (and which profile each talent group uses). Needs /reload.", 40,
		function() return not BindPadVars end)
	toggle("cvars", "Game settings (interface options)", "The console variables of the Interface options and of the hidden ones: nameplates, camera, chat, combat, tooltips, sound switches ... The graphics, sound devices and voice chat settings are not copied.", 45)
	toggle("profiles", "Addon profiles (Bartender4, BigDebuffs, DBM ...)", "Switches the addons to the frozen profile that was saved with the setup. Nothing is copied again: characters that use it share it, so a change made on one shows on all of them.", 50)
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
		name = snap and ("Setup '" .. (snap.name or db.selected) .. "': " .. Summary(snap) .. (snap.class ~= select(2, UnitClass("player")) and ("\n|cffff5555This setup is from a " .. tostring(snap.class) .. (opts.forceOtherClass and ": copied anyway, as you chose.|r" or ": the action bars, macros and BindPad will be skipped.|r")) or "")) or "Save a setup first." }
	ap.args.apply = { type = "execute", order = 71, name = "Apply to this character", disabled = function() return not GetSnap(db.selected) end,
		confirm = true, confirmText = "Replace the chosen things of this character with the setup?",
		func = function() Apply(db.selected) end }
	ap.args.undoHeader = { type = "header", order = 73, name = "Undo" }
	ap.args.undoInfo = { type = "description", order = 74, name = "Before every apply, everything of this character (bars, keybinds, macros, BindPad, addon profile names, game settings) is saved. The last " .. KeepBackups() .. " backups are kept." }
	ap.args.undoSel = { type = "select", order = 75, name = "Backup", width = "double", values = BackupValues,
		get = function()
			if #db.backups == 0 then return 0 end
			return math.min(db.undoSel or 1, #db.backups)
		end,
		set = function(_, v) if v > 0 then db.undoSel = v end end,
		disabled = function() return #db.backups == 0 end }
	ap.args.undo = { type = "execute", order = 76, name = "Restore this backup", disabled = function() return #db.backups == 0 end,
		confirm = true, confirmText = "Put back everything of the backup (macros created since then are deleted)?",
		func = function() RestoreBackup(math.min(db.undoSel or 1, #db.backups)) end }
	ap.args.reload = { type = "execute", order = 72, name = "Reload the interface", func = function() ReloadUI() end }
	if db.lastResult then
		ap.args.resultHeader = { type = "header", order = 80, name = "Last result" }
		ap.args.result = { type = "description", order = 81, name = db.lastResult }
	end
	root.args.apply = ap

	-- tab 3: storage
	local st = { type = "group", name = "Storage", order = 3, args = {} }
	st.args.info = { type = "description", order = 1, fontSize = "medium",
		name = function()
			local versions = 0
			for _, list in pairs(db.history) do versions = versions + #list end
			local total, orphans, nodes = ScanFrozen(false)
			return ("Setups: %d, older versions: %d, backups: %d.\nStored by this addon: about %d KB.\n"
				.. "Frozen addon profiles in the files of the other addons: %d (about %d KB), %d of them used by nothing."):format(
				CountKeys(db.snapshots), versions, #db.backups, math.floor(Nodes(db) * 16 / 1024), total, math.floor(nodes * 16 / 1024), orphans)
		end }
	st.args.keepVersions = { type = "range", order = 2, name = "Older versions kept per setup", width = "double", min = 0, max = 10, step = 1,
		desc = "Saving a setup again keeps its previous version. Older ones are deleted, with the frozen addon profiles nothing else uses.",
		get = function() return KeepVersions() end, set = function(_, v) db.keepVersions = v; Trim() end }
	st.args.keepBackups = { type = "range", order = 3, name = "Backups kept", width = "double", min = 1, max = 20, step = 1,
		desc = "A backup of the character is made before every apply.",
		get = function() return KeepBackups() end, set = function(_, v) db.keepBackups = v; Trim() end }
	st.args.clean = { type = "execute", order = 4, name = "Delete the frozen profiles that nothing uses",
		desc = "Frozen profiles (named ..._sync_...) that no saved setup, older version, backup or character uses. Safe to delete.",
		func = function()
			local _, removed = ScanFrozen(true)
			Say(removed .. " unused frozen profile(s) deleted.")
			LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON)
		end }
	st.args.note = { type = "description", order = 5,
		name = "A save that changes nothing in an addon's profile reuses the previous frozen profile instead of making a new one." }
	root.args.storage = st
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
	db.history = db.history or {}
	db.backups = db.backups or {}
	db.macroBackup = nil
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
	elseif cmd == "bars" then
		-- the spells, items and companions saved on the bars (macros are counted)
		local snap = GetSnap(rest ~= "" and rest or db.selected)
		if not snap then Say("No saved setup.") return end
		local macros = 0
		local slots = {}
		for slot in pairs(snap.bars) do slots[#slots + 1] = slot end
		table.sort(slots)
		for _, slot in ipairs(slots) do
			local e = snap.bars[slot]
			if e.t == "macro" then macros = macros + 1 else Say(("slot %d: %s %s"):format(slot, e.t, tostring(e.name or e.id))) end
		end
		Say(("%d macros on the bars."):format(macros))
	elseif cmd == "restore" then
		RestoreBackup(tonumber(rest) or 1)
	elseif cmd == "list" then
		local n = 0
		for name, snap in pairs(db.snapshots) do n = n + 1; Say(("%s  from %s: %s"):format(name, snap.char, Summary(snap))) end
		if n == 0 then Say("nothing saved yet.") end
	else
		LibStub("AceConfigDialog-3.0"):Open(ADDON)
	end
end
