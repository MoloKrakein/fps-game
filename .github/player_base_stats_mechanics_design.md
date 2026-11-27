# Player Base Stats & Loadout Scaling Design

## 1. Overview & Design Philosophy
This document defines the foundational player statistics, loadout weight interactions, and combat formulas for the game. 

Unlike stealth-focused concealment systems, player agility and critical scaling are governed by **Swiftness** (Loadout Mobility)—a direct reflection of how light or heavy the player's equipped armor and weapons are. This creates a transparent build spectrum ranging from **Heavy Juggernauts** (high armor, high stagger, slow movement) to **Swift Skirmishers** (high dodge, high critical rate, fast movement, fragile armor).

---

## 2. Core Stat Categories

### A. Survival Stats
| Stat | Base Value | Description | Scaling & Mechanics |
| :--- | :--- | :--- | :--- |
| **Max Health** | `100` | Raw vitality pool. Reaching `0` triggers a downed/incapacitated state. | Does **not** regenerate passively; restored via medical items, skills, or specific Perk Deck triggers. |
| **Max Armor** | `50` (Base) | Regenerating protective buffer that absorbs damage before Health is touched. | Determined by equipped **Armor Rig** (`20` Light up to `180` Heavy) + Skill Tree bonuses. |
| **Armor Regen Delay** | `3.0s` | Time without taking damage before Armor begins regenerating. | Reduced by combat skills or active Perk Deck triggers (e.g., on-kill or on-stagger). |
| **Damage Mitigation** | `0%` (Base) | Percentage reduction applied to incoming Armor/Health damage. | Gained through heavy armor rigs, cover/stance skills, or defensive Perk Decks. |

> **Armor-Gating Rule:** When an incoming hit breaks the player's remaining Armor, excess damage from that single hit **does not** bleed into Health (except against specific heavy sniper/explosive attacks). This rewards maintaining even a sliver of Armor during intense firefights.

---

### B. Swiftness & Agility Stats (Concealment Replacement)
**Swiftness** is a `0` to `100` rating calculated directly from the player's equipped **Armor Rig**, **Primary Weapon**, and **Secondary Weapon**.

$$\text{Swiftness} = \text{clamp}\left(100 - (\text{Armor Weight} + \text{Primary Weight} + \text{Secondary Weight}),\ 0,\ 100\right)$$

| Stat | Base / Range | Description | How Swiftness Scales It |
| :--- | :--- | :--- | :--- |
| **Swiftness** | `0 – 100` | Master agility rating displayed clearly on the loadout screen. | Light gear keeps Swiftness near `80–100`; heavy rigs + LMGs drop it toward `10–30`. |
| **Move Speed** | `6.0 m/s` (Base) | Base walk/jog speed (Sprint is `1.45x` base speed). | Scales linearly from `-15%` (at `0` Swiftness) up to `+20%` (at `100` Swiftness). |
| **Stamina Pool** | `100` (Base) | Resource spent on sprinting, sliding, and vaulting. | High Swiftness reduces sprint/slide stamina drain and speeds up stamina recovery. |
| **Dodge Chance** | `0%` (Base) | Chance to completely negate an incoming bullet/projectile hit. | Requires Dodge-enabling skills/perks; scales with Swiftness and active movement states. |

---

### C. Offensive & Combat Handling Stats
| Stat | Base Value | Description | Scaling & Mechanics |
| :--- | :--- | :--- | :--- |
| **Crit Chance** | `5%` (Base) | Chance for a hit to deal **Critical Damage** (`2.0x` base) and apply bonus stagger. | Scales with **Swiftness** via Agility skills/perks (rewarding light, fast loadouts with burst lethality). |
| **Crit Multiplier** | `2.0x` | Damage multiplier applied on a successful Critical Hit. | Can be increased by precision/marksman skills or weapon attachments. |
| **Impact / Stagger** | `1.0x` | Multiplier to how easily hits stumble enemies or break enemy armor thresholds. | Heavier weapons and Bruiser skills increase Impact; Critical Hits also apply a `1.5x` stagger bonus. |
| **Weapon Handling** | `100%` | Governs ADS speed, weapon swap speed, recoil recovery, and reload speed. | Tuned through the normal Skill Tree and weapon mods. |

---

## 3. Dodge & Crit Scaling Formulas

To prevent pure RNG tanking while keeping fast playstyles rewarding, **Dodge** is split into a modest **Passive Base** and a stronger **Active Movement Bonus**:

### Dodge Calculation
$$\text{Total Dodge} = \min\left(\text{Skill/Perk Base Dodge} + \text{Swiftness Bonus} + \text{Action State Bonus},\ 55\%\right)$$

* **Swiftness Bonus:** Unlocks at `50+` Swiftness, granting `+0.4%` Dodge per point above `50` (up to `+20%` at `100` Swiftness) when the player has a Dodge Perk/Skill active.
* **Action State Bonus:** Sprinting, sliding, or mid-air vaulting grants an additional `+15%` Dodge (and `+10%` for `1.5s` immediately after a slide/vault).
* **Hard Cap:** Total Dodge is capped at **`55%`**. Any excess Dodge/Swiftness bonuses above the cap convert into `+0.5%` Move Speed and `+0.5%` Reload Speed per excess percent.

### Crit Chance Calculation
$$\text{Total Crit Chance} = \min\left(5\% + \text{Weapon/Skill Crit} + \text{Swiftness Crit Bonus},\ 45\%\right)$$

* **Swiftness Crit Bonus:** With the appropriate Agility skill/perk, every `2` points of Swiftness above `40` grants `+1%` Crit Chance (up to `+30%` at `100` Swiftness).

---

## 4. Loadout Archetype Examples

| Archetype | Armor & Weapons | Swiftness | Max Armor | Typical Dodge (Active) | Typical Crit Chance | Combat Role |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Swift Skirmisher** | Light Vest + SMG + Pistol | `90` | `30` | `45% – 55%` | `30% – 40%` | High-speed flanker; relies on sprinting/sliding, armor-gating, and crit staggers. |
| **Tactical Bruiser** | Medium Rig + Rifle + Shotgun | `55` | `85` | `15% – 25%` | `12% – 20%` | Balanced frontline fighter; mixes moderate armor sustain with light dodge/crit. |
| **Heavy Vanguard** | Heavy Rig + LMG + Launcher | `20` | `180` | `0%` | `5%` | Anchor tank; absorbs sustained fire, suppresses corridors, and shatters enemy armor. |

---

## 5. Godot Implementation Notes (Resource Architecture)
To keep this clean and modular in Godot 4:
* **`PlayerStatsResource` (`Resource`):** Holds base values (`base_health`, `base_armor`, `base_speed`, `armor_regen_delay`) plus equipment weight inputs.
* **`StatModifier` / Buff Pipeline:** Collects flat and percentage modifiers from equipped **Armor**, **Weapons**, **Skill Tree nodes**, and the **3-Tier Perk Deck** slots, recalculating derived stats (`swiftness`, `dodge_chance`, `crit_chance`, `move_speed`) whenever equipment or temporary combat states (e.g., `is_sprinting`, `is_sliding`) change.
* **UI Feedback:** Display `Swiftness` (`0–100`) alongside live previews of `Max Armor`, `Dodge % (Idle / Moving)`, and `Crit %` directly in the loadout menu so players can optimize breakpoints effortlessly.