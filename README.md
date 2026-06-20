# Midnight Club 2 Race Editor Parser

A PowerShell parser and technical documentation for the `.red` file format used by Midnight Club 2's in-game Race Editor. Each `.red` file is a fixed-size 222-byte binary file describing one custom race - including city, time of day, weather, race mode, CPU opponents, checkpoints, time bonuses, and lap count.

## Contents

- **[`src/ParseRedToJson.ps1`](src/ParseRedToJson.ps1)** — Reads all `.red` files from `src/userdata/` and writes one `.json` per file to `src/output/`.
- **[`docs/RedFileFormat.md`](docs/RedFileFormat.md)** — Full technical documentation of the `.red` binary format: byte map, enumerations, checkpoint layout, parsing rules, serialization rules, and padding sentinels.

## Usage

Place `.red` files in `src/userdata/`, then run the parser from the `src/` directory:

```powershell
cd src
.\ParseRedToJson.ps1
```

Parsed `.json` files are written to `src/output/`.

## Notes

- `.red` files are saved by the game at `%USERPROFILE%\My Documents\Midnight Club 2\savegame\<profile>\` alongside the `.sav` profile file.
- File names follow the pattern `<profile><city><index>.red` (e.g. `CCR 01LA3.red`).
- The in-game Race Editor UI supports up to 4 CPU opponents; the engine supports up to 6.
