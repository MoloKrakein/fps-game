# Perk Deck System Specification (Mechanics-First)

## 1. Design Priority: Mechanics Before Theming
- Build and verify all **gameplay mechanics, stat modifiers, state triggers, and rule-breaking abilities** first using neutral/functional archetype IDs (`DECK_00` through `DECK_13`).
- Treat **Tarot card names (`0`–`13`), artwork, and lore** as a presentation/theming pass layered *after* core combat interactions work reliably in-game.

---

## 2. Three-Slot Escalation Architecture
Every equipped build uses **3 Perk Slots** that resolve in order (`Slot I` -> `Slot II` -> `Slot III`):

- **Slot I — Identity & Signature Rule-Breaker:**
  - Establishes the core combat role, active tool/stance/stat conversion, and **one rule-breaking signature ability** distinct from universal **Bullet Time** (`12%` world scale, `100` Focus).
- **Slot II — Support / Enabler:**
  - Either **reinforces Slot I** (extra charge/duration, faster cooldown/focus regen, wider/stronger effect) **or** **cross-picks another deck** to patch a weakness (e.g., armor regen delay, stagger poise, dodge/crit scaling, objective speed).
- **Slot III — Payoff / Escalation:**
  - Either **raises the ceiling of the committed build** **or** **completes a cross-deck combo** (e.g., forcing stumbles/falls/ragdolls and capitalizing with crits, armor shred, morale drops, or resource refunds).

---

## 3. Shared Combat Parameters & Event Hooks (Build Glue)
All 14 perk sets read/write shared player, enemy, and combat hooks so any 3-card combination works without custom per-pair code:

### Player Parameters
- `health` (base `100`), `max_armor` (base `50` without rig), `armor_regen_rate` (base `5/s`), `armor_regen_delay` (base `3.0s`), `damage_mitigation`
- `swiftness` (derived from `100`-point loadout budget & armor/weapon weight), `move_speed`, `stamina` / `tiredness`, `fall_damage_scale`
- `dodge_chance` (base `0`, moving `+~15%` over idle, post-slide/vault `+10%` for `1.5s`, **hard cap `55%`**; overflow can penalize `reload_speed`)
- `crit_chance` (base `5%`), `crit_multiplier` (base `2.0x`), weapon handling / spread / recoil / reload modifiers
- `bullet_time_focus` (base `100`, drain `20/s`, regen `12/s`, min activation `15`), dive/slide/vault parameters, prop grab/throw (`E` / `Q`)

### Enemy & Encounter Parameters
- `stumble_intensity` (light `<35` dmg flinch, `35–80` progressive stumble, `>=80` max stumble; headshot `>=45%`, leg hit `+35%`, **fall at `>=65%` or 3 staggers**, **post-recovery immunity `1.5s`**)
- `ragdoll_impulse` (`3–12 m/s` on kill/knockdown; physics ragdoll / fall `0.7–4.0s`)
- `armor` / armor mitigation / penetration
- `morale` stances (`Aggressive >=70%`, `Steady 45–69%`, `Cautious 25–44%`, `Broken <25%`), shock/fear decay, and **squad attack tokens** / flanking

### Shared Combat Events (Signals / Hooks)
- `on_gadget_activated`, `on_bullet_time_toggled`, `on_dive_or_slide`, `on_vault`, `on_prop_thrown`
- `on_hit_dealt`, `on_crit_hit`, `on_armor_broken`, `on_enemy_stumbled`, `on_enemy_fallen`, `on_enemy_ragdolled`, `on_enemy_killed`
- `on_damage_taken`, `on_armor_depleted`, `on_armor_regen_started`, `on_objective_tick`

---

## 4. Functional Archetype Roster (`00`–`13`, Pre-Theming)

> Note: Numbers `00`–`13` align 1:1 with the planned Tarot set (`0` The Fool through `13` Death) once theming is applied.

### Objective & Mobility
1. **`00` — Momentum Runner (`0` / The Fool)**
   - *Slot I:* Boosts `swiftness` & sprint/dive stamina efficiency, reduces dive cooldown (`0.8s`), speeds objective progress while moving/carrying props; **Rule-Breaker:** *Zero-Cooldown Dive Phase* (temporarily removes dive cooldown & dive tiredness cost, turning dives/slides into evasive dashes that boost objective progress on arrival).
   - *Slot II:* Extends post-slide/vault dodge & dive momentum, lowers dive/sprint tiredness gain, preserves agility with heavy props.
   - *Slot III:* Objective progress, dives/slides, or movement chains grant a `swiftness`/crit burst and shave gadget or Bullet Time cooldowns.

2. **`05` — Objective Bastion (`V` / The Hierophant)**
   - *Slot I:* Projects an objective zone pulse that speeds task progress and staggers/slows nearby enemies (`<6m`); **Rule-Breaker:** *Objective Lock Field* (zone suppresses enemy pushes and applies stumble/slow to intruders).
   - *Slot II:* Expands zone radius, adds armor mitigation while interacting (`E`) or inside zone, increases morale shock on task interrupters.
   - *Slot III:* Enemies staggered/slowed/broken in zone take extra damage and refund armor or Bullet Time Focus on takedown.

### Crowd Control & AI/Physics Disruption
3. **`01` — Disruption Emitter (`I` / The Magician)**
   - *Slot I:* Deploys a short-range disruption pulse causing flinch/stumble, higher enemy aim spread, and morale shock; **Rule-Breaker:** *Aim & Morale Scramble* (forces a wide flinch/stumble and pushes targets toward *Cautious*/*Broken*).
   - *Slot II:* Adds extra charge or faster recharge on stagger/headshot, worsens enemy spread, extends disruption duration.
   - *Slot III:* Disrupted or *Cautious*/*Broken* enemies take bonus damage and lose squad attack-token priority.

4. **`10` — Ragdoll / Stumble Driver (`X` / Wheel of Fortune)**
   - *Slot I:* Increases `stumble_intensity` gain and ragdoll impulse (`3–12 m/s`); **Rule-Breaker:** *Physics Stumble Inversion* (forces stumbling/nearby targets into live stumbles/falls/ragdolls and boosts knockback).
   - *Slot II:* Lowers hits/intensity needed to cross the `65%` fall / 3-stagger threshold, shortens `1.5s` post-stumble immunity, increases ragdoll launch speed.
   - *Slot III:* Stumbles/ragdolls trigger squad morale fear and deal extra collision/impact damage when targets slam into surfaces or foes.

5. **`12` — Tempo & Token Suppressor (`XII` / The Hanged Man)**
   - *Slot I:* Enhances Bullet Time or applies slow/suppression to lower squad tempo; **Rule-Breaker:** *Token & Tempo Pin* (reduces enemy attack-token priority and slows movement/fire rhythm).
   - *Slot II:* Improves Bullet Time focus efficiency/regen on staggers/kills and boosts suppression/slow potency.
   - *Slot III:* Exiting Bullet Time or suppressing squads leaves enemies slowed and *Broken* with heavy spread.

### Damage Dealer
6. **`06` — Link & Follow-Up (`VI` / The Lovers)**
   - *Slot I:* Marks/links targets hit by stumbles, armor cracks, or gadgets for follow-up damage; **Rule-Breaker:** *Sympathetic Link* (linked targets share a portion of stagger/armor damage and spread fear on death).
   - *Slot II:* Extends link duration, spreads part of stumble/armor-break shock to nearby/linked targets, speeds weapon swap/chambering.
   - *Slot III:* Eliminating linked targets triggers a chain shock/fear pulse and refunds Bullet Time Focus or armor.

7. **`07` — Kinetic Breacher (`VII` / The Chariot)**
   - *Slot I:* Enables Concussion Charge/Breach and boosts impact/stumble during or after dive/slide/vault; **Rule-Breaker:** *Breach Ram* (dives/slides/charges slam enemies with heavy stumble/ragdoll and chip armor while keeping post-slide/vault dodge).
   - *Slot II:* Increases dive/slide carry & landing slide, grants stagger/flinch protection during dive/slide, shaves charge cooldown on stumbles.
   - *Slot III:* Dive/slide breaches or concussion hits on stumbling/fallen enemies deal burst damage and leave nearby targets stumbled/ragdolled.

8. **`11` — Armor Breaker (`XI` / Justice)**
   - *Slot I:* Grants armor penetration and bonus damage vs. armored targets; **Rule-Breaker:** *Armor Sunder* (armor breaks trigger a heavy stagger shock).
   - *Slot II:* Boosts armor shred/penetration on bursts, headshots, and mounted/heavy shots; reduces target armor mitigation on hit.
   - *Slot III:* Breaking enemy armor triggers a knockdown/stagger pulse and grants temporary armor or bonus damage vs. exposed foes.

9. **`13` — Execution Reaver (`XIII` / Death)**
   - *Slot I:* Boosts damage vs. stumbling, fallen, or *Broken* enemies and refunds resources on kills; **Rule-Breaker:** *Execution Reap* (takedowns on impaired/*Broken* targets refund Focus, armor, or cooldown/reload momentum).
   - *Slot II:* Increases Focus/armor/cooldown refunds on takedowns and adds extra morale fear when finishing stumbled/*Broken* foes.
   - *Slot III:* Chained takedowns on staggered, ragdolled, or *Broken* targets amplify follow-up damage and sustain refunds.

### Survival
10. **`03` — Regen Accelerator (`III` / The Empress)**
    - *Slot I:* Lowers `armor_regen_delay` (`3.0s`) and boosts armor recovery on crits, staggers, or takedowns; **Rule-Breaker:** *Rapid Regen Cycle* (accelerates regen recovery and converts staggers/crits into immediate armor ticks).
    - *Slot II:* Boosts `armor_regen_rate` (`5/s` base) and triggers mini armor pulses on stumbles or consecutive crits/headshots.
    - *Slot III:* Armor recovery/cycling grants a brief damage/crit or stagger-resistance buff.

11. **`04` — Mount & Hold Bastion (`IV` / The Emperor)**
    - *Slot I:* Adds `max_armor` and `damage_mitigation`, plus stagger poise and recoil/spread control while mounted (`X`), crouched, or holding ground; **Rule-Breaker:** *Aegis Bastion* (fortified stance/field while mounted or holding ground that resists stumbles and shields nearby allies/objectives).
    - *Slot II:* Further improves mounted/crouched handling & recoil, boosts stagger resistance while anchored, shaves regen delay when holding position.
    - *Slot III:* Holding ground or mounting converts incoming pressure into counter-stagger and boosts objective/ally protection.

12. **`08` — Grit & Poise (`VIII` / Strength)**
    - *Slot I:* Grants stagger/flinch poise, lowers `fall_damage_scale` and `tiredness` gain, and adds armor buffer under heavy loads; **Rule-Breaker:** *Damage / Resource Inversion* (converts heavy hits or stumble strain into poise, lower tiredness, or counter-stagger).
    - *Slot II:* Converts heavy hits/stumbles into poise and tiredness recovery, keeping mobility intact under pressure.
    - *Slot III:* Absorbing heavy hits or surviving high-stumble exchanges emits a stagger pulse and boosts next burst/crit.

### Crit Focus
13. **`02` — Precision & Bullet Time (`II` / The High Priestess)**
    - *Slot I:* Boosts `crit_chance` while aiming/mounted or in Bullet Time, and increases crit damage on staggered/fallen targets or headshots; **Rule-Breaker:** *Opening Sight* (amplifies crits against staggered, off-balance, or Bullet-Time targets).
    - *Slot II:* Boosts `crit_multiplier` (`2.0x` base) on headshots and off-balance foes; improves ADS/canted/Bullet Time aim steadiness.
    - *Slot III:* Crits on staggered, *Broken*, or Bullet Time targets extend stagger/disruption or refund Bullet Time Focus.

14. **`09` — Flank & Swiftness Crit (`IX` / The Hermit)**
    - *Slot I:* Converts `swiftness` into `crit_chance` and `dodge_chance` (respecting `55%` cap), eases movement spread, aids flanking; **Rule-Breaker:** *Phantom Slip* (breaks target lock/awareness checks during movement/flanks and spikes crit + dodge).
    - *Slot II:* Improves `swiftness`-to-crit/dodge conversion, reduces moving spread penalty, aids breaking awareness (`6m`) / vision (`110°`) on flanks/dives.
    - *Slot III:* Flanking shots, moving crits, or post-dive/slide strikes deal bonus damage and shave cooldowns or Bullet Time Focus cost.

---

## 5. Mix-and-Match Rules
- **Full Commitment (`3` cards from same set):** Maximizes one archetype's signature loop from Slot I to Slot III; accept its blind spots.
- **Weakness Patching (`Slot I` + off-set `Slot II`/`III`):** Pair a high-risk/high-reward identity (e.g., high-dodge/crit flanker) with sustain (`03`, `04`, `08`) or objective (`00`, `05`) cards.
- **Combo Engine (Enabler + Payoff across sets):** Combine a stumble/ragdoll/armor-break enabler (`10`, `07`, `11`, `01`) with a crit/execution/morale payoff (`02`, `13`, `06`).