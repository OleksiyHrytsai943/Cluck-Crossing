# Cluck Crossing — spec (IOS-1217)

Chicken Road–style crossing game, non-gambling: no bets, no real money; coins are earned only by playing.
Bundle `com.cluckcrossing.game30` · iOS 15+ · iPhone only · English UI · offline.

## Core loop
A hen crosses a night-city road lane by lane:
- tap to hop;
- swipe ← → to sidestep;
- swipe ↓ to step back.

Traffic is real-time. Every new lane raises the clutch multiplier, which is shown on neon plaques above the lanes.

## Signature mechanics
1. **Clutch Climb & Roost.** Each lane lays an egg worth 10 × the streak multiplier (+0.2 per lane, capped at ×6). Only ROOST on a traffic island banks the basket. A bump loses the basket and one feather, and sends the hen back to the last island.
2. **Manhole Flares.** Lids glow for 0.9 s (warning), then flare for 0.8 s (dangerous).
3. **Crossing Guard Whistle.** Lanes and corn fill the grain meter. A full meter freezes the current lane and the next two for 2 s or more; afterwards those lanes rush at ×1.6 for 3 s.
4. **Corn Truck Spill.** A horn and amber arrows warn of a long truck. It drops kernels that give grain, coins and cooler feet, and that disappear after 7 s.
5. **Hot Asphalt.** Standing on a hot lane heats the feet. At full heat the hen hops forward on her own; islands and corn cool her down.

## Progression
- **Campaign:** 30 crossings in 5 districts. Each district adds one hazard, and lanes, speed and density keep rising:
  - Sleepy Lane: no hazards;
  - Market Street: corn trucks;
  - Steam Quarter: manholes;
  - Neon Boulevard: hot asphalt;
  - Midnight Expressway: blackout.
- **Stars:**
  - ★ cross the road;
  - ★★ reach par (roost on every island);
  - ★★★ halfway from par to the no-roost score, which requires skipping islands.
- **Modes:** Night Run (endless, ramps up) and Daily Crossing (same seeded road for everyone each UTC day). Both unlock after Sleepy Lane.
- **Vending machine:** 5 upgrades. **Henhouse:** 6 hens with perks. **Billboard:** 15 neon achievements, stats and a trip log.
- **Retention:** Night Shift weekly rule, Lamp Lighter streak and the TOP PLAYERS roster. See `RETENTION.md`.

## Screens
- Street corner: lamp-post signs, WALK signal, Night Shift strip.
- Timetable: split-flap departure board.
- Vending, Henhouse (apartment windows), Billboard (neon), Top Players (WebView), Rulebook, Settings, tutorial.
- Run HUD: taxi sign, feathers, WHISTLE/ROOST, thermometer.
- Run end: Speed Camera photo.

## Tech
- SwiftUI + SpriteKit.
- Rules live in `RunSession` (pure Swift), save data is JSON.
- Art: `Artwork/generate_assets.swift`. Sounds: `Artwork/generate_sounds.swift`.
- Test launch arguments: `--uitesting`, `--autopilot`, `--coins=N`, `--cleared=N`, `--lamps=N`, `--open=<route>`, `--seed=N`, `--show-tutorial`.
