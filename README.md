# Skynet IADS — Retribution fork

A fork of [walder/Skynet-IADS](https://github.com/walder/Skynet-IADS), maintained for use
by [this DCS Retribution fork](https://github.com/juanjux/dcs-retribution).

Upstream has had no commit in about three years, every fork of it looks abandoned too,
and the script is shipped inside Retribution rather than dropped into a mission by hand
— so the changes we need have nowhere else to go.

**This file is the inventory of what we changed.** Upstream's own documentation, which is
the reference for how any of this works, is untouched at
[`skynet-iads-source/README_source.md`](skynet-iads-source/README_source.md).

## What this fork is built on

Retribution used to ship a build labelled `baron-branch`, dated May 2023: baleBaron's
`ActMobile` fork of Skynet 3.0.1, with unit tables Retribution had extended since. That
lineage never came back to upstream, and upstream meanwhile fixed things in the HARM
path that the older build does not have.

This fork is **upstream 3.3.0 with both of those brought in**, so nothing is lost either
way:

| | in `baron-branch` | in upstream 3.3.0 | here |
|---|---|---|---|
| `ActMobile` — mobile SHORAD shoot-and-scoot | yes | no | **yes** |
| HARM: AI off, not just emissions off (DCS multiplayer bug) | no | yes | **yes** |
| `SkynetIADS:onEvent` | no | yes | **yes** |
| High Digit SAMs: S-400, S-300V4, SAMP/T, Pantsir-SM | yes | no | **yes** |
| `FPS-117`, `FPS-117 Dome` | no | yes | **yes** |

## Changes

### Brought forward from `baron-branch` (2026-09-07)

- **`ActMobile`**, baleBaron's mobile shoot-and-scoot: a mobile SAM that has been
  emitting for longer than `mobilePhaseEmissionTimeMax` packs up and relocates, and one
  facing a long HARM shutdown spends it moving rather than sitting still. Lives in
  `skynet-iads-sam-site.lua`, with three touch points in
  `skynet-iads-abstract-radar-element.lua`: `hasWorkingSearchRadars()`, its use in
  `isTargetInRange` (a site whose search radars are all dead can still wake on its
  launchers), and the relocate hook at the end of `goSilentToEvadeHARM`.
- **The four High Digit SAMs systems** Retribution had added to its own build: `S-400`,
  `S-300V4`, `SAMP/T` and `Pantsir-SM`, with their radars, launchers and command posts.

### Performance and correctness (2026-09-07)

- **Short-circuit impossible target-range checks.** A failed search-range test skips
  launcher/tracking checks, a failed launcher test skips tracking checks, and kill-zone
  mode skips the working-search-radar query. Empty component lists and any-in-range
  semantics are unchanged.
  Tests exhaustively compare 108 search/launcher/tracking/mode/working-state combinations
  and assert that irrelevant checks are not called.
  Verified with the offline Lua 5.1 harness (DCS/MIST doubles, not an FPS benchmark).

- **Reject distant HARM tracks before heading calculations.** Each radar position is
  sampled once. Tracks outside the existing rounded 20 NM boundary skip bearing/heading
  work; heading and speed are read lazily at most once per notification. Existing
  magnetic-heading conventions, rounding, strict aspect/distance limits and shutdown
  rules are retained.
  For 100 distant radars the test performs 100 instead of 200 radar-position reads and
  zero instead of 100 bearing/heading calculations. No persistent position or heading
  cache is introduced.
  Verified with the offline Lua 5.1 harness (DCS/MIST doubles, not an FPS benchmark).

- **Index contact merging and radar membership.** An auxiliary name index replaces the
  full contact-list scan; the ordered contact array and HARM history remain intact.
  Expiry rebuilds the index, while detecting-radar membership uses a set and HARM
  evaluation uses a temporary membership set without aliasing the contact's array.
  The deterministic 50-radar / 200-contact test reduces getName calls from 3,959,800 to
  10,000, including initial insertion. Replacing/resizing the contacts array rebuilds
  its index; callers must not replace individual entries in-place or mutate the
  detecting-radar array behind its add method.
  Verified with the offline Lua 5.1 harness (DCS/MIST doubles, not an FPS benchmark).

- **Continue HARM evaluation after a first sighting.** A contact with zero measured
  speed now skips only its own HARM classification, not the rest of the network scan.
  Classification probabilities, altitude-profile rules and notifications for later
  contacts are preserved.
  Tests cover zero-speed contacts before, after and between established tracks.
  Verified with the offline Lua 5.1 harness (DCS/MIST doubles, not an FPS benchmark).

- **The contact filter runs once per contact, not once per site-and-contact pair.**
  `SkynetIADS.evaluateContacts` called `contact:getDesc()` inside its double loop, so a
  map with 20 sites to trigger and 100 contacts made 2000 calls every cycle for an answer
  that cannot differ between sites. `O(contacts)` now instead of `O(sites x contacts)`.
- **That filter read every contact as a unit** — [upstream #107](https://github.com/walder/Skynet-IADS/issues/107).
  A contact is a unit *or* a weapon and the two enumerations collide:
  `Weapon.Category.BOMB` is 3, the same as `Unit.Category.SHIP`, and
  `Weapon.Category.MISSILE` is 1, the same as `Unit.Category.HELICOPTER`. Bombs were
  discarded as if they were ships and missiles got through by coincidence, which is why
  C-RAM point defences never engaged bombs. `SkynetIADS.isAirborneContact` now asks the
  DCS object whether it is a weapon before choosing which enumeration to read.
- **Periodic maintenance also runs for point defences and zero-HARM-chance sites.**
  The earlier optimisation incorrectly treated `evaluateIfTargetsContainHARMs` as a
  detection scan. It actually removes spent missiles, expires HARM tracks and restores
  ROE after jamming. Skipping it could leave those states stuck. HARM identification
  runs separately in the network's contact evaluation; its tactical rules are unchanged.
  Offline Lua 5.1 regressions cover all three maintenance duties and task cancellation.

### CurrentHill's asset packs (2026-09-07)

Retribution fields CurrentHill's mods heavily and Skynet knew none of it. A system with no
entry is not merely ignored: `addSAMSite` calls `goLive()` and only then `cleanUp()`, so
the site is left radiating, outside the network, and beyond anything that could shut it
down.

- **[#113](https://github.com/walder/Skynet-IADS/pull/113) by HFXLegion** — thirty systems
  across China, Germany, Russia, the UK and the US, taken as five files under
  `skynet-iads-source/currenthill/`. Three corrections went in with them:
  - **Fourteen unit names were wrong.** Twelve US Patriot units and two Russian ones were
    written without the `CH_` prefix the mod uses, so those systems could never have
    matched anything.
  - **The Chinese file's THAAD is a byte-for-byte copy of the American one**, American
    unit names and all -- a paste that went into the wrong file. Dropped, and the US entry
    stands. It mattered because the files are concatenated and the later definition wins
    in silence.
  - Its `S-400`, `S-300V4`, `S-300PS` and `Pantsir-SM` are **not** taken. We already have
    all four from `baron-branch` and ours are supersets: the 51P6A launcher, Pantsir's
    `fire_on_march`, six more S-300PS units.
- **Four Swedish systems written here**, in `...-sweden-suported-types.lua`, which the PR
  does not cover and Retribution deploys: the `LvS-103` (ten layouts and campaigns),
  `RBS 70` and `RBS 98` -- both SHORAD, and `GroupTask.SHORAD` is handed to Skynet as a
  SAM site -- and the `IRIS-T SLM` under the older `CHAP_` unit names the fork still
  ships, given its own key so the files from #113 stay pristine and easy to re-sync.

Every CurrentHill launcher Retribution can field is now known to Skynet, and 21 of its 24
radars. The three left out are meant to be: the Patriot's ECS is a control station rather
than a radar, which is why upstream keeps it under `misc` -- a section nothing in Skynet
reads -- and the Monolit-B is coastal, and `GroupTask.Coastal` never enters the IADS.

### Two files that compiled only by accident (2026-09-07)

`skynet-iads-high-digit-sams-suported-types.lua` ended on a dangling `do` and
`skynet-iads-sam-site.lua` carried one `end` too many. Both were sliced a line short when
they were lifted out of the `baron-branch` build. The script compiled only because the two
cancelled each other out across every file between them, which made the build order
load-bearing and left six files sitting inside an accidental extra block. Both are fixed;
every source file now compiles on its own, which is also what makes them testable one at a
time.

### Upstream issues fixed here

- **[#88](https://github.com/walder/Skynet-IADS/issues/88) — the radio menu and the
  status text went to everybody.** `addRadioMenu` used `missionCommands.addSubMenu`,
  which has no coalition, and the logger used `trigger.action.outText`. An enemy pilot
  could open F10, choose *show IADS Status* or *show contacts* for the network he was
  flying against, and read its whole state and every contact it was tracking. Both are
  scoped to the network's own coalition now.
- **[#94](https://github.com/walder/Skynet-IADS/issues/94) — the SA-20A/B could not use
  the Tin Shield.** HDS 2.0 lets them, both the SA-5's and the mast-mounted 40B6M that
  came with the DCS 2.9 S-300; Skynet did not list either as an acceptable search radar
  for the S-300PMU1 or PMU2, so a site built that way had no search radar at all.
- **[#107](https://github.com/walder/Skynet-IADS/issues/107) — C-RAM point defences
  never engaged bombs.** Fixed above, in the contact filter.
- **[#85](https://github.com/walder/Skynet-IADS/issues/85) — a SAM site with no working
  search radar stayed dark for ever**, so killing an SA-11's Snow Drift disarmed its
  launchers. Fixed by the `hasWorkingSearchRadars` check brought in with `ActMobile`;
  the issue itself points at baleBaron's branch for it.
- **[#46](https://github.com/walder/Skynet-IADS/issues/46) — mobile SAMs should move
  when a HARM is detected.** That is `ActMobile`, also brought in above.

### Upstream pull requests adopted

Upstream is not merging anything, so the good ones are taken here, with credit.

- **[#105](https://github.com/walder/Skynet-IADS/pull/105) by MacFlorent** — calling
  `getCategory` as a method raises on an object that exists but is destroyed, and the
  error takes down whatever asked for the contact's type name. `Object.getCategory`
  answers nil instead.
- **[#106](https://github.com/walder/Skynet-IADS/pull/106) by MacFlorent** — the Phalanx
  can engage HARMs in DCS, whatever the realism of it, and the database said it could
  not. (It also fixes a missing comma.)

### Considered and not taken

- **[#75](https://github.com/walder/Skynet-IADS/pull/75) by MacFlorent** — the HARM
  identification aliasing bug, where the evaluated-radars list was the same table as the
  detected one, so only the first radar ever tried. Already fixed upstream in 3.3.0 by a
  different route: `getNewRadarsThatHaveDetectedContact` builds its own table now.
- **[#77](https://github.com/walder/Skynet-IADS/issues/77)** — user-definable range for
  connection nodes. Juanjo's call: campaigns place their comms towers without any such
  range in mind, so introducing one would change what is connected in campaigns already
  being played.

### Build

- `build-tools/build-compiled-script.ps1` concatenates the six `currenthill/` files,
  and no longer overwrites this README. It used to
  regenerate `README.md` from `README_source.md` on every build, which would erase this
  inventory; the generated documentation now goes to `DOCUMENTATION.md` instead.

## Building

```powershell
cd build-tools
./build-compiled-script.ps1 <version>
```

The compiled script lands in `demo-missions/skynet-iads-compiled.lua`. Retribution takes
that file into `resources/plugins/skynetiads/`.

The compiled output is plain concatenation of `skynet-iads-source/*.lua` in the order the
build script lists, which is what makes it possible to lift a feature out of a compiled
build and put it back into the sources — as was done for `ActMobile`.

## Licence

Unchanged from upstream; see [LICENSE.md](LICENSE.md).
