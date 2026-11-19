# Changelog

Newest first. Each version has up to three sections: New, Changed, Fixed. The release button builds each GitHub release's description from this file.

## Unreleased

### Changed
- Avada Balenciaga names anyone who takes #1 from you, not only K-Maxing users. In combat the name comes from your group list, by the class the meter shows.

### Fixed
- Avada Balenciaga no longer names you as the one who stole your Balenciaga. Forever writes names as "Name Realm", so your own K-Maxing messages looked like someone else's and you were counted as a K-Maxing user of your own class. It also reads the game's own ranked damage rows now, and when only one K-Maxing user in the group plays the thief's class, it names them from the group's K-Maxing list.

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
