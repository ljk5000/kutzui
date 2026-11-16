# KutzUI

A cleaner, more readable interface for the **WoW Forever** client (game version 1.60.1,
`## Interface: 16001`) that keeps Blizzard's own look. Names fit on the bars, health and power
stay readable, chat prefixes are short, and the combat log can be limited to combat. Every part
is a switch in one window, `/kutz`.

> **Only for WoW Forever.** It uses APIs and behaviour of that client. It is not tested on Retail
> or Classic and shows as out of date there.

Screenshots coming soon.

## Download

`KutzUI-X.Y.Z.zip` on the [Releases](https://github.com/ljk5000/kutzui/releases) page holds three
addon folders that belong together, plus `SHA256SUMS.txt`.

| Folder | In the AddOns list | Required? |
| --- | --- | --- |
| `KutzUI` | KutzUI | Yes. The interface itself. |
| `KutzUI_Options` | KutzUI - Settings | Yes, if you want `/kutz`. It loads only when you open the window. |
| `KutzUI_Monitor` | KutzUI - Addon Monitor | No. Diagnostics, `/kutz mon`. Leave it unticked if you do not want it. |

KutzUI_Options and KutzUI_Monitor depend on KutzUI and share its `## Version`.

On a public repository each release zip has a build-provenance attestation. After you download one:

```
gh attestation verify KutzUI-X.Y.Z.zip -R ljk5000/kutzui
sha256sum -c SHA256SUMS.txt
```

## Install

1. Close the game.
2. Open `Interface\AddOns` in the game folder. For WoW Forever that is usually
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`. Create `AddOns` if it
   is missing.
3. Extract the zip **into** `AddOns`, so you get `AddOns\KutzUI\KutzUI.toc`, not
   `AddOns\KutzUI-1.0.0\KutzUI\...`.
4. Start the game. On the character screen, open **AddOns** and tick the ones you want.
5. In game, type `/kutz`.

A new or updated addon needs a **full game restart**. `/reload` is not enough the first time.

**Update:** close the game, delete the three old folders, extract the new zip, start the game.
Settings are kept. They live in `WTF`, not in the addon folders.

## Uninstall

1. Before you delete it, give the game back anything you changed, in `/kutz`:
   - **Combat log → Which combat log → "Blizzard's log, as I set it up myself"** restores the
     combat-log settings KutzUI copied the first time you applied a preset.
   - **Convenience → Blink 3 times at low health** off brings back Blizzard's red screen pulse.
   - **Damage meter**, **minimap coordinates**, and the **Game settings** pages write the game's
     own settings. Those stay as you left them after the addon is gone.
2. Close the game and delete `KutzUI`, `KutzUI_Options`, and `KutzUI_Monitor` from
   `Interface\AddOns`.
3. To delete your settings as well, delete `KutzUI.lua` and `KutzUI.lua.bak` in
   `WTF\Account\<your account>\SavedVariables\`. **Do not delete the whole `WTF` folder.**

## The settings window

Type `/kutz` (also `/kutz layout` or `/kutz menu`). The first time, KutzUI loads KutzUI_Options.
Drag the window by any empty spot. Esc closes it. **Toggle grid** in the footer draws a faint
alignment grid (red lines are the screen centre). A dim sidebar label means that part is switched
off.

The sidebar:

| Group | Pages |
| --- | --- |
| Setup | KutzUI package, Profiles, UI features |
| Units and combat | Unit frames, Cast bars, Party and targets, Nameplates, Combat log, Damage meter |
| Interface | Fonts, Chat, Window positions, Action bars, Minimap, Tooltip placement, Tooltips and bags, FPS and latency, Convenience |
| Game | Game settings, Sound / advanced |

**UI features** is the module list. A module that is off creates no frames, timers, or events, and
leaves Blizzard's look for that part alone. Changing a switch is saved at once and applied after
**Reload UI** on that page (the same as `/reload`).

The **KutzUI package** page is a short guide to the three addons above. It also names a separate
inventory addon and a desktop companion, both in
[ljk5000/kutz-inventory](https://github.com/ljk5000/kutz-inventory). Neither is in this repository,
and this addon does not start them. See [Privacy](#privacy).

## Features

### Unit frames

Module `frames` (`UnitBars`, `UnitText`, `PartyBars`, `Names`, `Layout`).

KutzUI's own health and power bars for Player and Target, wider and taller than Blizzard's and
the same size on both. A square portrait (a flat picture, or a 3D model) sits in the same gold
border. The name is inside the health bar and wraps: Target shows the whole name, Player shows
your first name. You can hide first or last names and set the name size. Blizzard's combat glow
is held invisible. The target's buffs sit under the frame, and its debuffs can have their
own row above it. Player and Target are placed on
each side of the screen, with a size slider.

There is an always-on target-of-target: a health bar only, coloured by class or by a colour you
pick. Click it to target that unit.

Party frames (still the `frames` module) restyle Blizzard's classic party frames: about 15
characters wide, the name on two lines, health number and percent, power, and the role icon.
They stay clickable, including in combat.

### Party targets

Module `partytargets`. Beside each party frame, a small bar for what that member is targeting,
and one for that target's target. Click a bar to target it. Right-click opens its menu.

### Cast bars

Module `castbars` (also `Layout`). Two bars, Player and Target, placed on their own. Each shows
the spell icon, the spell name, and the time (counting down, `1.2 / 2.5`, or none). Your bar can
show a red latency safe zone. A cast you cannot interrupt gets a shield and a grey bar. Width,
thickness, square / rounded / pill corners, a set of bar textures (generated ones, several of
Blizzard's, and a flat fill, plus any texture another addon registers with LibSharedMedia), any
colour or the class colour, and fill from the left or the right.

### Nameplates

Module `nameplates`. On Blizzard's nameplates: health percent, the whole name, and a gold outline
on your target's plate. The same page also has the game's own nameplate switches (who gets a
plate, distance, overlap or stack).

### Action bars

Module `actionbars`. Experience numbers and percent on the XP bar, including rested XP. Hide the
page number and arrows, hide the gryphon end caps, or lock paging so the page keys do nothing.
Stance, vehicle, and possess bars still change. Size sliders.

Module `keybinds`, separate switch. Action-button labels use `M4` and `M5` instead of the
spelled-out mouse-button names. The Action bars page can also turn on Blizzard's cooldown numbers.

### Fonts

Module `fonts`. One monospace, slashed-zero font for the text this addon draws: Inconsolata
(the start), Roboto Mono, or Anonymous Pro. **Use this font everywhere** also sets it on
Blizzard's windows (character sheet, spellbook, professions, quest log, tooltips, error text,
chat). Floating combat numbers can use it too. Changing the game font, a new texture, or the
floating-combat font needs a full restart. **Default (Blizzard)** puts the game font back.

### Chat

Module `chat` (`ChatTags`, `Chat`, `ChatCopy`).

Short colour-coded prefixes: `[1. General - Elwynn Forest]` becomes `[1]`, party `[P]`, guild
`[G]`, raid `[R]`, and the same idea for officer, instance, and raid leader. Say, yell, and
whisper become `[Name][S]:`, `[Y]`, and `[W]`. Each kind has its own colour. Names stay
clickable. Enter always opens the main chat box. Font size, line spacing, text and background
opacity, and timestamps (seconds, 24-hour). Hide the chat buttons or the scroll bar, or fade
the tabs until the mouse is over the chat.

**Copy chat** (`/kutz copy`, or the button on a chat window) opens the lines as plain text you
can select. Lines the game will not show to an addon are counted, not guessed. The history
length is adjustable (Blizzard's own default is 128). There is also the game's profanity-filter
switch, labelled "Show uncensored words".

### Combat log

Module `combatlog` (`CombatLog`, `CombatFormat`, `CombatLogView`, `CombatPresets`, `KutzLog`,
`KutzLogFeed`).

The window can be transparent and borderless, with the tab and text box hidden and the filter
buttons flush with the bottom of the screen. **Only real combat in this window** keeps crafting,
experience, and some loot lines out of it. General chat is not affected.

**Which combat log:**

- Blizzard's log, as you set it up yourself
- Blizzard's log, out of the box
- Blizzard's log, with timestamps, short lines, class colours, school colours, and raid markers
- **KutzUI log**: KutzUI's own window in that spot. A log of your casts and of hits on you, your
  target, and your pet, plus Damage / Healing / Taken / Deaths bars from the game's damage-meter
  data

The game seals the words of Blizzard's combat lines, so an addon cannot recolour or rewrite them,
and KutzUI's own log cannot say who hit you or with which spell. Choosing a Blizzard preset
writes Blizzard's saved settings and reloads at once. Your previous settings are kept in
`KutzUIDB.clogBlizzBackup`. The first time the combat-only routing is installed while you are
already in game, `/reload` twice: once to load the code, once to save and apply the filters.
That routing backup is `KutzUIDB.clogRoutingBackup`.

### Damage meter

Module `damagemeter`. Turns on Blizzard's own damage meter, in your font, and can show the meter,
the combat log, or both. `/kutz meter`, `/kutz meter log`, `/kutz meter meter`, or
`/kutz meter both`. An optional small Log / Meter button sits on the combat log.

### Tooltips, bags, and item text

Module `tooltip` (`TooltipTweaks`, `TooltipExtras`, `TooltipCompare`) and module `movers`.

- Three tooltip spots you drag into place. For each kind of thing you point at (player, NPC,
  object, item, action button, party, raid, your frames, buffs, anything else) choose Blizzard's
  spot, the cursor, or one of the three. The cursor choice stays on the side of the pointer that
  has room.
- The combined backpack can be dragged. It remembers where you left it. `/kutz bags reset` puts
  it back. `/kutz move` shows the tooltip spots; `/kutz move reset` restores them.
- Tooltip scale, a shorter fade, and the option to hide the health bar on tooltips.
- Unit tooltips: class-coloured names, faction emblem and class icon, `Lvl 7  Human  Paladin`,
  the guild in green angle brackets, and Away / Busy / Offline / Dead.
- Optional lines: who that unit is targeting, an item-quality border, an EQUIPPED / NOT EQUIPPED
  label when the game compares gear, and item, spell, aura, and NPC ids.
- Module `itemlevel`. Item level on character-sheet slots and on weapons and armour in your bags,
  coloured by quality.
- Module `junkhint`. When every bag slot is full, a red border on the five stacks that would
  sell for the least, so you can see what to delete. Quest items and anything with no vendor
  price are skipped. Nothing is marked while a slot is free.

### Minimap

Module `minimap` (`Minimap`, `MapCoords`). Show or hide each button around the minimap, including
other addons' LibDBIcon buttons. The map, its border, and the zone name stay. The clock can move
to the top-right corner of the screen. Coordinates on the minimap and a line on the world map
(`Player 45.2, 63.1  Cursor 51.0, 70.3`). Inside a dungeon or raid the game hides your position,
so that side shows `--`.

### Windows and the FPS line

Module `windows`. Type the exact X, Y, width, and height of the chat window and the combat log.
X and Y are the bottom-left corner, in pixels from the bottom-left of the screen.

Module `fpsreadout`. One small line, like `144 fps  38 ms`, with no background and no click
target. The latency is the world latency. Default place is the top-left corner. Top-centre, or
just left of the minimap, or an X / Y offset.

### Crafting

Module `craftingtime`. Under the profession window, an estimate of how long Create and Create All
will take. While you craft, it counts down the crafts left and the time left, using the real cast
time. Create All uses the most you can make. The keyboard or a controller uses the number in the
quantity box. Cancelling clears it. A new install needs a full restart.

Module `subcraft`, its own switch. Shows how many crafts your materials support, including parts
you can make. Type any quantity up to that maximum in KutzUI's box (`Max crafts: N  Qty:`), then
click **Make N (parts first)**. Each missing part is made in one batch, deepest parts first, then
the parent batch. This still works when Blizzard's quantity box is disabled because the parts are
missing. One click starts the run. If the game refuses to start the next recipe by itself, the
button changes to **Next** and waits for a click. **Stop** cancels the remaining steps after the
current cast. Only learned recipes of the open profession are used: a bar you would smelt with
Mining for a Blacksmithing recipe is listed as missing. Optional and finishing reagents are
ignored. A linked, guild, or NPC profession is left alone.

### Convenience

Module `convenience` (`Convenience`, `BuyAmount`, `LowHealthBlink`). Each chore has its own
switch. At the start: sell grey junk, repair, fast loot, decline duels, the buy-amount box, the
low-health blink, and the achievement screenshot are on. The rest are off.

- At a vendor: sell grey junk (you can buy it back), repair (from your gold, or from the guild
  bank when your rank allows it), and **type the amount when buying**. Shift-click an item and
  type any number. The box shows the total and will not buy more than you can afford. Items paid
  with tokens or other items still use Blizzard's popup.
- Fast loot, while Blizzard's auto-loot is on.
- Decline duels. Accept a summon (not in combat). Accept a group invite from a friend, a
  Battle.net friend, or a guild member. Anyone else still gets the normal popup.
- A screenshot a moment after an achievement, and optionally after a level-up. Files go to the
  game's `Screenshots` folder.
- **Low health:** instead of Blizzard's red pulse for as long as you are under 35%, the screen
  edge blinks red three times, faintly, when you drop under 35%. It blinks again only after you
  have been back above 35%.

### Game settings

Not a module. The two Game pages read and write the game's own settings (CVars), so Blizzard's
options window agrees with them. Combat and casting (cast on key press, self-cast, spell-alert
opacity, floating combat text), camera and mouse, loot, a handful of interface switches, the
game's nameplate switches, sound, UI scale, and the frame-rate cap. **Any game setting** looks
up or sets a CVar by name.

### Always on

These are not in the module list. They load with KutzUI.

- `Core` holds the module switches, `/kutz`, `/kutz mem`, and `/kutz debug`.
- `Profiles` applies this character's profile before anything else reads a setting.
- `Grid` is the alignment grid (`/kutz grid`). It is off each time you log in, draws nothing
  until you ask, and never takes mouse clicks.
- `Common` is shared helpers (fonts, bar textures, text).

## Slash commands

`/kutz` with no extra word opens the window. With a word it does not know, it prints the
commands that are registered right now. A module that is off does not register its commands.

| Command | Needs | What it does |
| --- | --- | --- |
| `/kutz` | KutzUI_Options | Open or close the settings window. |
| `/kutz copy` | Chat | Copy the chat tab you are looking at. |
| `/kutz mon` | Addon monitor | Open the report. Also `print`, `reset`, `alert on\|off`, `cpu on\|off`. |
| `/kutz meter` | Damage meter | Swap log and meter. Also `log`, `meter`, `both`. |
| `/kutz grid` | (always) | Show or hide the alignment grid. |
| `/kutz tab` | Combat log | Show or hide the combat-log tab. |
| `/kutz log` | Combat log | Restyle the combat log now. |
| `/kutz move` | Bag and tooltip | Show the three tooltip spots. `reset` puts them back. |
| `/kutz bags` | Bag and tooltip | How to drag the bag. `reset` forgets the saved spot. |
| `/kutz mem` | (always) | Memory of every loaded addon, and of KutzUI after a garbage-collect. |
| `/kutz debug` | (always) | A short status line from each module that registered one. |

`/kutz mon cpu on` turns on the game's script profiler and needs `/reload`. It slows the game a
little. `/kutz mon cpu off`, then `/reload`, turns it off. `/kutz mon alert off` stops the chat
line that announces a new Lua error.

## Profiles

On the Profiles page. Each character gets a profile of its own the first time it logs in, named
after it (`Name-Realm`, at most 32 characters), copied from the settings in use at that moment.
The active profile follows later changes: it is written again at logout, reload, and when you
switch. **Load** replaces your settings with that profile; reload to apply them. **Char** pins a
profile to this character, or clears the pin so the character uses whatever is active and does
not get a new automatic profile.

**Create export text** turns the current settings into one line beginning with `KUTZ1:`. The
importer is a strict parser. It checks a checksum, refuses text that is too long, too deep, or
the wrong shape, and it never runs the text as code. Import saves a new profile and does not
touch the settings you are using until you load it.

Three things are account-wide and are not stored inside a profile: the profile list itself, which
character uses which profile, and which profile is active. Combat-log backups, the memory log,
and the addon monitor's notes are also left out of a profile.

## What is saved on your PC

The game writes `WTF\Account\<account>\SavedVariables\KutzUI.lua` at `/reload` and logout.
KutzUI_Options and KutzUI_Monitor have no saved-variable file of their own.

| In `KutzUIDB` | What it is |
| --- | --- |
| The settings each page edits | Fonts, bars, chat, windows, minimap, convenience switches, and the rest. A module that is on is stored by the key being absent; off is `false`. |
| `profiles`, `activeProfile` | Named copies of those settings, and which one is active. |
| `charProfile` | `Name-Realm` to a profile name, or `false` if that character should not get its own. |
| `clogBlizzBackup` | A copy of Blizzard's combat-log filter settings, taken the first time a preset is applied. |
| `clogRoutingBackup` | A copy of which messages were routed into the combat log, taken the first time the combat-only view changes that routing. |
| `memLog` | Up to 48 notes of every loaded addon's memory use: about every five minutes out of combat, and each `/kutz mem`. Addon name and a size, not your chat. |
| `monitor` | Only if the addon monitor has run. The current session (errors, blocked actions, frame times, CPU samples), short summaries of the five sessions before it, and `findings`, a ranked copy of the same facts in plain text and numbers. |
| `bags` and the tooltip spots | Where you dragged the bag and the three tooltip locations. |

Also outside that file:

| What | Where | When |
| --- | --- | --- |
| Game settings you change on KutzUI's pages, plus the damage meter, minimap coordinates, and the low-health flash | The game's own settings | Only when you flip that switch |
| Blizzard's combat-log filters | `SavedVariables\Blizzard_CombatLog.lua` | Only when you apply a combat-log preset |
| Screenshots | The game's `Screenshots` folder | Only with the achievement or level-up switch on |

## KutzUI_Monitor

Optional. It has to be ticked in the AddOns list **and** left on under UI features. It watches
every loaded addon, not only KutzUI.

- Lua errors, counted per message. Blizzard's error window is unchanged. A new error can print
  one chat line (`/kutz mon alert off` stops that).
- Blocked (tainted) actions: `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN`.
- How long each frame took, and every hitch of 100 ms or more.
- Memory now, and how fast each addon is growing, from the log Core already keeps.
- CPU per addon, only while the game's script profiler is on (`/kutz mon cpu on`).

`/kutz mon` opens the report: a ranked list of what is worth fixing, then one row per addon, then
the details. `/kutz mon print` puts the top of that list in chat. `/kutz mon reset` starts the
counters again. The notes survive logout in `KutzUIDB.monitor`.

## Privacy

KutzUI's Lua does not open a network connection. It does not send addon messages, join a chat
channel, or post chat. There is no `SendAddonMessage`, `SendChatMessage`, or HTTP call in this
repository.

A few switches ask the game to do what its own buttons do: accept a group invite from a friend
or guild member, decline a duel, accept a summon, repair, sell junk, loot, or take a screenshot.
That is the game client acting on your character, the same as a click. It is not a message to
anyone else, and those switches are yours to turn off.

Nothing is uploaded by installing the addon. The KutzUI package page describes a separate desktop
program, KutzUI Companion: if you run it, point it at the game folder, and connect a key, that
program watches the game's save files and uploads a snapshot after `/reload` or logout. That
program is not in this repository, installing KutzUI does not start it, and the addon never
stores that key. It lives with the inventory addon in
[ljk5000/kutz-inventory](https://github.com/ljk5000/kutz-inventory), whose README explains exactly
what it reads and sends.

What does stay on disk is listed above. `charProfile` contains character and realm names.
`monitor` can contain Lua error text and addon file paths. A profile export is a line of text
you copy yourself. The importer does not execute it.

## Known limits

KutzUI changes Blizzard's frames: player, target, and party frames, cast bars, nameplates, chat,
the combat log, tooltips, minimap buttons, and fonts. Another addon that restyles the same thing
can fight it. Turn off KutzUI's module for that part and `/reload`.

It is used day to day alongside Questie. Other combinations have not been tried.

The combat log's text is sealed. Presets only change Blizzard's saved filter settings, then
reload. KutzUI's own log is built from `UNIT_COMBAT`, your casts, deaths, and the damage meter.

The game font, new textures, and the floating combat-text font need a full restart.

## Building and testing

**Run it from a clone.** Link the three folders into `Interface\AddOns` (no admin rights). In
PowerShell, from the clone:

```
$addons = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
foreach ($a in "KutzUI","KutzUI_Options","KutzUI_Monitor") {
  New-Item -ItemType Junction -Path "$addons\$a" -Target "$PWD\$a"
}
```

**Offline checks** (Node 22):

```
cd tools
npm ci
node check_all.js ../KutzUI
```

That is syntax, the Lua 5.1 limits, a global-name typo check, and a fake game with every module
on, with the monitor addon missing, with an old profile fixture, and with each module off in
turn. `ALL CHECKS PASSED` means the logic ran. It does not tell you how something looks. See
[tools/README.md](tools/README.md). GitHub Actions runs the same command on every push and pull
request.

An optional secret-value lint (taintlint) runs only when `TAINTLINT_DIR` points at a clone of
that tool. Without it, the step is skipped.

**Textures.** `python -I tools/make_textures.py KutzUI/Media/Textures` regenerates the cast-bar
textures and corner masks. They are original.

**A release.** KutzUI_Options and KutzUI_Monitor share KutzUI's `## Version`. CI does not create
tags.

```
node tools/tag_release.js            # print the vX.Y.Z tag for HEAD
node tools/tag_release.js --apply    # create that lightweight tag; it does not push
git push origin vX.Y.Z
```

`.github/workflows/release-addons.yml` builds the zip with the BigWigs packager (`.pkgmeta`),
checks it as if it were the only thing in an empty AddOns folder, and on a `vX.Y.Z` tag publishes
`KutzUI-X.Y.Z.zip` and `SHA256SUMS.txt`. The tag must match the `.toc` version or the build
stops. The publish job has `contents: write`, `id-token: write`, and `attestations: write`.
Build provenance is attached when the repository is public. GitHub does not store attestations
for a private repository, so that step is skipped until the repository is public and then runs
on the next tagged release. No older zip is attested after the fact.

### This client, in short

- Do not hook Blizzard frames or functions. A hook taints them. The modules poll instead.
- Values the game hides are "secret". Never compare them or do arithmetic on them. `issecretvalue`
  is the guard.
- Protected frames cannot change in combat. Changes wait for `PLAYER_REGEN_ENABLED`.
- Combat-log lines reach addons as opaque tokens. Writing Blizzard's combat-log settings through
  its API, or listening to the raw combat-log event, is blocked. Presets write the saved settings
  and reload.
- `Font:SetFont` returns nothing on this client even when it works. Check with `GetFont()`.
- Blizzard's UI source for this build is the public `forever` branch of `Gethe/wow-ui-source`.

## Licence

The code and the generated textures are [MIT](LICENSE). The bundled fonts are SIL Open Font
License 1.1 and are not MIT: Anonymous Pro (Mark Simonson, reserved font name "Anonymous Pro"),
Inconsolata, and Roboto Mono. Each licence file sits beside its font. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). The repository follows
[REUSE](https://reuse.software).

World of Warcraft is a trademark of Blizzard Entertainment, Inc. KutzUI is not made or endorsed
by Blizzard.

## Security

Report a security issue privately. See [SECURITY.md](SECURITY.md).
