# SkomsProfileSync 1.0.0 (WoW 3.3.5a)

Set up one character, then copy that setup to your other characters of the same class: action bars, keybinds, macros, BindPad profile, addon profiles and game settings. Type `/sps`.

## How it works
1. On your main character, open `/sps`, give the setup a name and press **Save this character as a setup**. It is stored for the whole account. Saving again keeps the previous version (the last 5).
2. Log in on another character, open `/sps` > **Apply to this character**, choose the setup and what to copy, press **Apply**, then `/reload`.

## What is copied
- **Action bars:** every slot (also the stance / bonus bars). Spells are matched by name and use the highest rank the character knows; macros by name; items by id. Anything the character does not have yet is skipped and listed. Optional: also empty the slots that are empty in the setup. Skipped when the setup is from another class (unless you force it).
- **Keybinds:** all key bindings of the game, including the ones that point to macros, spells and bar buttons (Bartender4, BindPad). They are always written to the character's own binding set ("character specific key bindings"), never to the account set that other characters may share. Optional: keep the keybinds you already have.
- **Macros** of the character: created as local macros (kept in the game's `macros-cache.txt`), or updated when a macro with the same name exists. Macros that share a name are told apart by their position. Optional: also the general macros, and delete the character macros that are not in the setup. Done before the bars so the bars can use them.
- **BindPad:** the character's BindPad slots and which profile each talent group uses.
- **Addon profiles:** every addon that uses AceDB profiles (Bartender4, BigDebuffs, DBM and many more). When you save, each addon profile in use is copied to a frozen profile called `<name>_sync_<date>_<time>`, so changes you make to your main character afterwards do not change the setup. Applying switches the other characters to that frozen profile (you can untick the addons you do not want). Characters that use it share it, so a change made on one shows on all of them. Deleting a setup removes its frozen profiles when nothing else uses them.
- **Game settings:** the console variables behind the Interface options and the hidden ones (nameplates, camera, chat, combat, tooltips, sound switches ... about 170 of them). Graphics, sound devices and voice chat are not copied. See also SkomsInterfaceOptions.

## Different classes
Action bars, macros and the BindPad profile belong to a class. When the setup is from another class than the character you apply it to, they are skipped, and the Apply tab says so in red. Keybinds, addon profiles and game settings are still copied. Tick **Copy bars, macros and BindPad even if the setup is from another class** to force them.

## Backups
Before every apply, everything of the character it is applied to (bars, keybinds, macros, BindPad, the names of the addon profiles, game settings) is saved; the last 8 backups are kept. **Undo > Restore this backup** puts it all back, including deleting the macros the apply created. `/sps restore` restores the latest one.

Not copied: talents and glyphs (the game does not allow it), and anything that is stored only for one character by an addon (SavedVariablesPerCharacter).

## Commands
`/sps` opens the window. `/sps save <name>`, `/sps apply <name>`, `/sps list`, `/sps restore` (latest backup).

## Install
Put the `SkomsProfileSync` folder in `Interface\AddOns`. It only needs to be on the characters that you use it on (it can stay enabled everywhere).

## Help and feedback
Something that did not copy, or a setup that comes out wrong:
- **GitHub issues:** https://github.com/Ahmedrn/SkomsProfileSync/issues
- **A comment on the Warperia page**
- **Discord:** `skomzx`

## Credits
- **ActionBarSaver** by **Shadowed**: the idea of saving action bars by spell name.
- **Ace3** for the window.
