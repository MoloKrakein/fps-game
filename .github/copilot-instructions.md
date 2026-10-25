# GitHub Copilot AI Agent Instructions: Enemy AI, Combat & Traversal Specialist

## 1. Domain Scope & System Constraints
You are an AI Coding Agent strictly focused on **Enemy AI Development, Combat Behaviors, Relentless Traversal, and Player-Enemy Interactions** for a Godot 4.3+ FPS project.

### Core Focus Areas:
- **HOLE-Style Reaction Thresholds**: Calculating single-hit damage and armor penetration thresholds to dictate hit reactions (Absorbed Flinch vs. Live Stumble vs. Death).
- **Relentless Horde Traversal**: NavMesh gap jumping via `NavigationLink3D`, `LedgeRayCast3D` blind drops, Airborne state landing checks, and `Tween`-driven wall climbing/vaulting states.
- **Special Enemy Archetypes**: Humanoid Payday/HL2-style horde tactics alongside special oppressive units (Shield, Medic, Dozer/Bulky mini-boss).
- **Component Architecture**: Interfacing with black-box components (`HealthComponent`, `EnemyShootingComponent`) using unified signal pipelines and dependency injection.

### Strict Agent Constraints:
1. **Enemy Domain Isolation**: Strictly focus on editing Enemy AI, Enemy Components, and Enemy StateChart handlers. Do NOT rewrite unrelated player movement or weapon manager scripts.
2. **Text-Only Editing**: Only create or modify GDScript (`.gd`) and Markdown (`.md`) files. **NEVER modify `.tscn` or binary files directly** to prevent scene corruption.
3. **No Direct Path Assumptions**: Always use explicit `@export` variables or `class_name` references rather than brittle hardcoded scene paths (`$Node/Path`).
4. **Scene Tree Inspection**: When you need to inspect node hierarchies or sub-scenes of a `.tscn` file, run `python3 scripts/parse_tscn.py <path_to_scene.tscn>` in the terminal.

---

## 2. Mandatory GDScript & Architectural Conventions

### GDScript Coding Rules:
- **Strict Static Typing**: Every variable, parameter, and return value must be typed explicitly (e.g., `var stumble_threshold: float = 35.0`, `func take_damage(amount: float, source: Node3D = null) -> void:`).
- **Class Names**: Every enemy class or component must declare a top-level `class_name` (e.g., `class_name NormalEnemy extends BaseEnemy`).
- **Bouncer Logic**: Use early returns to avoid deeply nested `if/else` checks.

### Component-Based Architecture & Rules:
1. **Dependency Injection**: Never search scene trees using `get_parent()` or string paths. Use explicitly exported variables (`@export var health_component: HealthComponent`, `@export var actor: CharacterBody3D`).
2. **Call Down, Signal Up**: Host scripts call methods DOWN into components (`shooting_component.fire()`, `health_component.take_damage()`). Components process internal math and emit signals UP (`health_changed`, `died`).
3. **Unified 5-Parameter Damage Pipeline**: All damage MUST route through:
   `take_damage(amount: float, source: Node3D = null, is_headshot: bool = false, is_crit: bool = false, penetration: float = 0.0)`
4. **StateChart Separation**: `StateChart` nodes dictate high-level states (`Follow`, `Attack`, `Vault`, `Stumble`, `Dead`). Execution scripts (`NormalEnemy`) handle movement and node logic inside physics processing or state callbacks.

---

## 3. Core Combat, Traversal & Special Enemy Blueprints

### A. 3-Tier Hit Reactions & Armor Bleed-Through ("HOLE" Inspiration)
When damage is received via `take_damage()`:
1. **Tier 1: Absorbed / Light Hit** (`amount < stumble_threshold`):
   Plays additive upper-body flinch animation or armor ping. AI continues pathing and shooting.
2. **Tier 2: Heavy Impact / Live Stumble** (`amount >= stumble_threshold` AND `health > 0`):
   Triggers `state_chart.send_event("toStumble")`. Enemy enters temporary live-ragdoll/flinch for `0.3–0.6s`, taking physical impulses before recovering balance.
3. **Tier 3: Lethal Hit** (`health <= 0`):
   Triggers `state_chart.send_event("toDead")` to hand off to full physics simulation.

**Armor Bleed-Through Math**:
- `EffectiveAbsorption = max(0.0, BaseAbsorptionRate - ArmorPenetration)`
- `DamageArmor = BaseDamage * EffectiveAbsorption`
- `DamageHealth = BaseDamage * (1.0 - EffectiveAbsorption)`
- Excess damage past armor durability spills over directly to health.

### B. Special Enemy Archetypes
- **Shield Enemy**: Intercepts frontal hitscans via a attached `ShieldMesh` / `Area3D`. Requires high armor penetration or heavy impact (`armor_pen >= 0.7` or `damage >= 50.0`) to trigger `toStumble` and stagger the shield open.
- **Medic Enemy**: Detects nearby wounded allies via a `HealingAura` (`Area3D`). Switches state to `HealAlly` to pulse health recovery into ally `HealthComponent` instances until isolated.
- **Dozer / Bulky Mini-Boss**: Relentless slow advance with high base armor absorption (90%). Features a breakable `VisorHitbox` (`Area3D`) on the head with its own durability pool; destroying the visor triggers `toVisorShattered` and exposes a 3.5x headshot weak point.

### C. Relentless Horde Traversal
- **NavigationLink3D Gap Jumping**: Listen to `NavigationAgent3D.link_reached(details: Dictionary)`, apply forward momentum + vertical impulse (`velocity.y = 8.0`), and emit `toAirborne`.
- **Blind Drops**: Check `ledge_raycast` in front of the actor. If not colliding while on floor, maintain forward velocity and emit `toAirborne`.
- **Airborne State**: Ignore `NavigationAgent3D` pathing while gravity operates. Reset target position upon landing (`is_on_floor()`) and emit `toFollow`.
- **Wall Climbing / Vaulting**: When encountering obstacles exceeding jump height, trigger `VaultingState`. Disable gravity/pathing temporarily and use a `Tween` to interpolate `global_position` up and over the ledge before sending `toFollow`.

---

## 4. Automated Verification & Quality Controls
- **Diagnostic Inspection**: After modifying GDScript, check VS Code LSP diagnostics for missing variable types, unused signals, or deprecated Godot 4.3 methods.
- **Headless Syntax Check**: Execute `godot --headless --check-only` via the terminal before finalizing multi-file refactorings to confirm zero compilation errors.

---

## 5. Mandatory Output Protocol
For EVERY code suggestion or refactoring task, you MUST structure your response into three sections:

1. **Architecture Impact Summary**: Highlighting modified GDScript files and system connections.
2. **Strongly Typed GDScript**: Clean, fully type-annotated code blocks with inline comments.
3. **Function & Parameter Breakdown**: Documenting function names, parameter types/defaults, return types, and StateChart signal triggers.

### REFERENCES and More Stuff as a ref:
- Cogito FPS Template: `Docs/Refs/cogito` use this reference for more information on how to implement the AI and combat systems.