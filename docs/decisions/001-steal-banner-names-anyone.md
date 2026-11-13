# 001: The steal banner names anyone, straight from the meter

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

- The banner names whoever takes #1, K-Maxing or not, using the meter's
  (secret) name with `string.format`, never `..`.
- Secret values are only truth-tested or passed to the game, never compared.
- K-Maxing's own "TOP" claims stay as the backup for a meter row with no
  name; a refused claim is retried until the lockdown lifts.

## Not chosen

- Banner for K-Maxing users only (needs a readable name, so only works
  after combat via the claims).
- Matching the meter's spec icon to party members, as Details does for
  GUIDs: not needed once the name itself can be shown.
