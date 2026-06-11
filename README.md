# Maze Game

A top-down maze exploration game for the **ZX Spectrum Next**, written in Z80N assembly.

## Description

Explore a vast 256×192 tile maze populated with 20 intelligent enemies ("baddies"). Use smooth pixel-precise movement, avoid or confront the enemies, toggle a radar view that visualizes the enemy pathfinding data, and survive as long as your health allows.

The game showcases advanced ZX Spectrum Next techniques:
- Hardware tilemap scrolling with fine pixel offset
- Layer 2 graphics for radar/minimap mode
- Sprite handling with animation
- Memory paging for large worlds
- IM2 interrupts for timing and sound
- Flood-fill distance field powering both AI and visualization

## Features

- Large pre-generated maze (256×192 tiles)
- Smooth pixel scrolling and camera following
- Animated 4-direction player sprite
- 20 AI enemies with hunt/wander behavior using distance field "scent"
- Tile-based wall collision + pixel overlap enemy collision
- Toggleable radar view (Y key) showing walls/paths/flood distances on Layer 2
- Sound effects via AY chip + included melody data
- Health bar in HUD (top of screen)
- Active development with frequent improvements

## Controls (Keyboard)

| Key | Action          |
|-----|-----------------|
| Q   | Move up         |
| A   | Move down       |
| O   | Move left       |
| P   | Move right      |
| Y   | Toggle radar view (Layer 2 flood map) |

Movement is pixel-smooth (delta = 2 pixels). Collision is checked when aligned to tile boundaries.

## Requirements

- **ZX Spectrum Next** hardware **or** emulator:
  - [CSpect](https://cspect.org/) (recommended for development)
  - ZesarUX
  - Real ZX Spectrum Next
- Assembler with Z80N / Spectrum Next extended instruction support (e.g. sjasmplus, Z88DK)

## Building & Running

1. Assemble `maze.asm` (the current main source file).
2. The build process (using `SAVENEX` directives) automatically produces `maze.nex` including all embedded data.
3. Load the resulting `.nex` file in your emulator or copy to real hardware.

The maze tile data (`testmaze.map`) is embedded directly into the NEX file across memory pages 40–45.

## Maze Generation

The maze was created using the included `MAZE1.bas` (QB64PE / QuickBASIC 64 PE):

- Recursive backtracker algorithm (perfect maze, no loops)
- 256 × 192 byte array (`1` = wall, `0` = path)
- Top 8 rows completely open (no walls)
- Paths are exactly 2 tiles wide; walls are 1 tile thick
- Safe perimeter walls on left, right, and bottom

You can modify parameters in `MAZE1.bas` (e.g. `topOpenRows`) and re-run it to generate new `testmaze.map` files. Update the `INCBIN` statements in the assembly source if you want to use a different map.

## Project Structure

```
MAZE1.bas              # QB64PE maze generator (creates testmaze.map)
maze.asm               # Main game source
*.inc                  # Modular include files (see list below)
testmaze.map           # Binary maze data (48 KB, embedded in NEX)
mansprite.zip          # Original sprite graphics source
im2Routine.inc         # IM2 interrupt handler (included from maze.asm)
```

### Files Included by `maze.asm`

`maze.asm` uses the following `INCLUDE` directives:

| File                    | Purpose                                      |
|-------------------------|----------------------------------------------|
| `macros.inc`            | Useful macros (`DIV_HL_8`, `GET_WORLD_TILE`, etc.) |
| `maze2.inc`             | Core maze logic, flood-fill, distance field, baddie AI |
| `initialisation.inc`    | Sprite setup, palettes, clipping windows, HUD initialization |
| `text.inc`              | Text rendering routines                      |
| `inspectorclouseau.inc` | Music / melody data (Inspector Clouseau theme) |
| `soundEffects.inc`      | Sound effect definitions + `playsound` routine |

> **Note:** `im2Routine.inc` is included inside the interrupt setup section of `maze.asm`.

## Development Status

**Actively developed** (as of June 2026).

Recent commits include:
- XY pixel collision detection between player and enemies
- Sound effects on enemy collision
- Health bar added to HUD
- Code modularisation into functional `.inc` files
- Radar mode refinements and Layer 2 integration
- UDG / text display improvements

This is a personal project exploring the capabilities of the ZX Spectrum Next.

## Author

**John Greening**  
GitHub: https://github.com/JohnGreening  
Interests: ZX Spectrum, ZX Spectrum Next, Z80 development

---

*Built with enthusiasm for the ZX Spectrum Next community.*

If you have feedback, suggestions, or want to collaborate, feel free to open an issue or pull request!