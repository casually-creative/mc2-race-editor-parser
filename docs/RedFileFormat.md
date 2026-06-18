# Midnight Club 2 — Race Editor File Format (`.red`)

## Overview

`.red` (Race EDitor) files are saved by Midnight Club 2 when a player creates a custom race in the in-game Race Editor. Each file describes exactly one race. Files are **fixed-size: 222 bytes**. All multi-byte integers are **little-endian**.

---

## Full Byte Map

| Offset | Size | Type | Field | Notes |
|--------|------|------|-------|-------|
| `0x00` | 13 | ASCII | Race name | Null-padded; valid chars end at first `0x00` byte |
| `0x0D` | 1 | uint8 | City | See [City](#city) |
| `0x0E` | 1 | uint8 | Time of day | See [Time of Day](#time-of-day) |
| `0x0F` | 1 | uint8 | Weather | See [Weather](#weather) |
| `0x10` | 1 | uint8 | Race mode | See [Race Mode](#race-mode) |
| `0x11` | 1 | uint8 | CPU player count | `0` = none, `1`–`6` = number of opponents. The in-game Race Editor UI caps input at `4`, but the engine supports up to `6`. |
| `0x12` | 1 | uint8 | CPU player 1 vehicle | `0xFF` = no vehicle assigned - Group A in the Race Editor UI |
| `0x13` | 1 | uint8 | CPU player 2 vehicle | `0xFF` = no vehicle assigned - Group B in the Race Editor UI |
| `0x14` | 1 | uint8 | CPU player 3 vehicle | `0xFF` = no vehicle assigned - Group A in the Race Editor UI |
| `0x15` | 1 | uint8 | CPU player 4 vehicle | `0xFF` = no vehicle assigned - Group B in the Race Editor UI |
| `0x16` | 1 | uint8 | CPU player 5 vehicle | `0xFF` = no vehicle assigned - Unreachable via the Race Editor UI - always `0xFF` in normally-saved files. |
| `0x17` | 1 | uint8 | CPU player 6 vehicle | `0xFF` = no vehicle assigned - Unreachable via the Race Editor UI - always `0xFF` in normally-saved files. |
| `0x18` | 1 | uint8 | Traffic density | See [Traffic](#traffic) |
| `0x19` | 1 | uint8 | Pedestrians | `0x00` = Off, any other value = On |
| `0x1A` | 2 | uint16 LE | Checkpoint count | Maximum valid value is `64` |
| `0x1C` | 100 | uint16 LE × 50 | Checkpoint node IDs, slots 1–50 | `0x0000` fills unused slots |
| `0x80` | 28 | uint16 LE × 14 | Checkpoint node IDs, slots 51–64 | `0x0000` fills unused slots; zero for races with ≤50 checkpoints |
| `0x9C` | 48 | uint8 × 48 | Time bonuses, slots 1–48 | Seconds (0–60); `0xFF` fills unused slots |
| `0xCC` | 16 | uint8 × 16 | Time bonuses, slots 49–64 | Seconds (0–60); `0xFF` fills unused slots; `0xFF` for races with ≤48 checkpoints |
| `0xDC` | 2 | uint16 LE | Lap count | Valid range `1`–`4`; high byte (`0xDD`) is always `0x00`; value is stored but **ignored by the game** for Unordered races |

---

## Enumerations

### City
| Value | Name |
|-------|------|
| `0` | Los Angeles |
| `1` | Paris |
| `2` | Tokyo |

### Time of Day
| Value | Name |
|-------|------|
| `0` | Dawn |
| `1` | Midnight |
| `2` | Dusk |

### Weather
| Value | Name |
|-------|------|
| `0` | Clear |
| `1` | Foggy |
| `2` | Rainy |

### Traffic
| Value | Name |
|-------|------|
| `0` | None |
| `1` | Low |
| `2` | Medium |
| `3` | High |

### Race Mode

A single byte encodes both the checkpoint ordering rule and the time-bonus accumulation mode.

| Value | Race type | Time mode |
|-------|-----------|-----------|
| `4` | Unordered | None |
| `5` | Unordered | Reset each checkpoint |
| `6` | Unordered | Added each checkpoint |
| `7` | Ordered | None |
| `8` | Ordered | Reset each checkpoint |
| `9` | Ordered | Added each checkpoint |

**Unordered** — checkpoints can be hit in any order.  
**Ordered** — checkpoints must be hit in sequence.

### Vehicle Index

Odd-numbered CPU players (1, 3) are assigned **Vehicle Type A**; even-numbered players (2, 4) are assigned **Vehicle Type B**. The vehicle index in each slot selects the actual model.

Each slot is a full `uint8`, so the field can in principle address **255 distinct vehicles** (indices `0`–`254`). Index `255` (`0xFF`) is presumed to be the de-facto "no vehicle" value because the game never assigns a real vehicle there. The vanilla roster uses only indices `0`–`31`; indices `32`–`254` may be usable by vehicle addition mods — **untested**.

| Index | Vehicle |
|-------|---------|
| 0 | Cocotte |
| 1 | City |
| 2 | Emu |
| 3 | Torrida |
| 4 | 1971 Bestia |
| 5 | Interna |
| 6 | Cohete |
| 7 | Citi Turbo |
| 8 | Monstruo |
| 9 | Jersey XS |
| 10 | Boost |
| 11 | Bryanston V |
| 12 | Schneller V8 |
| 13 | Alarde |
| 14 | Fripon X |
| 15 | Monsoni |
| 16 | Stadt |
| 17 | Victory |
| 18 | Modo Prego |
| 19 | Lusso XT |
| 20 | RSMC 15 |
| 21 | Vortex 5 |
| 22 | Saikou |
| 23 | Knight |
| 24 | Nousagi |
| 25 | Saikou XS |
| 26 | Torque JX |
| 27 | Veloci |
| 28 | SLF450x |
| 29 | LA Cop |
| 30 | Paris Cop |
| 31 | Tokyo Cop |
| 32-254 | Potential vehicle addition mods |
| 255 | No vehicle selected |

---

## Checkpoint Layout — Important Detail

The checkpoint data is stored in **two physically separate blocks** for node IDs and two for time bonuses. The checkpoint count at `0x1A` is the authoritative length for both arrays.

```
Node ID array:   [0x1C .. 0x7F]  slots  1–50  (100 bytes)
                 [0x80 .. 0x9B]  slots 51–64  ( 28 bytes)

Time bonus array:[0x9C .. 0xCB]  slots  1–48  ( 48 bytes)
                 [0xCC .. 0xDB]  slots 49–64  ( 16 bytes)
```

Despite the physical gap between the two halves of each array, both arrays are **logically contiguous**: iterating from index `0` to `count - 1` using a base offset and a stride reads the correct data straight through.

```
node_id[i]    = uint16_LE at offset  0x1C + i * 2    (valid for i = 0 .. 63)
time_bonus[i] = uint8     at offset  0x9C + i         (valid for i = 0 .. 63)
```

The interleaving arises because `0x80–0x9B` (28 bytes) sits between the two halves of the node ID block and the first half of the time bonus block. Any parser that reads both arrays linearly by offset — without clamping to `0x7F` or `0xCB` — will handle all checkpoint counts from 1 to 64 correctly without special-casing.

Unused slots at the end of each array are filled with:
- `0x0000` — unused node ID slot
- `0xFF` — unused time bonus slot

A time bonus of `0x00` is valid and means **0 seconds** added at that checkpoint.

---

## Parsing Checklist

1. Assert file size == **222 bytes** before parsing.
2. Read race name as ASCII, stop at the first `0x00` byte (max 12 printable characters; the byte at `0x0C` may itself be a null terminator or the 13th character).
3. Read checkpoint count as `uint16 LE` at `0x1A`. Validate `0 ≤ count ≤ 64`.
4. Read `count` node IDs using `uint16_LE(0x1C + i * 2)` — do **not** clamp to `0x7F`.
5. Read `count` time bonuses using `byte(0x9C + i)` — do **not** clamp to `0xCB`.
6. Lap count is a `uint16 LE` at `0xDC` (high byte always `0x00`; reading as `uint8` is safe but less precise).
7. For Unordered races, the lap count field is written by the editor but has no effect in-game.
8. CPU vehicle slots at `0x12–0x17` are `0xFF` for all unused slots. Read only the first `cpu_count` slots (up to 6).

---

## Serialization (JSON → `.red`)

When writing a `.red` file from structured data, the output **must be exactly 222 bytes**. Start with a zeroed 222-byte buffer, then fill each field. Fields not listed below must be set to their padding sentinel.

### Writing rules per field

| Field | Rule |
|-------|------|
| Race name (`0x00–0x0C`) | Write ASCII bytes, then fill remaining bytes up to and including `0x0C` with `0x00` |
| All scalar fields (`0x0D`–`0x11`, `0x18`–`0x19`) | Write the single enumeration byte directly |
| CPU vehicle slots `0x12–0x17` | Write the vehicle index for each active slot; fill unused slots (index ≥ `cpu_count`) with `0xFF` |
| Checkpoint count (`0x1A–0x1B`) | Write as `uint16 LE` |
| Checkpoint node IDs | Write each `uint16 LE` at `0x1C + i * 2`; fill unused slots (index ≥ `count`) through `0x9B` with `0x00 0x00` |
| Checkpoint time bonuses | Write each `uint8` at `0x9C + i`; fill unused slots (index ≥ `count`) through `0xDB` with `0xFF` |
| Lap count (`0xDC–0xDD`) | Write as `uint16 LE`; high byte is always `0x00` for valid values (1–4); write even for Unordered races |

### Padding sentinel summary

| Region | Unused-slot sentinel |
|--------|----------------------|
| `0x12–0x17` (CPU vehicle slots 1–6) | `0xFF` |
| `0x1C–0x9B` (node IDs, unused slots) | `0x00 0x00` |
| `0x9C–0xDB` (time bonuses, unused slots) | `0xFF` |

### Constraints to enforce before writing

- Race name must be ≤ 12 characters of printable ASCII.
- Checkpoint count must be in range `0`–`64`.
- Each time bonus must be in range `0`–`60` (seconds); `0xFF` is reserved as the unused-slot sentinel and must not be written as a real bonus value.
- Lap count must be in range `1`–`4`.
- CPU player count must be in range `0`–`6`; the in-game editor only allows `0`–`4` but the engine supports up to `6`.
- Vehicle indices for active slots must be in range `0`–`31` for the vanilla vehicle roster, or `31`-`254` for vehicle addition mods; index `255` (`0xFF`) is reserved as the "no vehicle" marker.
