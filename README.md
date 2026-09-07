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

- **Build radar coverage once per unordered pair.** Full coverage rebuilds compare each
  pair in both directions exactly once. Parent-state notifications are deferred until
  the existing final pass over all SAM sites; incremental updates retain immediate
  notifications for newly added edges and suppress duplicate-edge notifications.
  With 100 radar elements the directional range checks fall from 19,800 to 9,900. Tests
  cover asymmetric coverage, repeated rebuilds, incremental additions, duplicates and
  empty/single-site networks.
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
- **The HARM scan no longer runs for elements that cannot act on it.** It is scheduled
  every two seconds per live element and walks every contact against every radar. A
  point defence is excluded from going silent by `informOfHARM`, and an element whose
  HARM detection chance is zero can never roll high enough to react — and zero is
  Skynet's own default, so out of the box every site paid for a scan it could never use.

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

- `build-tools/build-compiled-script.ps1` no longer overwrites this README. It used to
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
