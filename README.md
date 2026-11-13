# ForeverQuestKey

**ForeverQuestKey** is a lightweight, zero-bloat NPC interaction and quest progression addon built for **World of Warcraft: Forever** (`Interface: 16001`). It streamlines questing with single-key dialogue progression, deterministic turn-in prioritization, class-aware reward protection, and custom audio feedback while preserving the stock Classic UI look and feel.

---

## Key Features

### 1. Single-Key Dialogue Progression
Bind a primary action key (`SPACE` by default) to step through every stage of NPC interaction:
- **Gossip & Greeting Frames**: Selects the highest-priority quest or dialogue option.
- **Quest Detail**: Accepts offered quests.
- **Quest Progress**: Advances completable quests to the reward screen.
- **Quest Complete**: Claims rewards automatically or prompts when a gear decision is required.

### 2. Deterministic Priority Queue
When interacting with NPCs offering multiple quests or services, **ForeverQuestKey** evaluates options in strict priority order:
1. **Completed Quests (Turn-Ins)**: Always prioritizes active quests ready for completion before picking up new ones.
2. **Available Quests (Pickups)**: Opens the first unaccepted quest once all turn-ins are finished.
3. **Single Service Option**: Automatically selects the gossip option if an NPC has zero quests and only a single service (e.g., Flight Master, Banker, Innkeeper, Vendor, or Trainer).

### 3. Smart Reward Handling & Class Gear Protection
Never accidentally vendor-pick over an equippable upgrade again:
- **Class Equipment Safeguard**: Inspects all multi-choice quest rewards against your character's class armor affinity (e.g., Mail/Leather for Hunter, Plate/Mail for Warrior) and weapon proficiencies. If a usable armor piece or weapon is detected, automatic turn-in pauses, highlights the item with a gold border, and displays an on-screen alert so you can choose manually.
- **Highest Vendor Value Selection**: When no usable class gear or weapon is offered (or when gear protection is disabled), automatically highlights and claims the item with the highest vendor sell price.

### 4. Customizable Audio Feedback
Configure and preview built-in Blizzard `SoundKit` effects directly in the settings menu for three distinct events:
- **Sound on Dismiss / Walk Away** (Default: *Parchment Fold*)
- **Sound on Quest Accept** (Default: *Parchment Rustle*)
- **Sound on Quest Complete / Turn-In** (Default: *Classic Fanfare*)

---

## Slash Commands & Configuration

Type either command in chat to open the standalone movable configuration window:

```text
/fqk
/foreverquest
