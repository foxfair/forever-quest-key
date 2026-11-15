# ForeverQuestKey

**ForeverQuestKey** is a lightweight, taint-safe World of Warcraft: Forever (`Interface: 16001` / client `1.60.1`) addon that lets you advance quest dialogs and NPC service menus using the **`SPACE`** key—automatically restoring `SPACE` back to **Jump** the moment dialogs close or while typing in chat.

---

## Features

* **One-Key Quest Progression (`SPACE`):** Advance smoothly from quest gossip/greeting lists through quest acceptance, objective completion, and reward turn-in without reaching for the mouse.
* **Vendor, Flight Master & Banker Gossip Support:** Automatically selects service dialogue options when no quests are pending:
  * **Vendors / Merchants:** *"I would like to buy from you"*, *"I would like to browse your goods"*, *"Show me your wares"*
  * **Flight Masters:** *"Where can I fly?"*, *"I'd like to book a flight"*, flight path prompts
  * **Bankers:** *"I would like to check my bank box"*, *"Access my bank"*
* **Smart Gossip Priority:** Always prioritizes **completed quests** (ready for turn-in) first, **available quests** second, and **NPC service options** (Vendor / Flight Master / Banker) third.
* **Taint-Safe Keybinding Lifecycle:** Uses `SetOverrideBindingClick` only while a quest or gossip window is active and you are not typing in an edit box. Closing the dialog or opening a vendor, flight map, or bank frame immediately restores `SPACE` to `JUMP`.
* **High-Contrast Status Banner:** Displays a clear yellow-and-black prompt banner above the quest frame showing the next `SPACE` action.
* **Movable `/fqk` Options & Live Debug Window:** Configure settings with checkboxes, view live `SPACE` interception status, and inspect or copy timestamped debug logs directly in-game.

---

## How `SPACE` Progression Works

When a dialog opens, **ForeverQuestKey** intercepts `SPACE` and executes the appropriate step:

| Dialog State | `SPACE` Action |
| :--- | :--- |
| **Gossip / Greeting Frame** | 1. Selects any **completed quest** ready to turn in.<br>2. Otherwise selects the first **available quest** to pick up.<br>3. Otherwise selects a **Vendor**, **Flight Master**, or **Banker** dialogue option (if enabled). |
| **Quest Detail Panel** | Accepts the quest (`AcceptQuest()`). |
| **Quest Progress Panel** | Continues to the reward screen if objectives are complete (`CompleteQuest()`). |
| **Quest Reward Panel** | Claims the reward if there are 0 or 1 reward choices, or claims your clicked reward choice (`GetQuestReward()`). |
| **Vendor / Flight Map / Bank Open** | Immediately releases `SPACE` back to **Jump**. |

---

## Options Window & Slash Commands

Type `/fqk` (or `/foreverquestkey`) in chat to open the movable **Options & Live Debug Log** window, or use quick slash toggles:

| Command | Description |
| :--- | :--- |
| `/fqk` | Open or close the draggable Options & Live Debug Log window (`Esc` to close). |
| `/fqk toggle` | Enable or disable `SPACE` interception globally. |
| `/fqk service` | Toggle automatic Vendor, Flight Master, and Banker gossip progression (`/fqk vendor` also works). |
| `/fqk sound` | Toggle UI sound feedback on `SPACE` actions. |
| `/fqk debug` | Toggle live debug logging in both the chat window and the `/fqk` log panel. |

---

## Installation

### CurseForge App / Website
1. Search for **ForeverQuestKey** on CurseForge (Project ID: `1803606`) targeting game version **1.60.1**.
2. Install into your WoW Forever `_classic_era_/Interface/AddOns/` directory.

### Manual Installation (GitHub Releases)
1. Download `ForeverQuestKey-v1.2.9.zip` from the [GitHub Releases](https://github.com/foxfair/forever-quest-key/releases) page.
2. Extract the archive so the folder structure is:
   ```text
   <WoW Directory Forever>/_classic_era_/Interface/AddOns/ForeverQuestKey/
   ├── Core.lua
   ├── ForeverQuestKey.toc
   └── README.md
