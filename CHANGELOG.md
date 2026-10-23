# Changelog

## 1.0.0 (2026-10-21)

First release.

- An About tab in the options: how to get help (GitHub issues, Warperia, Discord) and the other addons by Skom, with what is installed. ArenaLFG is marked as Warmane only.
- Save a character as a named setup, apply it to other characters of the same account.
- Copies action bars (all 120 slots), keybinds, macros of the character, the BindPad profile, the game settings (console variables of the Interface options, show helm / cloak, the extra action bars, the modifier keys), and switches AceDB addon profiles (Bartender4, BigDebuffs, DBM ...).
- Saving makes a frozen copy of every addon profile in use (`<name>_sync_<date>_<time>`) and keeps the previous version of the setup (the last 5). Deleting a setup removes the frozen profiles nobody uses.
- Action bars, macros and the BindPad profile are skipped when the setup is from another class (an option forces them).
- Storage > Delete profiles by hand: pick an addon, see who uses each of its profiles, tick and delete the ones you do not need (the profile the current character uses is never listed). The deletion can be undone like the cleanup.
- Frozen profiles are now called `Sync_<setup>` (`Sync_<setup> v2`, `v3` ... for later saves) instead of `<setup>_sync_<date>_<time>`; the old ones are still recognised. When the list of unused profiles is empty, the page says how many are kept by setups, older versions or backups.
- Storage > Unused profiles lists the addon profiles that no character, setup, older version or backup uses (the frozen copies only, or every unused profile of every addon), deletes them on request, keeps a list of names that are never deleted ("Default" by default) and can restore the last cleanup.
- A Storage tab shows what is stored, sets how many versions and backups are kept, and deletes the unused frozen profiles. A save that changes nothing in an addon reuses its previous frozen profile.
- Before every apply, the whole state of the character is saved (the last 8 backups); one button or `/sps restore` puts it back.
- The Apply tab opens first, with the Apply button right under the setup choice and the result below it; the list of what to copy comes after.
- Choose what to copy, with options to keep your other keybinds, empty the slots that are empty in the setup, copy the general macros and delete the other character macros.
- `/sps` opens the window; `/sps save`, `/sps apply`, `/sps list`.
