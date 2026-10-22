# Changelog

## 1.0.0 (2026-10-21)

First release.

- Save a character as a named setup, apply it to other characters of the same account.
- Copies action bars (all 120 slots), keybinds, macros of the character, the BindPad profile, the game settings (console variables of the Interface options), and switches AceDB addon profiles (Bartender4, BigDebuffs, DBM ...).
- Saving makes a frozen copy of every addon profile in use (`<name>_sync_<date>_<time>`) and keeps the previous version of the setup (the last 5). Deleting a setup removes the frozen profiles nobody uses.
- Before every apply, the whole state of the character is saved (the last 8 backups); one button or `/sps restore` puts it back.
- Choose what to copy, with options to keep your other keybinds, empty the slots that are empty in the setup, copy the general macros and delete the other character macros.
- `/sps` opens the window; `/sps save`, `/sps apply`, `/sps list`.
