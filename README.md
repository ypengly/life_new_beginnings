# Life: New Beginnings (Godot 4.3+ / GDScript)

A 2D top-down life-sim RPG: start with ~$400 in a basic apartment and build any life you like.

## Run
1. Install **Godot 4.3 or newer** (standard build, GDScript).
2. Godot Project Manager -> **Import** -> select `project.godot` -> open. Let it import once.
3. Press **F5**. Main menu -> New Game -> create a character -> Begin Life.

Controls: **WASD/Arrows** move, **E** interact (doors / people), **P** phone, **M** map, **I** inventory, **V** switch vehicle, **Esc** pause.
Time runs while you walk (1 real sec = 1 game minute; 1x/4x/12x buttons in the HUD). Menus pause time.

## Quick-start tips
- Walk to the door of a building (the glowing prompt appears at the bottom) and press **E**.
- Day 1: buy groceries at Corner Grocery, then apply for a Cashier job (Corner Grocery) and work shifts 09:00-17:00.
- Rent is due every 30 days. Sleep at home. Eat. Watch energy/hunger.
- New districts unlock by **net worth** (Commercial $500, Entertainment $1.5k, Industrial $3k, Financial $8k, Suburbs $15k).
- Study at home -> bootcamp at City University -> Junior Developer. Or freelance from your home computer. Or save for a Coffee Shop at Shop Unit A.

## What is implemented
Time/calendar/aging, day-night lighting, weather (rain particles), needs + stats + 9 skills, 6 backgrounds with perks,
character creator (placeholder art), 8 districts / 44 buildings with locked-district barriers and opening hours,
39 jobs in 11 career tracks with requirements, shifts, tax, promotions, absence firing, 10 courses with exams,
freelance board with deadlines, shops/items/clothing/furniture, rent/buy/sell properties, 7 vehicles (speed, fuel, breakdowns),
bank (savings, loans with interest, missed payments, repossession), 6 stocks with charts, 10 business types with daily simulation
(staff, stock, price elasticity, reputation, wages, rent) that keeps running off-screen, 12 NPCs with schedules and needs,
relationships (5 levels) -> dating -> official -> living together -> marriage -> children, gifts, memories, 19 random events
(+3 story beats, multiple endings), 12 achievements, phone UI (Stats/Jobs/Bank/Invest/People/Property/Map/Items/Log),
clickable fast-travel map, 4 save slots (+autosave, atomic writes, validation), settings, procedural SFX, music hooks.

## Known limitations (honest list)
- Written without running it in-engine: expect a few first-run parse errors to fix in the Godot editor (check the Output/Debugger panel).
- Art is placeholder (drawn shapes). NPCs walk in straight lines (no pathfinding) and ignore building collisions; they are hidden "inside" buildings.
- No TileMapLayer yet: the city is drawn from data (`world.gd`). Replace `_draw()` with TileMapLayers later; collisions/doors come from `locations.json`.
- No traffic, no building interiors, no NPC-initiated meetings/phone texts, no controller UI polish, language = English only,
  music/ambience need your own .ogg files, vehicle sounds are just a beep.
- Balance is a first pass. Tune numbers in `data/*.json`.

## Project structure
```
data/        jobs, courses, items, properties, vehicles, stocks, businesses, gigs, locations, npcs, events (JSON)
scenes/      main_menu, world/world, player/player, npc/npc, ui/hud
scripts/
  managers/  time_manager, game_manager (state, needs, achievements), activity_manager (all building/NPC menus), audio_manager
  economy/   economy_manager (money API, loans, stocks, monthly bills)
  careers/   career_manager (jobs, education, freelance)
  businesses/business_manager   relationships/relationship_manager   events/event_manager
  npc/       npc_manager, npc     player/player     world/world     save/save_manager
  ui/        hud, phone, map_view, main_menu, save_panel, settings_panel, line_chart, char_draw, ui_util
tests/test_runner.gd
assets/      sprites, animations, audio/music, audio/ambience, fonts (empty: drop real assets here)
```
All run state lives in **one dictionary** (`GameManager.s`), so saving = serializing it. Money only changes through
`EconomyManager.add_money / spend / spend_up_to` (negative balances and duplication are impossible by construction).

## Add content (no code needed for most)
- **Job**: add an object to `data/jobs.json` (`workplace` = a building `type`; `promotes_to` chains the track).
- **Course/degree**: `data/courses.json` (`school` = `school` or `university`; its id becomes a qualification jobs can require via `education_any`).
- **Business type**: `data/businesses.json`.  **Item/shop stock**: `data/items.json` (`shop` = building type).
- **Building / district**: `data/locations.json` (buildings need a district + x,y inside the 1100x900 cell; add a `prop` for homes/units and a matching entry in `properties.json`).
- **NPC**: `data/npcs.json` (home/work are building ids; schedule = [hour, place]).
- **Event**: `data/events.json` (conditions: min_day, min_money, min_networth, has_job, has_vehicle, has_business, need_flag, need_npc; effects: money, stats, skills, rep, rel_npc, mood, flag, time).
- **Real art**: add an `AnimatedSprite2D` child (animations `idle`, `walk`) to `scenes/player/player.tscn`; the placeholder drawing switches off automatically.
- **Music/ambience**: put `theme.ogg` in `assets/audio/music/` and `city.ogg` in `assets/audio/ambience/`.

## Tests
`godot --headless --path . -s tests/test_runner.gd` runs checks for economy exploits, loans, stocks, time, jobs, business simulation,
relationships, NPC schedules, save/load and corrupted-save rejection. Manual UI checklist: new game -> work a shift -> sleep ->
save -> reload -> open each phone tab -> buy a vehicle -> start a business.
