# Midnight Club 2 - Race Editor (.red) file writer
# Reads all *.json files from ./userjson/, validates against spec/race.schema.json,
# and writes one *.red per file into ./userdata/

# Load enum data from spec/race.schema.json - single source of truth
$specDir    = Join-Path (Split-Path -Parent $PSScriptRoot) "spec"
$schemaJson = Get-Content (Join-Path $specDir "race.schema.json") -Raw
$schema     = $schemaJson | ConvertFrom-Json

$cities       = [string[]]$schema.properties.city.enum
$todNames     = [string[]]$schema.properties.timeOfDay.enum
$weatherNames = [string[]]$schema.properties.weather.enum
$traffNames   = [string[]]$schema.properties.traffic.enum
$vehicles     = [string[]]($schema.'$defs'.vehicleSlot.enum | Where-Object { $_ -ne $null })

# Build reverse raceModes lookup: "RaceType|TimeMode" -> byte value
$raceModeReverse = @{}
$byte = 4
foreach ($rt in $schema.properties.raceType.enum) {
    foreach ($tm in $schema.properties.timeMode.enum) {
        $raceModeReverse["$rt|$tm"] = $byte
        $byte++
    }
}

function ConvertTo-RedBytes([string]$jsonPath) {
    $data = (Get-Content $jsonPath -Raw) | ConvertFrom-Json
    $b    = [byte[]]::new(222)

    # Race name: bytes 0x00-0x0C, null-padded ASCII (max 13 chars)
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes([string]$data.name)
    $copyLen   = [Math]::Min($nameBytes.Length, 13)
    [Array]::Copy($nameBytes, $b, $copyLen)

    # City: byte 0x0D
    $b[0x0D] = [byte][Array]::IndexOf($cities, [string]$data.city)

    # Time of Day: byte 0x0E
    $b[0x0E] = [byte][Array]::IndexOf($todNames, [string]$data.timeOfDay)

    # Weather: byte 0x0F
    $b[0x0F] = [byte][Array]::IndexOf($weatherNames, [string]$data.weather)

    # Race mode: byte 0x10
    $b[0x10] = [byte]$raceModeReverse["$($data.raceType)|$($data.timeMode)"]

    # CPU player count: byte 0x11
    $b[0x11] = [byte]$data.cpuPlayers

    # CPU vehicles: Group A (players 1 & 3) at 0x12 and 0x14; Group B (players 2 & 4) at 0x13 and 0x15
    # 0xFF = no vehicle assigned
    $idxA = if ($null -ne $data.cpuVehicleA) { [byte][Array]::IndexOf($vehicles, [string]$data.cpuVehicleA) } else { [byte]0xFF }
    $idxB = if ($null -ne $data.cpuVehicleB) { [byte][Array]::IndexOf($vehicles, [string]$data.cpuVehicleB) } else { [byte]0xFF }
    $b[0x12] = $idxA; $b[0x14] = $idxA
    $b[0x13] = $idxB; $b[0x15] = $idxB
    $b[0x16] = 0xFF
    $b[0x17] = 0xFF

    # Traffic: byte 0x18
    $b[0x18] = [byte][Array]::IndexOf($traffNames, [string]$data.traffic)

    # Pedestrians: byte 0x19
    $b[0x19] = if ($data.pedestrians -eq "Off") { [byte]0x00 } else { [byte]0x01 }

    # Checkpoint count: uint16 LE at 0x1A-0x1B
    $count   = $data.checkpoints.Count
    $b[0x1A] = [byte]($count -band 0xFF)
    $b[0x1B] = [byte](($count -shr 8) -band 0xFF)

    # Checkpoint node IDs: slots 1-50 at 0x1C-0x7F, slots 51-64 at 0x80-0x9B; 0x0000 fills unused
    for ($i = 0; $i -lt 50; $i++) {
        $node   = if ($i -lt $count) { [int]$data.checkpoints[$i].node } else { 0 }
        $offset = 0x1C + $i * 2
        $b[$offset]     = [byte]($node -band 0xFF)
        $b[$offset + 1] = [byte](($node -shr 8) -band 0xFF)
    }
    for ($i = 50; $i -lt 64; $i++) {
        $node   = if ($i -lt $count) { [int]$data.checkpoints[$i].node } else { 0 }
        $offset = 0x80 + ($i - 50) * 2
        $b[$offset]     = [byte]($node -band 0xFF)
        $b[$offset + 1] = [byte](($node -shr 8) -band 0xFF)
    }

    # Time bonuses: slots 1-48 at 0x9C-0xCB, slots 49-64 at 0xCC-0xDB; 0xFF fills unused
    for ($i = 0; $i -lt 48; $i++) {
        $b[0x9C + $i] = if ($i -lt $count) { [byte]$data.checkpoints[$i].timeBonus } else { [byte]0xFF }
    }
    for ($i = 48; $i -lt 64; $i++) {
        $b[0xCC + ($i - 48)] = if ($i -lt $count) { [byte]$data.checkpoints[$i].timeBonus } else { [byte]0xFF }
    }

    # Laps: uint16 LE at 0xDC-0xDD; null (Unordered race) is stored as 1 (ignored by the game anyway)
    $laps    = if ($null -ne $data.laps) { [int]$data.laps } else { 1 }
    $b[0xDC] = [byte]($laps -band 0xFF)
    $b[0xDD] = [byte](($laps -shr 8) -band 0xFF)

    return ,$b
}

$userdataDir = Join-Path $PSScriptRoot "userdata"
$userjsonDir = Join-Path $PSScriptRoot "userjson"

$canValidate = $PSVersionTable.PSVersion -ge [version]"6.1"
if (-not $canValidate) {
    Write-Warning "Schema validation requires PowerShell 6.1 or later - skipping."
}

$jsonFiles = Get-ChildItem (Join-Path $userjsonDir "*.json") | Sort-Object { [regex]::Replace($_.BaseName, '\d+', { $args[0].Value.PadLeft(10, '0') }) }
$fileCount = 0

foreach ($file in $jsonFiles) {
    if ($canValidate) {
        $raw     = Get-Content $file.FullName -Raw
        $isValid = Test-Json -Json $raw -Schema $schemaJson -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
        if (-not $isValid) {
            Write-Warning "$($file.Name): schema validation failed:"
            foreach ($e in $schemaErrors) { Write-Warning "  $($e.Exception.Message)" }
            Write-Warning "$($file.Name): skipping."
            continue
        }
    }

    $bytes   = ConvertTo-RedBytes $file.FullName
    $redName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".red"
    [System.IO.File]::WriteAllBytes((Join-Path $userdataDir $redName), $bytes)
    Write-Host "Wrote $redName"
    $fileCount++
}

Write-Host ""
Write-Host "$fileCount file(s) written to: $userdataDir"
