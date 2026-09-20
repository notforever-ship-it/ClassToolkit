# Class Toolkit

Small, useful helpers for every class on Ravencraft (and other 1.12.1 servers). Each character only sees what fits its class, and everything can be switched off.

- **Swing timer.** Bars counting down to your next melee swing, Auto Shot or wand shot. The red end of the Auto Shot bar is the aim: stand still then, or the shot is delayed. With SuperWoW there's an off-hand bar too.
- **Buff reminder.** An icon appears when a buff your class keeps up is missing or about to run out: an aspect, an armor, a blessing or aura, Fortitude, Mark of the Wild and so on. Click it to cast, right-click to stop that reminder. Hunters also get a warning when Aspect of the Cheetah or the Pack is still on in a fight.
- **Spell ready icons.** Watch as many spells as you like. Each gets an icon that greys out with a countdown on cooldown, turns blue without the mana (or rage, or energy), red when the target is out of range, and says **READY** when you can cast it. Or keep **one** icon that shows whichever watched spell is ready first. Hunters start with Arcane Shot.
- **Reagent and ammo warnings.** A chat and mid-screen warning when you run low on a reagent you carry (Soul Shards, Ankhs, runes, candles, symbols, seeds, Flash Powder), and hunters' ammo at 200 and 50 shots.
- **Low ammo box** for hunters: a red box on screen when you're down to your last 2 stacks of arrows or bullets, showing the stacks and shots left.
- **Hunters:** a **range icon** (In range, Dead zone, Melee, Out of range) and a **pet feed reminder** that you click to feed.

These started out in [PokeHuntLog](https://github.com/notforever-ship-it/PokeHuntLog), the hunter pet collection log, and moved here so every class can use them.

## Install

**With an addon launcher** (RavenLaunch and similar): paste `https://github.com/notforever-ship-it/ClassToolkit` into its GitHub addon installer.

**By hand:**

1. Download the zip from the [latest release](https://github.com/notforever-ship-it/ClassToolkit/releases/latest). It contains a ready-made `ClassToolkit` folder.
2. Copy that folder into `World of Warcraft\Interface\AddOns\`. The path should end in `Interface\AddOns\ClassToolkit\ClassToolkit.toc`.
3. Fully restart the game. `/reload` doesn't pick up newly added addons.

## Use

- Type **`/ctk`** to open the options: what shows on this character, the spells with a ready icon, and **Unlock icons** for moving things around.
- Press **Help** in the options, or type **`/ctk help`**, for the How to use window.
- Settings are **per character**, so your Paladin and your Hunter can show different things. Icon positions are shared by all your characters.
- Anything a spell icon or the range icon needs to know about range has to come from an **action bar**: put the spell on any bar, even a page you never show.

### What starts switched on

| | Melee timer | Auto Shot / wand timer | Buff reminder | Spell ready | Reagents | Range and feed |
|---|---|---|---|---|---|---|
| Warrior, Rogue, Paladin, Shaman, Druid | yes | | yes | add your own | yes | |
| Priest, Mage, Warlock | | wand | yes | add your own | yes | |
| Hunter | yes | Auto Shot | yes | Arcane Shot | yes + ammo, low ammo box | yes |

### Buff reminders by class

| Class | Reminds about |
|---|---|
| Warrior | Battle Shout (in combat only) |
| Paladin | an aura, a blessing (Greater Blessings count) |
| Hunter | an aspect, Trueshot Aura; Cheetah or Pack left on in a fight |
| Priest | Fortitude, Inner Fire, Divine Spirit |
| Mage | Arcane Intellect, an armor |
| Warlock | Demon Skin or Demon Armor |
| Druid | Mark of the Wild, Thorns, Omen of Clarity |
| Shaman | Lightning Shield |

A reminder only appears once you know the spell. Buffs from other players count (a Prayer of Fortitude from your priest is fine).

### Commands

| Command | What it does |
|---|---|
| `/ctk` | Open the options window |
| `/ctk help` | Open the How to use window |
| `/ctk commands` | List every command in chat |
| `/ctk move` | Unlock or lock the icons and bars so you can drag them |
| `/ctk swing`, `/ctk ranged` | Melee timer, Auto Shot / wand timer on or off |
| `/ctk ready`, `/ctk buffs`, `/ctk reagents` | Spell ready icons, buff reminder, reagent warnings on or off |
| `/ctk range`, `/ctk feed`, `/ctk ammo` | Hunters: range icon, feed reminder, low ammo box on or off |
| `/ctk ammo <stacks>` | Hunters: show the low ammo box at this many stacks left (2 to start) |
| `/ctk watch <spell>` / `/ctk unwatch <spell>` | Add or remove a spell ready icon |
| `/ctk ready all` / `/ctk ready one` | An icon for every watched spell, or one for the next one ready |
| `/ctk feed content` / `/ctk feed unhappy` / `/ctk feed sound` | When the feed reminder shows, and its sound |
| `/ctk buffs reset` | Bring back buff reminders you right-clicked away |
| `/ctk counts` | List your reagents and ammo |
| `/ctk version` | Show which version you have |
| `/ctk debug on` | Show what the addon notices in chat, for bug reports |
| `/ctk reset` | Put this character's settings and all icon positions back to default |

## How it works

- **Swings.** With SuperWoW the game reports every swing and shot directly. Without it, melee swings come from the combat log (your hits and misses, and on-next-swing abilities like Heroic Strike, Raptor Strike and Maul), wand shots from "Your Shoot ..." lines, and Auto Shots from an arrow leaving the quiver while no special shot has just started the global cooldown.
- **Buffs.** 1.12 only tells addons a buff's icon, so names are read from each buff's tooltip.
- **Reagents.** A reagent is only watched once you've carried at least its warning amount, so nobody is told they're out of something they never use.
- The combat log parts only work on English game clients.

## Reporting bugs

Screenshot the problem, and include what `/ctk debug on` prints while it happens and any red error text.

## For developers

- The addon files live at the repo root, which is the layout launchers expect; `tools/` is development only and left out of release zips.
- `node tools/check-lua.js` parses every file as **Lua 5.0** and flags things the 1.12 client doesn't have.
- `node tools/install.js [path to Interface\AddOns]` copies the addon into a game folder.

## Credits

Made by stealthzi.

## License

MIT, see [LICENSE](LICENSE).

## Changelog

### 1.2.0

- **Watch as many spells as you like.** The four-spell limit is gone; the icons wrap onto another line past six, and the options window grows with the list.
- **One icon instead of a row:** *Ready icons: just the next one* in `/ctk` (or `/ctk ready one`) shows whichever watched spell you can cast now, or the one coming back soonest.
- While the icons are unlocked for dragging, every ready icon shows, so you can see how much room the row takes.

### 1.1.0

- **How to use window:** a Help button in `/ctk`, or `/ctk help`. `/ctk commands` lists every command in chat.
- **Low ammo box** for hunters: a red box on screen when you're down to your last 2 stacks of ammo, with the stacks and shots left. Its own switch in `/ctk`, draggable like the rest, and `/ctk ammo 3` changes when it shows.

### 1.0.0

- First release: swing timer for every class, buff reminder, spell ready icons, reagent and ammo warnings, and the hunter range icon and feed reminder from PokeHuntLog.
