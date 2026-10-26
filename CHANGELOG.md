# Changelog

## 1.1.1 (2026-10-26)

- The addon list shows a readable name ("Skom's Profile Sync"). The About tab uses those names, and lists Skom's Arena Stats (marked as Warmane only).

## 1.1.0 (2026-10-23)

- Frozen profiles are now called `Sync_<setup>` (`Sync_<setup> v2` ... for later saves); the old names are still recognised.
- Storage > Delete profiles by hand: pick an addon, see who uses each profile, tick and delete the ones you do not need (undo like the cleanup). Buttons tick the unused ones, the ones no character has selected, and the ones of other servers (an editable list of this server's realms).
- The Save a setup tab explains what a setup holds and how versions and cleanup work.
- Action bars: a slot that differs is emptied before the new spell or macro is placed, so a full slot no longer ends up wrong.
- Macros: no attempt to create a macro when the character's list is full (it could leave a stray copy in the general macros).
- Logo.

## 1.0.0 (2026-10-21)

First release.

- An About tab in the options: how to get help (GitHub issues, Warperia, Discord) and the other addons by Skom, with what is installed. ArenaLFG is marked as Warmane only.
- Save a character as a named setup, apply it to other characters of the same account.
- Copies action bars (all 120 slots), keybinds, macros of the character, the BindPad profile, the game settings (console variables of the Interface options, show helm / cloak, the extra action bars, the modifier keys), and switches AceDB addon profiles (Bartender4, BigDebuffs, DBM ...).
- Saving makes a frozen copy of every addon profile in use (`<name>_sync_<date>_<time>`) and keeps the previous version of the setup (the last 5). Deleting a setup removes the frozen profiles nobody uses.
- Action bars, macros and the BindPad profile are skipped when the setup is from another class (an option forces them).
- Storage > Unused profiles lists the addon profiles that no character, setup, older version or backup uses (the frozen copies only, or every unused profile of every addon), deletes them on request, keeps a list of names that are never deleted ("Default" by default) and can restore the last cleanup.
- A Storage tab shows what is stored, sets how many versions and backups are kept, and deletes the unused frozen profiles. A save that changes nothing in an addon reuses its previous frozen profile.
- Before every apply, the whole state of the character is saved (the last 8 backups); one button or `/sps restore` puts it back.
- The Apply tab opens first, with the Apply button right under the setup choice and the result below it; the list of what to copy comes after.
- Choose what to copy, with options to keep your other keybinds, empty the slots that are empty in the setup, copy the general macros and delete the other character macros.
- `/sps` opens the window; `/sps save`, `/sps apply`, `/sps list`.
