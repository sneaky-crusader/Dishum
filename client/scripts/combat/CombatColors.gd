extends RefCounted
class_name CombatColors
## Shared region-feedback colors — single source of truth so every fighter
## renderer (2D FighterModel, 3D Fighter3D, future ones) agrees on what
## "guarding" / "telegraph" / "hit" / "blocked" look like.

const NEUTRAL := Color(0.75, 0.72, 0.65)   # nothing happening
const GUARD := Color(0.25, 0.45, 0.9)      # this region is being guarded
const TELEGRAPH := Color(0.95, 0.85, 0.15) # an incoming punch is winding up toward this region
const HIT := Color(0.9, 0.15, 0.15)        # this region was just hit
const BLOCKED := Color(0.2, 0.8, 0.35)     # an incoming punch here was just blocked
