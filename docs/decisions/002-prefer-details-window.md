# 002: Follow the Details! window when Details is loaded

Date: 2026-11-20. Asked for by Kain: many testers read Details! instead of
Forever's own damage meter.

## Context

On Forever, Details! has no combat log to parse. It reads the same game rows
K-Maxing already reads (`C_DamageMeter.GetCombatSessionFromType` /
`GetCombatSessionFromID`), in the game's order, with the same secret names.
What differs is the view: each Details window picks its own fight (this fight,
Overall, or an older one) and its own display (Damage Done, DPS, healing...).
A tester watching Details at DPS, or on a fight the game's meter isn't on,
could see a different #1 from the one K-Maxing reacted to.

## Decision

- When `_G.Details` is loaded, K-Maxing reads row 1 of the first open Details
  window (`Details:GetInstance(id)`, `IsEnabled()`) that shows Damage Done or
  DPS (`GetDisplay()` = 1, 1 or 1, 2) on this fight (`GetSegmentType()` = 1),
  through that window's own `GetSegmentObject()`.
- Any other view, a closed window, an empty window or an error falls back to
  the game's rows, then the game's meter window, as before. The rows are the
  game's own tables, so the secret-value rules from decision 001 still apply.
- `/bmdiag` and `/kmax debug` name the source being read.

## Not chosen

- Following Overall or an older fight: K-Maxing is about #1 in this fight,
  and an Overall #1 at the start of a pull would end the music at once.
- Reading Details' private tables (`Details222`): not reachable from another
  addon, and the window's public methods give the same rows.
