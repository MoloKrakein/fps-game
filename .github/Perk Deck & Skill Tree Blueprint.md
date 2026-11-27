# **Perk Deck & Skill Tree System Blueprint**

## **1\. System Architecture & Responsibilities**

This blueprint defines how the **3-Slot Perk Deck System** and the **Normal Skill Tree** work together in our objective-driven FPS without overlapping or creating build confusion.

> * **3-Slot Perk Deck System \= Playstyle Identity, Role Tool & Combat Loops**  
  * **Slot I (Role & Signature Tool):** Establishes the character's core combat role and provides a signature tactical gadget/throwable/deployable (e.g., *Mini ECM*, *Concussion Charge*, *Aegis/Stagger Beacon*, *Disrupt/Adrenaline Tool*).  
  * **Slot II (Escalation or Cross-Pollination):** Lets the player either **Double Down** on a previously chosen deck to advance its tier (T1 \-\> T2) or **Cross-Pick** another deck's T1 hook to introduce a secondary playstyle element.  
  * **Slot III (Capstone or Hybrid Synergy):** Lets the player either push a double-downed deck to T3 or lock in a third synergy piece so both pure specialists and hybrid builds feel intentional.  
> * **Normal Skill Tree \= Granular Tuning, Breakpoint Scaling & Objective Utility**  
  * Tuned via skill points across thematic branches.  
  * Handles foundational FPS feel and objective mechanics: reload speed, magazine/ammo economy, weapon handling/ADS/swap speed, **Swiftness** conversion thresholds (Dodge & Crit scaling), armor regen delay/sustain tuning, stagger/impact tuning, and objective interaction speed.

## **2\. 3-Slot Perk Deck Rules**

### **Slot Progression & Tier Resolution**

Each of the **3 Perk Deck Slots (Slot I, Slot II, Slot III)** equips one Perk Deck (T1, T2, or T3):

> 1. **Slot I (Base Foundation):** Always unlocks the chosen deck's **Tier 1 Hook** and its **Signature Role Gadget** (when that deck is the active role anchor).  
> 2. **Slot II (Pivot — Double Down vs. Cross-Pick):**  
   * **Double Down (Same Deck):** Advances that deck to **Tier 2 (Escalation)**—upgrading gadget charges/radius/cooldown refund or strengthening its signature combat trigger.  
   * **Cross-Pick (Different Deck):** Unlocks the new deck's **Tier 1 Hook** (never a higher tier on first splash), keeping cross-deck choices easy to read and preventing text overload.  
> 3. **Slot III (Payoff — Capstone vs. Hybrid Synergy):**  
   * **Double Down to Tier 3:** Advances a deck that already has T1 \+ T2 into **Tier 3 (Capstone)** for maximum specialization.  
   * **Cross-Pick / Second Tier:** Either adds another deck's T1 hook for a tri-flavor hybrid or advances a T1 cross-pick to T2.

### **Clarity & Tagging Rules**

Every Perk Deck card uses short, scannable rules and a clear behavior tag:

> * \[Gadget\] — Signature role throwable/deployable and its upgrades.  
> * \[Passive\] — Active continuously or when Swiftness/movement/stance conditions are met.  
> * \[On Trigger\] — Fires on specific combat/objective events (Dodge, Crit, Stagger/Stumble, Armor Break, Aim Disruption).  
> * \[Active / Cooldown\] — Cooldown- or charge-based effect that can interact with combat triggers.

## **3\. Core Perk Deck Archetypes (Blueprint)**

### **A. Disruptor / Hacker (Disrupt / Control)**

> * **Slot I Gadget — Mini ECM Pulse:** Quick-throws or deploys a compact pulse that staggers/flinches nearby enemies, increases enemy aim spread/accuracy penalty, and grants a small heal/armor pulse.  
> * **T1 Hook:** Mini ECM unlocks \+ enemies disrupted/staggered by your pulse suffer reduced tracking accuracy.  
> * **T2 Escalation (Double Down):** Wider pulse radius / extra charge; staggering or taking down disrupted enemies shaves cooldown off the Mini ECM.  
> * **T3 Capstone (Double Down):** Disrupted/staggered targets take bonus damage and grant a burst of armor on takedown.

### **B. Breacher / Shock (Stagger / Impact)**

> * **Slot I Gadget — Concussion Charge:** Tosses or plants a shock charge that triggers a heavy stumble or temporary non-fatal ragdoll on nearby enemies and chips armor.  
> * **T1 Hook:** Concussion Charge unlocks \+ bonus Stagger/Impact power and bonus damage against stumbling/off-balance targets.  
> * **T2 Escalation (Double Down):** Extra charge / stronger stumble impulse; staggering or breaking armor restores a portion of armor.  
> * **T3 Capstone (Double Down):** Toppling an enemy into stumble/ragdoll grants brief damage resistance and boosts crit/stagger follow-up.

### **C. Skirmisher / Phantom (Swift / Mobility)**

> * **Slot I Gadget — Sensor Disruptor / Adrenaline Burst:** Breaks enemy target lock/line-of-sight cues and grants a burst of movement speed and Swiftness momentum.  
> * **T1 Hook:** Gadget unlocks \+ unlocks Swiftness-scaled Dodge while moving and boosts sprint/slide agility.  
> * **T2 Escalation (Double Down):** Longer disruption/speed window \+ dodging or landing crits builds momentum and restores a sliver of armor (armor-gating).  
> * **T3 Capstone (Double Down):** Peak momentum unlocks overdrive dodge/crit bonuses and shaves gadget cooldown on mobile kills/crits.

### **D. Bulwark / Warden (Armor / Hold)**

> * **Slot I Gadget — Aegis / Stagger Beacon:** Deploys a short-duration ward/pulse or triggers a defensive surge that reduces incoming damage/stumble and speeds armor recovery while holding ground.  
> * **T1 Hook:** Gadget unlocks \+ grants bonus Max Armor and incoming damage mitigation.  
> * **T2 Escalation (Double Down):** Shorter Armor Regen Delay \+ staggering or breaking enemy armor triggers faster armor recovery.  
> * **T3 Capstone (Double Down):** Further Max Armor & mitigation \+ breaking armor or holding an objective zone grants extra sustain.

## **4\. Normal Skill Tree Blueprint**

The **Normal Skill Tree** lets players fine-tune stats, unlock **Swiftness** conversion thresholds, and support objective play regardless of which Perk Decks they slot.

### **Recommended Tree Branches**

> 1. **Swiftness & Agility Branch (Mobility, Dodge & Crit Scaling)**  
   * **Swiftness Crit Conversion:** Converts high **Swiftness** (above threshold) into **Crit Chance** up to the crit cap.  
   * **Kinetic Footwork:** Boosts sprint/slide speed, stamina efficiency, and active Dodge while sprinting/sliding/vaulting.  
   * **Fluid Handling:** Improves weapon swap speed, ADS speed, and reload speed for mobile playstyles.  
> 2. **Armor & Stagger Branch (Survivability, Impact & Armor Shred)**  
   * **Reinforced Plating:** Increases Max Armor, damage mitigation, or reduces Armor Regen Delay.  
   * **Concussive & Ballistic Impact:** Increases **Impact / Stagger** power to stumble enemies faster and break armor thresholds.  
   * **Heavy Weapon Discipline:** Reduces recoil climb and improves magazine/ammo sustain for heavier weapons.  
> 3. **Fieldcraft & Objective Branch (Horde Control, Utility & Objectives)**  
   * **Objective Specialist:** Speeds up hacking, drilling, carrying, or objective interactions while under fire.  
   * **Tactical Economy:** Increases ammo pickup, reserve capacity, or gadget/throwable cooldown efficiency.  
   * **Suppression & Recovery:** Enhances crowd control duration, revive/recovery speed, or sustain during high-pressure waves.

## **5\. Mitigating Design Pitfalls Between Slot I, Slots II–III & Skill Tree**

> * **Preventing Slot I from Locking Players In:** Pair Slot I's role tool with **Swiftness-friendly** or **role-agnostic** options in Slots II–III and the Normal Skill Tree so a *Hacker* or *Breacher* can still build fast dodge/crit or heavy armor/objective speed.  
> * **Preventing Slots II–III from Feeling Like Stat Filler:** Anchor Slot II–III perks around **combat state interactions** (stagger/stumble, armor break, aim disruption, dodge/crit triggers, objective phases) rather than plain percentage padding.  
> * **Preventing Overlap with the Skill Tree:** Keep pure handling/ammo/objective-speed numbers in the Normal Skill Tree; keep Perk Decks focused on **signature tools, build pivots, and combat loops**.

## **6\. Blueprint Checklist for Implementation (Godot 4\)**

> * **Data Definitions (Resource):** Define PerkDeckData (with tier\_1, tier\_2, tier\_3 entries and a role\_gadget scene/resource) and SkillNodeData (point cost, prerequisites, stat/flag modifiers).  
> * **Build Resolver:** Compute the 3 Perk Deck slots (Slot I, Slot II, Slot III) into resolved tier levels, active role gadget, and combat state hooks, then merge with Normal Skill Tree modifiers and PlayerStatsResource (Swiftness, Armor, Dodge, Crit, Impact).  
> * **Combat & AI Hooks:** Connect perk/skill triggers to your enemy combat/stumble/ragdoll/accuracy systems and objective interaction states so builds can be tested cleanly in playtest rooms.