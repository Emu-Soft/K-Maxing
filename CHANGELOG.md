# Changelog

Newest first. Each version has up to three sections: New, Changed, Fixed. The release button builds each GitHub release's description from this file.

## Unreleased

### New
- `/kmax fake <name>` pretends a K-Maxing user took #1 from you each time you lose it, for testing the steal banner without a second K-Maxing user. `/kmax fake off` stops it.
- `/kmax lose` pretends someone passed you on the meter until combat ends, so you can test losing #1 on your own. `/kmax lose off` stops it early.

### Fixed
- Avada Balenciaga now names the thief in combat. The damage meter hides names there, so the K-Maxing user who takes #1 now tells the group themselves.
- If the game holds addon messages back during a dungeon fight, the steal banner now shows once the fight ends instead of never.
- Taking #1 while the game is holding addon messages back no longer stops the music from starting.

## 1.0.1

### Changed
- The download now has the version number in its name, so WowUp shows which version you have.

## 1.0

### New
- First release on GitHub.
- Top the damage meter in a 5-player dungeon to start the music, the pulsing logo and the #1 timer.
- Avada Balenciaga: when another K-Maxing user steals your top spot, you'll know who did it.
- `/kmax` options: fonts, sizes, previews, and frames you can drag into place.
