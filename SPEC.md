# Cluck Crossing — spec (IOS-1217)

Chicken Road–style crossing game on a bright-day farm, non-gambling: no bets, no real money; coins are earned only by playing.
Bundle `com.cluckcrossing.game30` · iOS 15+ · iPhone only · English UI · offline.

## Core loop
A hen crosses a busy farm road lane by lane:
- tap to hop;
- swipe ← → to sidestep;
- swipe ↓ to step back.

Traffic (pickups, tractors, milk vans, combines, corn trucks) is real-time. Every new lane raises the clutch multiplier, which is shown on wooden signs beside the lanes.

## Signature mechanics
1. **Basket Climb & Roost.** Each lane lays an egg worth 10 × the streak multiplier (+0.2 per lane, capped at ×6). Only ROOST on a hay strip banks the basket. A bump loses the basket and one feather, and sends the hen back to the last hay strip.
2. **Sprinkler Bursts.** Sprinklers gurgle for 0.9 s (warning), then spray for 0.8 s (dangerous).
3. **Farm Bell.** Lanes and corn fill the grain meter. A full meter rings the farm bell and holds the current lane and the next two for 2 s or more; afterwards those lanes rush at ×1.6 for 3 s.
4. **Corn Truck Spill.** A horn and HONK arrows warn of a long truck. It drops kernels that give grain, coins and cooler feet, and that disappear after 7 s.
5. **Hot Gravel.** Standing on a hot lane heats the feet. At full heat the hen hops forward on her own; hay strips and corn cool her down.

## Progression
- **Campaign:** 30 crossings in 5 districts. Each district adds one hazard, and lanes, speed and density keep rising:
  - Meadow Lane: no hazards;
  - Harvest Road: corn trucks;
  - Orchard Row: sprinklers;
  - Sunbaked Gravel: hot gravel;
  - Foggy Hollow: fog.
- **Stars:**
  - ★ cross the road;
  - ★★ reach par (roost on every hay strip);
  - ★★★ halfway from par to the no-roost score, which requires skipping hay strips.
- **Modes:** Long Road (endless, ramps up) and Daily Crossing (same seeded road for everyone each UTC day). Both unlock after Meadow Lane.
- **Feed Store:** 5 upgrades. **Henhouse:** 6 hens with perks. **Barn Wall:** 15 fair-ribbon achievements, stats and a trip log.
- **Retention:** Farm Week weekly rule, Sunflower Row streak and the TOP PLAYERS roster. See `RETENTION.md`.

## Screens
- Farmyard: wooden signpost by the barn, GO! sign, Farm Week strip.
- Route Board: chalk board of crossings.
- Feed Store, Henhouse (nest boxes), Barn Wall (ribbons), Top Players (WebView), Almanac, Settings, tutorial.
- Run HUD: wooden score sign, feathers, BELL/ROOST, thermometer.
- Run end: county-fair photo with a ribbon.

## Tech
- SwiftUI + SpriteKit.
- Rules live in `RunSession` (pure Swift), save data is JSON.
- Art: `Artwork/generate_assets.swift`. Sounds: `Artwork/generate_sounds.swift`.
- Test launch arguments: `--uitesting`, `--autopilot`, `--coins=N`, `--cleared=N`, `--sunflowers=N`, `--open=<route>`, `--seed=N`, `--show-tutorial`.
