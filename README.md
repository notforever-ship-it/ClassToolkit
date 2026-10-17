# Class Toolkit

Small helpers for every class on Ravencraft and other 1.12.1 servers.

- Each character only sees what fits its class.
- Everything can be switched off.

## What it does

- **Swing timer**: bars count down to your next swing, Auto Shot or wand shot.
- **Buff reminder**: an icon when a class buff is missing or running out. Click it to cast.
- **Spell ready icons**: one icon per spell you watch. Shows cooldown, mana, range and **READY**.
- **Cooldown ready flash**: a spell's icon pops up mid-screen for about 5 seconds when its cooldown ends.
- **DoT timers**: a watched DoT counts down on your target, then says **APPLY**.
- **Reagent and ammo warnings**: in chat and mid-screen when you run low.
- **Range icon**: is your target in range of your main attack (or a spell you pick)?
- **Hunters**: aggro meter, low ammo box, pet feed reminder, pet eating warning.

These started in [PokeHuntLog](https://github.com/notforever-ship-it/PokeHuntLog) and moved here for every class.

## Install

- Launcher (RavenLaunch and similar): paste `https://github.com/notforever-ship-it/ClassToolkit` into its GitHub addon installer.
- By hand: download the zip from the [latest release](https://github.com/notforever-ship-it/ClassToolkit/releases/latest).
- Copy the `ClassToolkit` folder into `World of Warcraft\Interface\AddOns\`.
- The path should end in `Interface\AddOns\ClassToolkit\ClassToolkit.toc`.
- Close the game completely and start it again. `/reload` does not find new addons.

## Start

- Type **`/ctk`** for the options.
- Press **Help** there, or type **`/ctk help`**, for the How to use window.
- **Unlock icons**: drag icons and bars. **Lock icons** when done.
- Settings are per character. Icon positions are shared.
- Range checks need the spell on an **action bar** (any slot, any page).

## Swing timer

- Counts down to your next melee swing, Auto Shot or wand shot.
- Auto Shot: at the red end, stand still or the shot is delayed.
- With SuperWoW you get an off-hand bar too.

## Buff reminder

- An icon when a class buff is missing or running out.
- Click it to cast. Right-click to stop that reminder.
- `/ctk buffs reset` brings stopped reminders back.
- Only shows once you know the spell.
- Buffs from other players count.
- Hunters: a warning when Cheetah or Pack is on in a fight.

| Class | Reminds about |
|---|---|
| Warrior | Battle Shout (in combat only) |
| Paladin | an aura, a blessing (Greater Blessings count) |
| Hunter | an aspect, Trueshot Aura |
| Priest | Fortitude, Inner Fire, Divine Spirit |
| Mage | Arcane Intellect, an armor |
| Warlock | Demon Skin or Demon Armor |
| Druid | Mark of the Wild, Thorns, Omen of Clarity |
| Shaman | Lightning Shield |

## Spell ready icons

- Add as many spells as you like in `/ctk`.
- Shown in combat or with an enemy targeted.
- Grey with a number: cooling down.
- Blue: not enough mana, rage or energy.
- Red: out of range.
- **READY**: cast it.
- **Ready icons: just the next one**: one icon for the next spell ready.
- **Cooldown ready flash**: any spell's icon pops up mid-screen when its cooldown ends (on by default; unlock icons to move it).
- Hunters start with Arcane Shot.

## DoT timers

- Purple countdown while your DoT ticks on your current target.
- Orange for the last 3 seconds, then **APPLY**.
- `/ctk dot` lists the lengths read from the tooltips.
- `/ctk dot Rend 12` fixes one. Use `off` or `auto` in place of the number.

## Reagents and ammo

- Watched: Soul Shards, Ankhs, runes, candles, symbols, seeds, Flash Powder.
- A reagent is only watched once you have carried enough of it.
- `/ctk counts` lists what you have.
- Hunters: ammo warnings at 200 and 50 shots.
- Hunters: a red **low ammo box** when equipped ammo is down to 100 shots.
- `/ctk ammo <shots>` changes that number.
- The box also shows **OUT OF AMMO** when a bow, gun or crossbow has no ammo equipped.
- Only the equipped stack counts, not your bags.

## Range icon

- Watches your class's main attack to start.
- `/ctk range <spell>`, or the box in `/ctk`, picks another.
- Shows In range (with yards), Melee, Under 10 yd, Under 28 yd or Out of range.
- Hunters: **Dead zone** when neither shot nor Wing Clip lands.
- Hunters get a plain bow picture.

## Hunters

- **Aggro meter**: how close you are to pulling the mob off your pet.
- It shows who the mob attacks, and says Shoot, Ease off, Hold or Feign Death.
- It learns your server's Growl as you fight.
- `/ctk aggro growl <threat>` sets Growl. `/ctk aggro reset` forgets.
- **Feed reminder**: a face when your pet is not happy. Click it, then a food.
- **Pet eating warning**: don't attack while it shows. Attacking ends the meal.

## What starts switched on

| | Melee timer | Auto Shot / wand timer | Buff reminder | Spell ready | Reagents | Range icon | Aggro meter and feed |
|---|---|---|---|---|---|---|---|
| Warrior, Rogue, Paladin, Shaman, Druid | yes | | yes | add your own | yes | yes | |
| Priest, Mage, Warlock | | wand | yes | add your own | yes | yes | |
| Hunter | yes | Auto Shot | yes | Arcane Shot | yes + ammo, low ammo box | yes | yes |

## Commands

| Command | What it does |
|---|---|
| `/ctk` | Options window |
| `/ctk help` | How to use window |
| `/ctk commands` | Every command in chat |
| `/ctk move` (or `lock`, `unlock`) | Unlock or lock the icons for dragging |
| `/ctk swing`, `/ctk ranged` | Melee timer, Auto Shot / wand timer on or off |
| `/ctk ready`, `/ctk one` | Spell ready icons, just the next one, on or off |
| `/ctk pulse` | Cooldown ready flash on or off |
| `/ctk buffs`, `/ctk reagents`, `/ctk range` | Buff reminder, reagent warnings, range icon on or off |
| `/ctk aggro`, `/ctk feed`, `/ctk eating`, `/ctk ammo` | Hunters: aggro meter, feed reminder, eating warning, low ammo box on or off |
| `/ctk range <spell>` | Spell the range icon watches |
| `/ctk watch <spell>` | Add a spell ready icon |
| `/ctk unwatch <spell>` | Remove one |
| `/ctk ready all` / `/ctk ready one` | Every watched spell, or just the next one |
| `/ctk dot` | List the DoT lengths |
| `/ctk dot <spell> <seconds>` (or `off`, `auto`) | Fix one DoT length |
| `/ctk aggro growl <threat>` (or `auto`) | Set what Growl is worth |
| `/ctk aggro reset` | Forget what the aggro meter learned |
| `/ctk feed content` / `/ctk feed unhappy` | When the feed reminder shows |
| `/ctk feed sound` | Feed reminder sound on or off |
| `/ctk ammo <shots>` | Low ammo box level (100 to start) |
| `/ctk ammodebug` | What the game says about your ammo slot |
| `/ctk buffs reset` | Bring back hidden buff reminders |
| `/ctk counts` | List your reagents and ammo |
| `/ctk version` | Show your version |
| `/ctk debug on` | Show what the addon notices, for bug reports |
| `/ctk reset` | This character's settings and all icon positions back to default |

## How it works

- **Swings**: SuperWoW reports every swing. Without it, the combat log is read.
- **Buffs**: names are read from each buff's tooltip.
- **Reagents**: only watched once you have carried the warning amount.
- The combat log parts only work on English game clients.

## Reporting bugs

- Take a screenshot of the problem.
- Add what `/ctk debug on` prints, and any red error text.

## For developers

- The addon files sit at the repo root (launchers expect that).
- `tools/` is for development only and left out of release zips.
- `node tools/check-lua.js` checks every file as **Lua 5.0**.
- `node tools/install.js [path to Interface\AddOns]` copies the addon into a game folder.

## Credits

Made by stealthzi.

## License

MIT, see [LICENSE](LICENSE).

## Changelog

### 1.5.5

- **Cooldown ready flash.** When a spell with a cooldown over 7 seconds comes back (so not Arcane Shot), its icon pops up in the middle of the screen for about 5 seconds, then fades. Switch in `/ctk` or `/ctk pulse`; unlock the icons to move it.

### 1.5.4

- **Pet eating warning for hunters.** After you feed your pet, an icon with the Feed Pet picture and the words "Pet is eating: don't attack" shows while the pet has the eating buff, and goes away the moment the buff is gone. Attacking while the pet eats cancels the meal. Its own switch in `/ctk` (on to start), `/ctk eating` in chat, and you can drag it like the other icons.

### 1.5.3

- **The low ammo box no longer cries wolf.** Some clients do not give the ammo slot an item name, which made the box say OUT OF AMMO with a full quiver. It now reads the equipped count directly, and only says OUT OF AMMO when a bow, gun or crossbow is in your hand, the ammo slot is empty, and there is no ammo in your bags either. If the count cannot be read it says nothing.
- `/ctk ammodebug` prints what the game says about your ammo slot, to find out why the box does or does not show.
- The Help window shows the version, like the other windows.

### 1.5.2

- **The low ammo box only looks at the ammo you have equipped**, not your bags: it shows when that stack is down to 100 shots (`/ctk ammo <shots>` to change; it used to count spare stacks), and shows "OUT OF AMMO" when a bow, gun or crossbow is in your hand with no ammo equipped.
- **The range icon is a plain bow for hunters**, so it looks the same every time. Before, it borrowed the watched spell's picture, which came and went depending on where the spell sat on your action bars. Other classes still get the watched spell's picture.

### 1.5.1

- **The low ammo box is easier to see.** It now counts the equipped stack as well as the stacks in your bags, shows whenever you are down to 200 shots or fewer in all (the same level as the first chat warning), and shows "OUT OF AMMO" when a bow, gun or crossbow is in your hand and no ammo is equipped. Before, it only counted spare stacks in your bags and showed nothing with an empty quiver slot.

### 1.5.0

- **Aggro meter for hunters.** A bar showing how close you are to pulling the mob off your pet, who the mob is really attacking, and what to do: Shoot, Ease off, Hold, or Feign Death. Threat is counted from the combat log (damage, Growl, Distracting Shot, Feign Death) and corrected by what the mob attacks, so it learns your server's Growl numbers as you fight. Switch in `/ctk` or `/ctk aggro`; `/ctk aggro growl <threat>` if you know what Growl is worth on your server.

### 1.4.1

- The range icon showed a question mark for some spells (the hunter's Auto Shot among them) because the client gave no icon for them when the spellbook was read. The icon is now taken from the action button holding the spell instead, so the ready icons and DoT timers get it too.

### 1.4.0

- DoT timers on the spell ready icons.

### 1.3.0

- Range icon for every class: it watches your class's main attack, or any spell you pick with `/ctk range <spell>`.

### 1.2.0

- **Watch as many spells as you like.** The four-spell limit is gone; the icons wrap onto another line past six, and the options window grows with the list.
- **One icon instead of a row:** *Ready icons: just the next one* in `/ctk` (or `/ctk ready one`) shows whichever watched spell you can cast now, or the one coming back soonest.
- While the icons are unlocked for dragging, every ready icon shows, so you can see how much room the row takes.

### 1.1.0

- **How to use window:** a Help button in `/ctk`, or `/ctk help`. `/ctk commands` lists every command in chat.
- **Low ammo box** for hunters: a red box on screen when you're down to your last 2 stacks of ammo, with the stacks and shots left. Its own switch in `/ctk`, draggable like the rest, and `/ctk ammo 3` changes when it shows.

### 1.0.0

- First release: swing timer for every class, buff reminder, spell ready icons, reagent and ammo warnings, and the hunter range icon and feed reminder from PokeHuntLog.
