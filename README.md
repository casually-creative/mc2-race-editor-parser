# Midnight Club 2 Race Editor Parser

A PowerShell parser and technical documentation for the `.red` file format used by Midnight Club 2's in-game Race Editor. Each `.red` file is a fixed-size 222-byte binary file describing one custom race - including city, time of day, weather, race mode, CPU opponents, checkpoints, time bonuses, and lap count.

## Contents

- **[`src/ParseRedToJson.ps1`](src/ParseRedToJson.ps1)** — Reads all `.red` files from `src/userdata/` and writes one `.json` per file to `src/output/`.
- **[`docs/RedFileFormat.md`](docs/RedFileFormat.md)** — Full technical documentation of the `.red` binary format: byte map, enumerations, checkpoint layout, parsing rules, serialization rules, and padding sentinels.

## Usage

1. Make a backup of your `/userdata` folder, just in case.
2. Place the parser scripts in the root of your Midnight Club 2 directory.
3. Execute ParseRedToJson.ps1 to parse your `/userdata/*.red` files to `/userjson/*.json` files.
4. Inspect the `.json` files and make edits if appropriate.
5. Execute ParseJsonToRed.ps1 to parse the `/userjson/*.json`files back to `/userdata/*.red` files.
