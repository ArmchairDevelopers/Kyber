## [2.0.0-beta10] - [??/??/????]
- Added parties
    - Invite players to a party through the friends list. Invites show up as a banner with a sound and can be accepted or declined directly
    - Party leaders can kick members and transfer leadership
    - The party leader picks a server and every member is taken through the required mod checks and downloads automatically
    - Members join the game automatically once everyone is ready, or can join late at any time
    - Party leaders can also host a server and have the party join it
    - Party members are placed in the same in-game squad
    - Added an in-game party chat that is only visible to your party
    - Added a privacy setting to control whether non-friends can invite you to a party
    - In-game team shuffling now groups party members together
- Added server queues
    - Joining a full server now places you in a queue instead of failing
    - Your queue position is shown live in the launcher and a slot is reserved for you as soon as one frees up
    - Parties queue as a group and get reserved slots for the whole party once every member has the required mods
    - Party invites can't be sent or accepted while queueing, so a queue spot can't be shared with players who weren't in the party when it was queued
- Replaced the navigation bar with a new social bar
    - Shows your friends, your party and download progress at a glance
- Added incremental mod downloads
    - Now when downloading a new version of a mod collection, only mods that have been updated need to be downloaded.
- Added in-game AFK kicking. Configure timeout with `Whiteshark.NoInteractivityTimeoutTime` in seconds. To disable, set to 0
- Added in-game chat filtering
    - Messages sent are filtered from a list of phrases, with a default one set for every server
    - Plugin developers can configure this list, the filter character, & functionality with the `ChatFilter` interface.
    - Set console setting `Kyber.LogFilteredChatMessages` to true to enable in-depth logs of filtered messages
- Increased the mod limit from 247 to 1739
- Redesigned the server info box
- Servers are now grouped by region in the server browser
- Added a token reset flow for Kyber tokens
- Added a bypass player limit entitlement that allows joining full servers
- The launcher now warns about corrupted collections and prefers a working duplicate when available
- Battlepoints can now be interacted with via console commands `Kyber.SetBattlepoints <username> <value>` & `Kyber.GiveBattlepoints`
- Added new KYBER Plugin features:
    - Plugins can now be hot-reloaded with `Kyber.HotReloadLua server`
    - Official API documentation is now available at https://docs.kyber.gg/g/pluginref
    - `MapRotation` Library: modify & read the current map rotation at runtime
    - `ChatFilter` Library: modify the chat filter blocked phrases list & toggle functionality.
    - Certain events can now be cancelled via `EventManager.SetCancelled(true)` in the event callback context
    - `FBArray`s can now be fully read and processed
    - Fixed DataContainer reading
    - All enums are now usable
    - `Client` plugins are now deprecated
    - Player battlepoints, score, kills, assists, deaths, active kit, if they are spawned, and player id are now interactable
    - Players can now have their health, max health, and abilities changed while spawned
    - You can now disable player inputs with `SetInputEnabled`
    - Added events `Level:Complete`, `DedicatedServer:PerformanceStatsMessage`, `ServerPlayer:Disconnect`, `ServerPlayer:Killed`, `ServerPlayer:Spawned`, `ServerPlayer:SendMessage`
    - Renamed event `Server:PlayerJoined` to `ServerPlayer:Joined`
- Optimized launcher avatar loading
- Many Module stability and performance improvements
    - Many API requests made were before synchonous and took up processing across 14 threads, and now only take 2 and are properly asynchronous
        - This fix/performance improvement should fix a good amount of random startup crashes & lower FPS spikes
    - Optimized ModLoader array extension allocations
    - Optimized player persistence instantiation
    - Optimized FNV string hashes
    - Optimized packet processing
- Added new time entities:
    - `KyberCurrentTimeEntity`: Get current `Time` field
    - `KyberTimeSplitterEntity`: Input `Time` float from the previous entity to get the current day, month, year, second, minute, and hour
- In-game friendly fire now fully works
- Fixed an issue where collections would display the wrong mod count
- Fixed shift-selection in the mods list
- Fixed an issue where proxies were not reachable for users with IPv6
    - Proxy connections now force IPv4 DNS lookups
- Fixed an issue where unreachable proxies could break the launcher while loading
- Fixed an issue where mod files inside nested archive folders were not detected on mod installs
- Fixed in-game latency differential value readback
- Fixed ModLoader bundling issue with an asset that has different bundles in different mods
- Fixed PlayerExtentRegistration type name reading
- Fixed `LocalizedStringIdPickerEntity` not reading the property connection `Sid` to have the output field `StringId` changed at outside of instantiation
- Fixed in-game team chat not working
- Fixed joining a server while having the game already open
- Fixed certain console commands being able to be ran on the client, causing a crash
- The server browser search is now cleared when switching tabs
- The launcher window can now be dragged from the full width of the title bar
- Fixed punished players missing their user information on the server moderation page
    - This fixes the issue where it would not be possible to unban a player
- Banning a player that is already banned no longer creates a duplicate punishment

## [2.0.0-beta9] - [??/??/????]
- Fixed stats on official servers not updating
- Added a new filter options to the mods page
    - You can now filter mods by gameplay and cosmetic mods
- Fixed "The title is installed in a language you are not entitled to play" for some users
    - Moved the Module path to `C:\ProgramData\Kyber\Module` to prevent issues with non-ascii characters in the user profile path
- Added the option to set custom icons for collections
- Implemented copy server link buttons
- Fixed an issue where it was not possible to download mods for a full server
- Fixed an issue where all instances of a server group would show up with the same map in the server browser
- Fixed an issue where the launcher would grey out when a server group was full
- Fixed JSON file map rotation imports
- Fixed an issue where the "CREATE NEW COLLECTION" button would grey out on the server host page
- Fixed an issue where the stats page would softlock when failing to ea stats
- Fixed an issue where all content would disappear when maxima failed to start the game
    - Added a new warning dialog when trying to start a game with an expired EA session

## [2.0.0-beta8] - [??/??/????]
- Extracting progress is now shown when installing mods
    - This will only work for .zip and .rar files, .7z files won't show any progress
    - This comes together with a major overhaul of the download manager, if you encounter any issues with downloads, please let us know in our Discord server
- Changed how clients authenticate with servers
    - This fixes an issue where it was possible to join full servers
- We are now using a new different CDN for mod downloads
    - This should improve download speeds for most users and reduce issues with downloads failing
- Fixed crash regarding multiple levels being loaded when using Kyber.Restart
- **Forced HDR to be always disabled**
- Fixed a 1 player bug (for the 4th time)

## [2.0.0-beta7] - [??/??/????]

- Fixed an issue where the Launcher would fail to check if a user is logged in to Nexus Mods
- Fixed proximity voice chat not working
- Added Discord linking
    - You can now link your Discord account to your Kyber account in the settings page
    - Patreon supporters should have their Discord account linked automatically after logging in
- Added the option to use push to talk for proximity voice chat
- Added the option to switch input and output devices for proximity voice chat without needing to be in-game
- Added ingame icons for proximity voice chat
- Updated join modal UI
- Proxies are now pinged multiple times to get a more accurate ping value
    - We are aware that some users still experience high pings. [...]
- Collections can now be saved by pressing `enter` in the collection name input
- Fixed an issue where the game would sometimes crash when using `Kyber.Restart`
- EA usernames should get updated again on KYBER after a name change.
    - It can take up to 7 days for your username to update on KYBER.
- The launcher now clears the Nexus Mods cache between each version to prevent issues with outdated cache
- Fixed stats on official servers not updating
- Fixed an issue where the launcher would get stuck at "Updating Module"
- Files in the `MISCELLANEOUS FILES` category are now displayed in the mod browser
- Fixed an issue where the mods list on the host page would not refresh after a file system change
- Moved mod browser cache to the system temp folder

## [2.0.0-beta6] - [-/-/-]

- Added a report system
    - To report a user, simply open the launcher while being in-game, hover over the user you want to report and click on the report button
    - To open the in-game panel while being in-game, press `INSERT`
    - To report someone not in your server, click on your profile on the top right and then search for the user
- Added support for custom modes and maps in the map rotation builder
    - When using mods that implement the new format, new maps and modes will show up in the map rotation builder
- New server grouping system
    - Official servers are now grouped together. When joining an official server, the most popular one will be selected by default.
    - You can manually select a server instance by selecting it in the join dialog.
- Fixed an issue where Downloads would fail with "Request Range Not Satisfiable"
    - The launcher now displays a warning when trying to use more than 247 mods
- Fixed an issue where it was possible to set a path with non-ascii characters as the mod path
- Fixed an issue where it wasn't possible to create a new Nexus Mods account in the Launcher
- Fixed an issue where the Launcher would turn invisible on startup
- Fixed an issue where after a name change users would not be able to promote other players to moderators
- Fixed an issue where EA usernames would not update on KYBER
    - It can take up to 3 days for your username to update on KYBER.
- (Maxima) Fixed Cloud Sync
    - This fixes the issue where Battlefront 2 settings would get reset after every game start

## [2.0.0-beta5] - [-/-/-]

- Fixed proxy reconnection bug: packets sent while reconnecting to the proxy are now reported as successful, preventing the engine from mistakenly triggering a full disconnection.
- Fixed an issue where the Launcher would not be able to search for mods in the Mod Browser
- Added region icons to the server browser
- Made server password inputs sensitive
- Added a new option to disable proximity chat
- Fixed an issue where the launcher would sometimes crash while starting the game
    - This means that Windows 7 Compatibility Mode is no longer needed
- Fixed an issue where promoting a player to moderator wasn’t possible
- Fixed an issue where the Launcher was not able to load proxies
- Potential fix for an issue preventing some users from linking their Patreon account
- Added a new host option to shuffle teams between rounds
- Fixed an issue where the Launcher would load the wrong files when using a mod collection
- (Maxima) Improved error messages
- Added a new option to unlink or link your Patreon account in settings
- Fixed an issue where the Launcher would not start correctly and would just display a white screen
- The launcher now displays a warning when multiple big mod packs are used together
- Fixed an issue where the Launcher would sometimes fail to download mods with Nexus Mods premium
- Fixed an issue where the Launcher would turn grey when trying to join a server
- Fixed a memory leak in the Module
- The launcher now displays usernames for punishments and moderators
- Frosty Collection screenshots are now being shown when inspecting them
- Fixed an issue where loading multiple levels at the same time would crash the module
- Removed the "PLAY" button from the server browser as playing on EA servers is still broken
    - To play offline, you can go to the Mods page, select a mod collection and click on the "PLAY" button there

## [2.0.0-beta4] - [-/-/-]

- **Fixed an issue where the Nexus Mods login would load indefinitely**
- Implemented server list search and pagination
- The mod category `Map` is now considered a gameplay category
    - That means that mods with the `Map` category will be need to be installed when joining a server
- New download manager
    - You are now able to pause, resume and cancel downloads
    - The progress of downloads is now saved and will be restored when the Launcher is restarted
- Stats page sneak peek
- Improved loading times for affected files
- Added a selection of backgrounds for the Launcher (Patrons only)
- Improved mods page layout
- Improved Nexus Mods search
- The mods featured during the setup should now be always up to date
- Mods can now be dragged and dropped into other applications (e.g. Discord)
- Updated the credits page
- Several other minor UI improvements

## [2.0.0-beta3] - [-/-/-]

- Added a new maintenance warning system
- Several installer improvements
- Fixed an issue where the Launcher wouldn't apply a custom primary color during startup
- Fixed an issue where the Launcher couldn't start the game because of a "PanicException"

## [2.0.0-beta2] - [-/-/-]

- Added colorblind profiles
- Patrons now can change the primary color and the background of the Launcher
- Added a new "Auto" setting for the proxy selector
- Fixed an issue where the generated BSM file would not be saved automatically
- Fixed an issue where the Launcher would error when trying to join a server or download a mod (HandshakeException)
- Fixed an issue where the Frosty Import Dialog would grey out
- Fixed the server type filter
- Fixed an issue where the Launcher would apply required gameplay mods twice when selecting a cosmetic mod collection
- Fixed an issue where the Launcher would fail to extract mods from a RAR file
- Fixed an issue where the Launcher couldn't start the game because of a "PanicException"

## [2.0.0-alpha9] - [-/-/-]

- New filter options for the server browser
- Overhauled settings page
- Overhauled host page
- Implemented server descriptions
- New punishment & moderation system
- Fixed an issue where the Launcher would display the wrong maps in the map rotation builder

## [2.0.0-alpha8] - [-/-/-]

- You are now able to view mod descriptions, screenshots and affected files
- When importing Frosty Packs, the Launcher will now automatically copy the mods
- Fixes an issue where downloads would not start

## [2.0.0-alpha7] - [-/-/-]

- New Setup flow
- **Fixed an issue where the Launcher would crash for some users when trying to log in to Nexus Mods**.
- Removed puppeteer as a dependency so Chromium is no longer required.
    - If not done automatically, you can remove the `chromium` folder at `%appdata%\ArmchairDevelopers\Kyber\chromium`
- The launcher now uses a new API for everything Nexus Mods related.
    - The new API is experimental and might not work as expected. Should you encounter any issues, please let us know in our Discord server.
    - You are now able to specify a custom value for displayed items per page on the Mod Browser.
    - Added Nexus Mods user profile pages
- New layout for the Play, Host, Mods, Mod Browser and Settings pages.
- Added support for [BetterSabers](https://www.nexusmods.com/starwarsbattlefront22017/mods/16)
    - To install the plugin just drag and drop the ZIP file into the Launcher
- Added new settings for Auto Players on the Host page
- Servers are now highlighted when they are hosted by someone from your EA friends list
- You are now able to delete installed mods on the Mod Page
- Added mod extraction support for .rar and .7z files
- You can now import your Frosty Packs into the Launcher
    - Go to the Settings page then click on the "Import From Frosty" button
- Several other minor UI improvements
- For Nexus Mods Premium Users, the Launcher will now use the API to generate download links which should speed up the download process
- Fixed an issue where the Launcher would not work properly with multiple versions of Collections
- Fixed some issues with drag and drop
- Fixed various issues
- Performance improvements

___
Known issues:

- Resetting the Launcher does not work. Workaround: Click reset, close the Launcher and start it again.

## [2.0.0-alpha4] - [-/-/-]

- New and improved mod browser
- When pressing `INSERT` ingame, the Launcher will now open the moderation page
- Patreon integration
    - You can now link your Patreon account to the Launcher and get whitelisted automatically
    - After starting the Launcher, you will be asked to link your Patreon account to gain access
- Automatic mod downloads got improved
    - The Launcher is now using the new backend for mod downloads which contains a lot more mods
- Fixed an issue where the NexusMods login would not work
- The download progress is now displayed in the taskbar
- Improved drag and drop handling
    - You are now able to drag and drop download links into the Launcher which will then be added to the download queue
    - You can also drag and drop NexusMods links into the Launcher which will then open the mod page on the mod browser page
    - Added a drag and drop UI
- Added the ability to duplicate mod collections
- Improved error handling for maxima related issues
- Improved notifications
- Improved settings page

## [2.0.0-alpha3] - [28/05/2024]

- Automatic mod downloads are now working
    - Please keep in mind that this feature is still in beta.
    - Not all mods will be available for download yet. We are working on adding more mods.
        - If you would like to see a specific mod added, please let us know in our Discord server.
- Password protected servers are now working
- The Launcher now remembers its size and position and will open in the same place as it was closed
    - This feature can be disabled in the settings

## [2.0.0-alpha2] - [27/05/2024]

- Logout button for the whitelist page
- Fix Proximity Chat settings
- Added a shortcut to export logs
    * `Ctrl + Alt + Space` to export logs
- Fixed multiple scrollbar issues
- **Fixed an issue where KYBER would not inject properly**
- Fixed the max player count on the host page
- Fixed an issue that prevented downloads from the Mod Browser to start
- Improvements for the map rotation builder
    - Added buttons to redo and undo changes
    - Added a button to shuffle the map rotation
    - Added a button to clear the map rotation
- Improved the auto-updater
    - Fixed a bug where the auto-updater could not close all required processes

## [2.0.0-alpha1] - [-/-/-]

- Initial release