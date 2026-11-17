# Cluck Crossing — reasons to come back (IOS-1217)

Unique to this game, all offline-first. Nothing here pretends to be a server.

## 1. Farm Week (weekly rule)
- `Models/FarmWeek.swift` → `FarmWeek.current(at:)` picks a `ShiftTheme` from the ISO week number (UTC), so every player gets the same week.
- Themes really change runs (`ShiftTheme.apply(to:)`, used by `ProfileStore.runConfig`):
  - Corn Harvest Week: kernels +2 coins
  - Bell Ringer Week: farm bell +1 s
  - Egg Basket Week: +10% basket per lane
  - Market Day Week: multiplier step +0.05
- Shown in the farmyard (Farm Week strip) and on the Top Players page.

## 2. Sunflower Row (weekly streak)
- Each UTC day with at least one finished run makes one of 7 sunflowers bloom along the farm fence (`PlayerProfile.sunflowerNights`).
- Tiers 3 / 5 / 7 sunflowers → 120 / 260 / 520 coins, claimable once per week (`ProfileStore.claimSunflowers`, `PlayerProfile.claimedLamps`).
- Native claim buttons under the roster.

## 3. TOP PLAYERS — Farm Week Roster
- Screen: `Views/Roster/RosterView.swift`. A `WKWebView` renders the local template `Resources/TopPlayers/top_players.html`: top 5, weekly reward slots, the sunflower row and the week theme.
- Data: `LeaderboardPage` (JSON) is baked into the template (`/*ROSTER_DATA*/null`); hen portraits are inlined (`/*HEN_IMAGES*/{}`).
- Weekly reward slots (`RosterRewardSlot.weekly`):
  - #1 Golden Comb: 800 coins
  - #2–3 Golden Feather: 400 coins
  - #4–5 Brass Bell Pin: 200 coins
- Weekly best per ISO week is stored in `PlayerProfile.weeklyBest`.

### Extension points for the online stage
- `LeaderboardProviding.weeklyTop(for:player:sunflowersLit:now:)` (`Services/LeaderboardProvider.swift`). The app depends only on this protocol, injected in `AppDependencies.leaderboard`.
- Current implementation: `PreviewLeaderboardProvider`. It uses deterministic sample rivals per week, merges in the player's real weekly best, and sets `isPreview = true`. The page shows a "Preview roster" notice, and reward slots say "Opens with the live roster".
- A live provider must:
  - fetch the top 5 for `shift.weekKey`;
  - submit `player.weeklyBest`;
  - return `isPreview = false`;
  - grant roster rewards on the server.

  The HTML switches the slot captions to "Paid on Monday" by itself.

## Tests
- Unit: `CluckCrossingTests/FarmWeekTests.swift` covers the week key, theme rotation, theme effects, sunflowers per night, claims and the preview roster top 5.
- UI: `testTopPlayersShowsRosterAndClaimsSunflowerReward` checks that the HTML renders and that a claim credits 120 coins. `testTour` captures the Top Players screen.
