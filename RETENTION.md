# Cluck Crossing — reasons to come back (IOS-1217)

Unique to this game, all offline-first. Nothing here pretends to be a server.

## 1. Night Shift (weekly rule)
- `Models/NightShift.swift` → `NightShift.current(at:)` picks a `ShiftTheme` from the ISO week number (UTC), so every player gets the same week.
- Themes really change runs (`ShiftTheme.apply(to:)`, used by `ProfileStore.runConfig`):
  - Corn Harvest Week: kernels +2 coins
  - Crossing Guard Week: whistle +1 s
  - Lamp Lighters Week: +10% basket per lane
  - Rush Hour Week: multiplier step +0.05
- Shown on the street corner (Night Shift strip) and on the Top Players page.

## 2. Lamp Lighter (weekly streak)
- Each UTC night with at least one finished run lights one of 7 lamps on the player's block (`PlayerProfile.lampNights`).
- Tiers 3 / 5 / 7 lamps → 120 / 260 / 520 coins, claimable once per week (`ProfileStore.claimLamps`, `PlayerProfile.claimedLamps`).
- Native claim buttons under the roster.

## 3. TOP PLAYERS — Night Shift Roster
- Screen: `Views/Roster/RosterView.swift`. A `WKWebView` renders the local template `Resources/TopPlayers/top_players.html`: top 5, weekly reward slots, the lamp row and the week theme.
- Data: `LeaderboardPage` (JSON) is baked into the template (`/*ROSTER_DATA*/null`); hen portraits are inlined (`/*HEN_IMAGES*/{}`).
- Weekly reward slots (`RosterRewardSlot.weekly`):
  - #1 Golden Comb: 800 coins
  - #2–3 Neon Feather: 400 coins
  - #4–5 Brass Whistle Pin: 200 coins
- Weekly best per ISO week is stored in `PlayerProfile.weeklyBest`.

### Extension points for the online stage
- `LeaderboardProviding.weeklyTop(for:player:lampsLit:now:)` (`Services/LeaderboardProvider.swift`). The app depends only on this protocol, injected in `AppDependencies.leaderboard`.
- Current implementation: `PreviewLeaderboardProvider`. It uses deterministic sample rivals per week, merges in the player's real weekly best, and sets `isPreview = true`. The page shows a "Preview roster" notice, and reward slots say "Opens with the live roster".
- A live provider must:
  - fetch the top 5 for `shift.weekKey`;
  - submit `player.weeklyBest`;
  - return `isPreview = false`;
  - grant roster rewards on the server.

  The HTML switches the slot captions to "Paid on Monday" by itself.

## Tests
- Unit: `CluckCrossingTests/NightShiftTests.swift` covers the week key, theme rotation, theme effects, lamps per night, claims and the preview roster top 5.
- UI: `testTopPlayersShowsRosterAndClaimsLampReward` checks that the HTML renders and that a claim credits 120 coins. `testTour` captures the Top Players screen.
