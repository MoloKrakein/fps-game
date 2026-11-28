# Implementation Roadmap & Complementary Skill Tree

## 1. Complementary 4-Tier "Ace-to-Skip" Skill Tree
The Skill Tree supports the **3-Slot Perk Deck** by tuning gunplay/handling, armor/stagger numbers, stamina/Swiftness, and objective speed.

### Progression & Skip Rules
- **Basic (`1 pt`):** Unlocks the skill and allows normal progression to the next tier.
- **Ace (`+2 pts`, `3 pts` total):** Boosts the skill's effect and provides **Tier Skip** leverage:
  - Buying any Basic skill on Tier $N$ unlocks Tier $N+1$ normally.
  - **Acing both skills on a tier** (e.g., Tier 1 or Tier 2) lets the player **bypass/skip the next tier** (e.g., jump from Tier 1 to Tier 3), trading breadth/points for deeper specialization and faster access to higher-tier nodes.
- **Constraint:** Keep point budgets and capstone requirements balanced so skipping a tier feels earned rather than mandatory.

### Suggested Complementary Skill Domains (Mechanics First)
- **Mobility & Handling:** Stamina/tiredness efficiency, dodge/Swiftness tuning (mindful of the `55%` dodge cap and reload-speed overflow penalty), recoil/spread/swap/reload speed.
- **Impact & Armor:** Stumble intensity/knockdown tuning, armor mitigation/regen timing, objective interaction speed.
- **Payoff & Control:** Bonus damage or cooldown/Focus refunds tied to stumbles, armor breaks, crits, or *Broken* morale.

---

## 2. Mechanic Verification Checklist (Before Theming)
Ensure every underlying combat hook actually executes in gameplay before writing final Tarot copy/UI:

1. **Gadgets & Rule-Breakers Actually Trigger:** Replace placeholder rule flags with real scenes/abilities/modifiers (e.g., Mini ECM/disruption pulse, Concussion Charge, objective zone field, dive/slide state hooks).
2. **Stumble, Fall & Ragdoll Loop:** Confirm damage thresholds (`<35`, `35–80`, `>=80`), headshot (`>=45%`) and leg (`+35%`) bonuses, `65%` fall / 3-stagger knockdown, `1.5s` post-recovery immunity, and `3–12 m/s` ragdoll impulse work cleanly.
3. **Enemy Morale & Squad Tokens:** Verify shock/fear shifts `Aggressive` -> `Steady` -> `Cautious` -> `Broken` and affect attack-token allocation, spread, and retreat behavior.
4. **Dodge Cap & Overflow Rule:** Verify `dodge_chance` caps at `55%` and any overflow/reload penalty behaves predictably without breaking weapon reloads.
5. **Bullet Time + Perk Coexistence:** Confirm Bullet Time (`12%` world scale, `100` Focus) runs cleanly alongside active perk rule-breakers and Focus refund/regen hooks.
6. **Build Resolver Order:** Ensure `PlayerBuildResolver` applies base stats -> Perk Slots I, II, III -> Skill Tree modifiers deterministically, and cleanly resets on build change.

---

## 3. Recommended Build Order for Coding Assistant
1. **Phase 1 — Stat & Event Bus:** Expose shared player/enemy stats and emit core combat events (`stumbled`, `fallen`, `ragdolled`, `armor_broken`, `crit`, `dive_slide`, `bullet_time`, `objective_tick`).
2. **Phase 2 — Core Gadget & Rule-Breaker Hooks:** Implement the missing role tools/zone/dive/morale/armor hooks in the controller, weapons, and enemy components.
3. **Phase 3 — 3-Slot Deck Resolver & 6–8 Test Decks:** Wire Slot I/II/III stacking + cross-deck combos and test full-commitment, weakness-patch, and combo builds in combat.
4. **Phase 4 — 4-Tier Ace-to-Skip Tree:** Implement Basic/Ace point costs, tier-unlock + tier-skip checks, and reset logic.
5. **Phase 5 — Tarot Theming Pass:** Map `00`–`13` to Tarot names (`0 The Fool` through `13 Death`), visuals, and flavor text once all mechanics are proven fun.