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

## Update 2026-11-19: never name the player who lost #1

In game, 1.1.0 named Kain on every steal. The rig only ever had one meter
row and never showed it. The name now comes from:

- The game's ranked rows, `C_DamageMeter.GetCombatSessionFromType(Current,
  DamageDone).combatSources[1]`, as Details! reads them. The meter window
  (`DamageMeterSessionWindow1`) is only the fallback.
- The K-Maxing user list when one user in the group plays the thief's
  class. That name is plain and can never be ours (our own hello is ignored).
- The meter's name only for two K-Maxing users of the same class. A
  readable answer (row name or `UnitNameFromGUID`) that is our own name is
  dropped, since that row is never us.

The cause in game: Forever writes names as "Name Realm" (a space), and
the self check only cut at "-", so our own party messages (which come back
to us) counted as another K-Maxing user of our class, and our own "TOP"
claim as the thief's. Names are now cut at "-" or " " (`ShortName`), and
every message from us is dropped first (`IsMe`).

`tests/self_name_sim.lua` covers each way the meter could hand back our name.

## Not chosen

- Banner for anyone who takes #1 (Kain's first pick, reversed the same day).
- Matching the spec icon as well, as Details does for GUIDs: would split
  same-class players, but Details notes the icon can be secret in combat.
  Worth adding if same-class groups come up often.
