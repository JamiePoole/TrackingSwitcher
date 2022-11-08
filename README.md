## Track multiple resources with no effort.
__Automatic Tracking Switcher__ effortlessly monitors multiple tracking targets with minimal effort by switching between different abilities on a timer. This allows you to optimise gathering abilities for farming, or for maintaining class-specific tracking spells while still keeping an eye out for resources.

### Update 1.1.0
The first feature update brings in the ability to additionally pause switching while in combat, a party dungeon, a raid instance or battleground/arena. This helps manage trackers that use global cooldowns and intefer with combat rotations, and also prevents these Trackers from appearing in damage meters and Warcraft Logs as unwarranted 'Activity'. So now your Raid Leader won't be asking why you cast 'Find Herbs' 34 times during KT!

### _Switcher Tracking Addon_ by lanscetre
This addon was heavily inspired by __Switcher Tracking__ from __lansectre__. This project started as a fork of their addon as a learning experience and to improve upon it's functionality. However, during development, it was clear that the improved features required significant changes that warranted a new addon. Thanks for lansectre for the inspiration to create this project. All the code in this addon has been written from scratch, and nothing has been duplicated.

### So what improvements were made?
This addon was created to do three things desired from using *Switcher Tracking*:
1. Remove the switch sound effect (the 'click' sound when activating a tracker)
2. Stop the switch from interrupting 'aiming' (Blizzard, certain bomb items etc)
3. Stop the switch from closing the loot window prematurely

The other improvement is through an enhanced `Interface Options` panel, that provides a graphical way to manipulate addon settings. These settings include:
* The switch interval _[default: 2 seconds]_
* Start the switch automatically on login _[default: on]_
* Mute the default switch sound effect _[default: on]_
* Play a sound effect when the switch has been 'paused' _[default: off]_
* Play a sound effect once switching 'resumes' _[default: off]_
* Pause the switch when the mouse is over the minimap _[default: off]_
* Enable/Disable which tracking abilities to switch between _[default: Find Minerals, Find Herbs]_

### When is it 'paused'?
When certain conditions are met, the switch between tracking abilities is 'paused' until the condition has passed. For instance, as per the improvements above, the switch won't occur, or will be 'paused', while the player is looting or aiming.

This is the list of all the conditions the addon must pass in order to switch abilities:
* The tracking ability is not on cooldown
* The player is not casting a spell or item
* The player is not channeling a spell or item
* The player is not looting
* The player doesn't have something on their cursor (left-click drag of loot or spell etc)
* The player isn't in 'targeting' mode (free-aim like Blizzard or some throwable items, usually bombs)
* The option to pause while the cursor is on the minimap is enabled, and the cursor is over the minimap

### Still to come...
There are still a some features yet to be implemented that are currently in-development, and I would love to hear your feedback or ideas on what to include in future releases.


| Feature | Progress |
|---------|:--------:|
| Bug Fixes | In-Progress|
| Dungeon/Raid/Combat toggle | In-Progress |
| Localisation | Planned |
| Provide functional key-bindings for switching | Planned |
| React to user learning/unlearning Tracking abilities | Planned |
| Stop Switch on manual Tracker override | Planned |
| Resume 'pause' based on time elapsed | Planned |
| Minimap Tracking Icon overlay/GUI | Wish |
| Allow players to select Trackers from default GUI dropdown | Wish |
| List commands and arguments for slash command (/ats) | Complete |

To make requests, report a bug, or just leave feedback, see this project's GitHub page at https://github.com/JamiePoole/TrackingSwitcher