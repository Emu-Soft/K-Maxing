# 001: The steal banner names K-Maxing users, straight from the meter

Date: 2026-11-13. Decided by Kain.

## Context

In combat (and dungeon lockdown) Forever's damage meter gives addons every
name and GUID as a SECRET value: it can't be compared, used as a table key
or joined with `..`. Up to 1.0.1 the banner only fired for K-Maxing users,
which needs the name as a table key, so it never fired in combat. Addon
messages are also refused during lockdown (`AddOnMessageLockdown`, 11).

Details! shows the way round it: it never reads the names, it hands the
secret straight to the game, `SetText(format("%d. %s", rank, name))`, and
strips the realm with `UnitNameFromGUID(guid)`, which accepts a secret GUID.

## Decision

- The banner shows the meter's (secret) name with `string.format`, never
  `..`. Kain first chose "anyone who takes #1", then asked to keep it to
  K-Maxing users, so:
- K-Maxing users say hello with their class ("USER:MAGE") out of combat.
  The meter's `classFilename` stays readable in combat; when every other
  group member of that class runs K-Maxing, the new #1 is a user.
- Secret values are only truth-tested or passed to the game, never compared.
- When the class can't settle it (same class, hidden class, no name), the
  K-Maxing user's own "TOP" claim names them; a refused claim is retried
  until the fight ends. No banner after the fight (Kain: "We don't need a
  banner after the fight").

## Not chosen

- Banner for anyone who takes #1 (Kain's first pick, reversed the same day).
- Matching the spec icon as well, as Details does for GUIDs: would split
  same-class players, but Details notes the icon can be secret in combat.
  Worth adding if same-class groups come up often.
