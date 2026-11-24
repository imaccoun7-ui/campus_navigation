# Campus Nav

**"Never get lost on Campus."** Offline campus navigation for BiPSU Main Campus.
A student scans a study load, the app builds a personal schedule and walks them
to each classroom on the illustrated campus map. Visitors can browse and get
directions without an account.

Flutter 3.35.4 (stable) · Dart 3.9.2 · Android + iOS · fully offline.

---

## Status

Built and checked:

- All 13 screens in `highfi/` implemented, plus the **Campus Map** (derived — see
  [Deviations](#deviations-from-the-brief-and-the-designs)).
- `flutter analyze`: **no issues**.
- `flutter test`: **41 tests passing** (see [Tests](#tests)).
- Not run on a physical device or emulator: this build machine has no Android
  SDK/emulator. Everything below the UI is covered by tests, and the widget
  tests build the real tree at 360×640 and 430×932.

Settled after the first report: the map scale is calibrated from measured
distances, the supplied logo is in use, `rooms.txt` was checked against
`buildings.json`, the parser is tuned on a real SIAS enrolment form, and the GPS
and room-photo features were removed on request.

---

## Screens → design files

| Screen | Route | Design |
|---|---|---|
| Splash | `/` | `highfi/01-splash.png` |
| Onboarding | `/onboarding` | `highfi/02-onboarding.png` |
| Log in | `/login` | `highfi/03-login.png` |
| Home | `/home` | `highfi/04-home.png` |
| Upload Study Load | `/upload` | `highfi/05-upload-study-load.png` |
| Scanning Study Load | `/scan` | `highfi/06-scanning-study-load.png` |
| Review/Correct | `/review` | `highfi/07-review-correct.png` |
| My Schedule | `/schedule` | `highfi/08-my-schedule.png` |
| Search | `/search` | `highfi/09-results.png` (results state) + derived empty state |
| Room Details | `/room/:buildingId/:roomIndex` | `highfi/10-room-details.png` |
| Set Starting Point | `/start` | `highfi/11-set-starting-point.png` |
| Route | `/route` | `highfi/12-route.png` |
| Arrival | `/arrival` | `highfi/13-arrival.png` |
| Campus Map | `/map` | **no design file** — derived from §5 using the same tokens |

The original 13 exports were loose UUID-named PNGs in the project root; they are
now in `highfi/` with descriptive names in the order above. Nothing else about
them was changed.

---

## Setup

```bash
flutter --version          # 3.35.4 stable or newer
flutter pub get
flutter run                # Android or iOS device / emulator
```

Checks:

```bash
flutter analyze
flutter test
```

Platform notes:

- **iOS**: `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are
  already in `ios/Runner/Info.plist`.
- **Android**: no extra permissions are needed; image/file picking uses the
  system pickers. ML Kit needs a device with Google Play services for the text
  recogniser's best accuracy.

---

## Assets

| Path | What it is |
|---|---|
| `assets/map/campus_map.png` | The illustrated campus map, 1346 × 1168, transparent background |
| `assets/data/buildings.json` | Building outlines, floors, rooms, gates, road network |
| `assets/data/room_details.json` | Editable type / capacity / accessibility layer, keyed per room |
| `assets/fonts/Poppins-*.ttf` | Bundled so headings render correctly offline |
| `assets/images/logo.png` | The supplied app logo, used on Splash and Log in |

All three data/graphics assets are declared in `pubspec.yaml`, along with the
Poppins family (Regular 400, Medium 500, SemiBold 600, Bold 700).

---

## Project structure

```
lib/
  main.dart                 loads Hive, buildings.json and room_details.json once
  app.dart                  MaterialApp.router
  core/
    theme/                  the only colours, type, spacing, ThemeData
    config/                 metersPerPixel, walking speed, start points, assets
    routing/                go_router graph
    format/                 clock / distance / walking-time formatting
    widgets/                pill buttons, cards, detail rows, header, bottom nav
  data/
    models/                 Building, Floor, Room, Gate, RoadGraph, CampusData,
                            ScheduledClass
    repositories/           campus JSON, room details, schedule + search history
                            (Hive), and the Riverpod providers
  features/
    splash/ onboarding/ auth/ home/ upload/ scan/ review/ schedule/ search/
    room/ start/ route/ arrival/ map/
  services/
    routing/                dijkstra, pathfinder (densify + doors), steps
    matching/               fuzzy room-code matcher for OCR output
    ocr/                    PDF text extractor, ML Kit scanner, study-load parser
test/                       analysis, geometry, routing, parser, UI smoke tests
```

State management is Riverpod (`Notifier`/`NotifierProvider`), navigation is
`go_router`. Storage is Hive (`campus_nav` box: `schedule`, `recent_searches`).

---

## How the map works

- Every coordinate in `buildings.json` is a **pixel on the 1346 × 1168
  illustration** and stays that way: the `InteractiveViewer` applies the pan/zoom
  matrix, and hit testing converts taps back with
  `transformationController.toScene(...)`.
- Each building's outline `Path` is built once in the `Building` constructor and
  reused for every hit test and every paint.
- Layers: the map image, then one `CustomPaint` for the selected-building
  highlight, the route (white outline + blue line, green start, red end) and the
  optional road-graph overlay.
- Zoom is 0.8× to 6× of the fit-to-screen scale, opening fitted, with zoom
  in/out and reset controls (48 dp, labelled for screen readers).
- Tapping a building opens a bottom sheet with its floors and rooms; search
  results select and zoom to a building and highlight the matching room.
- **Hidden debug overlay**: long-press the reset (fit) button on the map to draw
  the traced road graph. Long-press again to hide it.

---

## Routing

Local only, no network:

1. Build a graph from `roads.nodes` / `roads.edges`. The nodes follow the dark
   paved road centerlines visible in `campus_map.png`, not a rectangular grid;
   Naval Road is excluded from routing.
2. Densify every edge into points ~20 px apart (`AppConfig.roadDensifySpacing`).
3. For each building, find the outline point closest to any road point (its
   door) and link that door into the graph.
4. Run Dijkstra from the chosen start to the destination's door.
5. Draw the point list and fit the view to it.
6. Convert the point list into steps: heading changes above 30° become turns,
   each turn is named after the nearest building within 220 px.

Building-to-road connectors are rejected if they cross a building outline.
Gate starts and dropped pins snap to the nearest campus-side road point.
The map is illustrative, so the road centerlines and walking distances remain
approximate. The graph lives in `buildings.json` and can be corrected there
without changing the routing code.

### Starting points

| Option in the UI | What it resolves to |
|---|---|
| Main Entrance | **First Gate** — assumed to be the main gate, configurable via `AppConfig.mainGateName` |
| Library | School of Management and Entrepreneurship (Library on floors 2–3) |
| Cafeteria | School of Technology and Computer Studies (Cafeteria on floor 4) |
| Student Center | Student Center building (no rooms yet) |
| Current Location | tap the map; the pin snaps to the nearest road point |

`AppConfig.landmarkStartBuildings` holds the Library/Cafeteria mapping.

---

## Map scale

`AppConfig.metersPerPixel` is **0.26** and `scaleIsApproximate` is `false`, so
distances and walking times are shown as measured instead of "approx.".

The number is measured, not guessed: three buildings on the illustration are
also mapped in OpenStreetMap, so the real distance between each pair of their
footprint centroids was compared with the pixel distance between the centroids
of the same outlines in `buildings.json`.

| Pair (OSM ways) | Real | Pixels | m/px |
|---|---|---|---|
| Gymnasium ↔ Student Center (`370529139` ↔ `437636220`) | 94.5 m | 355 px | 0.266 |
| Gymnasium ↔ Andaya Building (`370529139` ↔ `921747881`) | 42.4 m | 183 px | 0.232 |
| Student Center ↔ Andaya Building (`437636220` ↔ `921747881`) | 120.7 m | 465 px | 0.260 |

0.26 is the median. The illustration is stylised, so treat it as ±7%. To make it
exact, tape-measure First Gate `(215, 258)` to Second Gate `(848, 105)` along
Naval Road, read the same path in pixels with the debug overlay (long-press the
reset button on the map), and set
`metersPerPixel = real_metres / pixel_distance`. Set `scaleIsApproximate = true`
if you ever want the "approx." labels back.

Walking time uses `AppConfig.walkingMetersPerMinute` (80 m/min).

**GPS is not part of the app.** "Use my current location" and `GeoCalibration`
were removed on request, so dropping a pin on the map is the only way to start
from where you are.

---

## Editing `assets/data/buildings.json`

- `image`: `{width, height}` — keep in sync with `campus_map.png`.
- `gates`: `{name, x, y}` in image pixels.
- `buildings[]`: `{id, name, poly, floors}`.
  - `poly` is the tappable outline, image pixels, in order; it closes
    automatically.
  - `floors[]` is `{label, rooms[]}` where `rooms` are plain strings. A building
    with no room data uses `"floors": []` and the app shows
    "No room details yet".
  - `id` must stay stable: rooms, routes and saved schedules reference it.
- `roads`: `{nodes: {id: [x, y]}, edges: [[idA, idB]]}`. Add a node, then an
  edge to connect it. Doors are computed automatically, so new buildings only
  need their outline and a nearby road.

The School of Nursing, Health and Science and the School of Teacher Education
are two halves of one long building — they stay two entries, as in the data.

### Checked against the university room list

The university room list was compared building by building with
`buildings.json`: every building, floor, side and room matches. The only
changes are the two places where that list nests names — `Habi Space (study hub
and co-working spaces)` and the Andaya first floor's `Academics, Research and
Innovation Office (inside: …)`, whose three inner offices stay in the
parenthesis so search still finds them — plus one typo fix (`RECORDA AND
ARCHIVES` is stored as `Records and Archives`) and normal casing.

## Editing `assets/data/room_details.json`

Every room in `buildings.json` has an entry keyed by `buildingId|room name`
(the room string exactly as written):

```json
"stcs|T-201 - AutoCAD Lab": {
  "type": "Laboratory",
  "capacity": null,
  "accessibility": null,
  "notes": ""
}
```

- `type` is only filled in where the room name states it (Laboratory, Laboratory
  / Smart Classroom / Classroom / Office / Library / Cafeteria / Sports
  Facility). 60 of the 152 rooms got a type this way; 92 are `null`.
- `capacity` and `accessibility` are `null` for **every** room: the source data
  does not contain them and they must not be invented.
- Any `null` renders as **"Not available yet"** in Room Details and Arrival.
- Room Details says "Floor" from the floor label in `buildings.json`, so you do
  not repeat the floor here.

Saving this file is enough — no code change needed.

---

## Study-load scanning

1. `image_picker` (camera) or `file_picker` (JPG, PNG, PDF).
2. Images go through ML Kit text recognition (`google_mlkit_text_recognition`).
3. PDFs: embedded text is extracted first with a small pure-Dart extractor
   (`PdfTextExtractor`); if the text is not usable (a scan, or an odd font
   encoding) every page is rendered with `pdfx` and OCR'd.
4. `StudyLoadParser` (pure Dart, no Flutter) turns the text into subject / day /
   time / room candidates, splitting compact day codes (`MWF`, `TTh`) into one
   class per day.
5. `RoomMatcher` resolves the room string against `buildings.json` with OCR
   tolerance (`O`→`0`, `I`/`L`→`1`, dropped hyphens, edit distance).

Nothing is guessed silently: a missing day, time, room or AM/PM marker is
reported in Review, where every row can be edited, removed, or added to, before
**Create Schedule** writes the schedule to Hive.

Tuned on real SIAS enrolment screenshots: the parser reads
hour-only schedules (`3-4 pm`, `10 am-12 pm`), compact day codes (`MTh`, `TF`),
a second meeting line that repeats only time, day and room, and the table's
`Class / Subject Code / Subject Description / Units / Schedule / Room /
Instructor / Section` columns. `TECH302` is the only room alias (→ `T-302`);
every other code must exist in `buildings.json`, so an unlisted room such as
`BI1101` is flagged for the student instead of being guessed.
`test/study_load_parser_test.dart` keeps that screenshot's text as a fixture.

---

## Accessibility

- Text follows the system font size (the app never overrides `textScaler`); all
  type is defined in one place so sizes scale coherently.
- Every control is at least 48 dp, including the compact room chips in the
  map's building sheet (the pill is drawn smaller inside a full-height target).
- Map controls, back buttons, cards and chips carry semantic labels; the map
  image itself has a label; the bottom navigation announces its tabs.
- Text on the blue canvas uses white / near-white (`#DCE7F9`) on `#4E88DF`;
  ink on light cards is `#1E1E1F`, which passes contrast at all used sizes.

---

## Tests

```bash
flutter test
```

| File | Covers |
|---|---|
| `test/buildings_json_test.dart` | JSON loads, 18 buildings, 2 gates, room/floor parsing, rooms without data, road graph, search |
| `test/polygon_hit_test.dart` | image-space hit testing, misses, cached `Path`, concave outlines, overlapping buildings |
| `test/routing_test.dart` | door node per building, ~20 px densification, **every building reachable from both gates**, snapping, distance/time |
| `test/steps_builder_test.dart` | steps for a route, max length, landmarks and turn direction, every building |
| `test/study_load_parser_test.dart` | stacked and single-line layouts, 24-hour times, compact day codes, multiple subjects, a real SIAS enrolment screenshot, and every "flag instead of guess" path |
| `test/room_matcher_test.dart` | `TECH302` → `T-302`, and unknown codes such as `BI1101` never resolving |
| `test/app_smoke_test.dart` | the real app at 360×640 and 430×932: splash → onboarding → guest → home; map building sheet with real rooms; "No room details yet" |

---

## Deviations from the brief and the designs

Reported per §2.5 of the brief (`highfi/` wins for looks, the brief wins for
behaviour, and both lose to real data):

1. **No Campus Map design, and no `campus_map.png`.** The map image was supplied
   later (thank you); the map screen itself is derived from §5 in the design
   language: blue canvas, titled header, floating round zoom/reset controls,
   rounded white building sheet with floor-grouped room chips and a yellow
   Directions button.
2. **Bottom navigation is Home / Schedule / Search**, exactly as in the designs,
   so the map is not a tab. The brief also asks for a map shortcut on Home, so a
   second round yellow button (map pin) sits next to the account button in the
   Home header. That one button is an addition to the design.
3. **"Create Schedule"** (the design's label) is used for the review action; the
   brief calls it "Save schedule".
4. **Set Starting Point shows five rows**: Current Location, Main Entrance,
   Library, Student Center and Cafeteria (required by the brief). The design's
   "Use my current location" row is **removed on request**, together with the
   `GeoCalibration` service, so "Current Location" (tap the map to drop a pin)
   is the only way to start from where you are.
5. **The designs' sample content does not exist in the data** — "Room 204",
   "Room 204A", "Lecture Room 204", "Room 310", "Room 115", "Arts Building",
   "Science Building", "Administration Building", Type "Classroom", Capacity 40,
   "Elevator access". Real screens render real data and show "Not available yet"
   for type/capacity/accessibility, per §4 and §11.
6. **Search & Browse**: the design only shows the *Results* state. The empty
   state (recent searches + browse by building) is built in the same visual
   language because §3.6 requires it.
7. **No photo panels, and the real logo.** The room and route photo panels the
   mockups show are **removed on request** — no grey placeholders are left — and
   `assets/images/logo.png`, the supplied mark, replaces the rebuilt icon.
8. **No account backend.** Log in is local-only (any non-empty ID and password
   continues); "Continue as guest" is fully supported, and search, browse, map
   and directions never require sign-in.

---

## Still missing

1. **Room capacity and accessibility** — all 152 rooms are `null`; fill in
   `room_details.json`.
2. **Room types for 92 rooms** whose names do not state one.
3. **An exact map scale** — 0.26 m/px comes from OpenStreetMap footprints (±7%);
   a tape-measured gate-to-gate distance would make it exact (see
   [Map scale](#map-scale)).
4. **`BI1101` and other rooms that are not on the map.** The sample study load
   schedules `BI1101`, which `buildings.json` does not list, so it is flagged in
   Review instead of being guessed.
5. **Road network accuracy** — derived from the illustrated black roads and
   still approximate; adjusting `roads` in `buildings.json` is enough.
6. **A device run** — `flutter run` on Android/iOS still needs to be done on
   hardware; the ML Kit and PDF paths only execute there.
