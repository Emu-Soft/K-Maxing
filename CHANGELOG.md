# Changelog

Newest first. Each version has up to three sections: New, Changed, Fixed. The release button builds each GitHub release's description from this file.

## 1.1.0

### New
- `/kmax fake <name>` pretends a K-Maxing user claimed #1 each time you lose it, for testing the backup path when the meter gives no name. `/kmax fake off` stops it.
- `/kmax debug` prints each step of working out who took #1.
- `/kmax lose [name]` pretends someone passed you on the meter until combat ends, so you can test losing #1 on your own. `/kmax lose off` stops it early.

### Fixed
- Avada Balenciaga now names the thief in combat, dungeon lockdown included. The name comes straight from the damage meter, and its class column tells K-Maxing users apart from everyone else.
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
