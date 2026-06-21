# Midnight Club 2 Race Editor (.red) file parser
# Reads all *.red files from ./userdata/ and writes one *.json per file into ./userjson/

# Load enum data from race.schema.json — single source of truth
$schemaJson = Get-Content (Join-Path $PSScriptRoot "race.schema.json") -Raw
$schema     = $schemaJson | ConvertFrom-Json

$cities       = [string[]]$schema.properties.city.enum
$todNames     = [string[]]$schema.properties.timeOfDay.enum
$weatherNames = [string[]]$schema.properties.weather.enum
$traffNames   = [string[]]$schema.properties.traffic.enum
$vehicles     = [string[]]($schema.'$defs'.vehicleSlot.enum | Where-Object { $_ -ne $null })

# Build raceModes lookup: byte values start at 4, timeMode cycles within each raceType
$raceModes = @{}
$byte = 4
foreach ($rt in $schema.properties.raceType.enum) {
    foreach ($tm in $schema.properties.timeMode.enum) {
        $raceModes[$byte] = @{ Type = $rt; Time = $tm }
        $byte++
    }
}

$includeExtendedCpu = $false

function Format-JsonAllman([string]$json) {
    # Step 1: compact — strip all whitespace outside of strings
    $compact = [System.Text.StringBuilder]::new()
    $inStr = $false; $esc = $false
    foreach ($c in $json.ToCharArray()) {
        if ($esc)                          { $compact.Append($c) | Out-Null; $esc = $false; continue }
        if ($c -eq '\' -and $inStr)        { $compact.Append($c) | Out-Null; $esc = $true;  continue }
        if ($c -eq '"')                    { $inStr = -not $inStr; $compact.Append($c) | Out-Null; continue }
        if ($inStr)                        { $compact.Append($c) | Out-Null; continue }
        if ($c -notin ' ',"`t","`n","`r") { $compact.Append($c) | Out-Null }
    }
    $json = $compact.ToString()

    # Step 2: reformat with Allman style + 4-space indent
    $sb     = [System.Text.StringBuilder]::new()
    $indent = 0
    $inStr  = $false; $esc = $false

    for ($i = 0; $i -lt $json.Length; $i++) {
        $c = $json[$i]

        if ($esc)                   { $sb.Append($c) | Out-Null; $esc = $false; continue }
        if ($c -eq '\' -and $inStr) { $sb.Append($c) | Out-Null; $esc = $true;  continue }
        if ($c -eq '"')             { $inStr = -not $inStr; $sb.Append($c) | Out-Null; continue }
        if ($inStr)                 { $sb.Append($c) | Out-Null; continue }

        $pad = ' ' * (4 * $indent)

        switch ($c) {
            '{' {
                $sb.Append("{`n") | Out-Null
                $indent++
                $sb.Append(' ' * (4 * $indent)) | Out-Null
            }
            '[' {
                $sb.Append("[`n") | Out-Null
                $indent++
                $sb.Append(' ' * (4 * $indent)) | Out-Null
            }
            '}' {
                $indent--
                $sb.Append("`n$(' ' * (4 * $indent))}") | Out-Null
            }
            ']' {
                $indent--
                $sb.Append("`n$(' ' * (4 * $indent))]") | Out-Null
            }
            ':' {
                $next = if ($i + 1 -lt $json.Length) { $json[$i + 1] } else { $null }
                if ($next -eq '{' -or $next -eq '[') {
                    $sb.Append(":`n$pad") | Out-Null
                } else {
                    $sb.Append(': ') | Out-Null
                }
            }
            ',' {
                $sb.Append(",`n$(' ' * (4 * $indent))") | Out-Null
            }
            default {
                $sb.Append($c) | Out-Null
            }
        }
    }

    return $sb.ToString()
}

function Read-RedFile([string]$path) {
    $b = [System.IO.File]::ReadAllBytes($path)

    if ($b.Length -ne 222) {
        Write-Warning "$([System.IO.Path]::GetFileName($path)): unexpected file size $($b.Length) bytes (expected 222), skipping."
        return $null
    }

    # Race name: bytes 0x00-0x0C, null-padded ASCII
    $nameRaw = $b[0..12]
    $nullAt  = [Array]::IndexOf($nameRaw, [byte]0)
    $nameLen = if ($nullAt -ge 0) { $nullAt } else { 13 }
    $name    = [System.Text.Encoding]::ASCII.GetString($nameRaw, 0, $nameLen)

    # City: byte 0x0D
    $cityIdx = $b[13]
    $city    = if ($cityIdx -lt $cities.Length) { $cities[$cityIdx] } else { "Unknown ($cityIdx)" }

    # Time of Day: byte 0x0E
    $todIdx = $b[14]
    $tod    = if ($todIdx -lt $todNames.Length) { $todNames[$todIdx] } else { "Unknown ($todIdx)" }

    # Weather: byte 0x0F
    $weatherIdx = $b[15]
    $weather    = if ($weatherIdx -lt $weatherNames.Length) { $weatherNames[$weatherIdx] } else { "Unknown ($weatherIdx)" }

    # Race type + Time mode: byte 0x10
    $modeByte = $b[16]
    $mode     = $raceModes[[int]$modeByte]
    $raceType = if ($mode) { $mode.Type } else { "Unknown (0x$($modeByte.ToString("X2")))" }
    $timeMode = if ($mode) { $mode.Time } else { "Unknown (0x$($modeByte.ToString("X2")))" }

    # CPU Players: byte 0x11; vehicle slots: bytes 0x12-0x15 (one per player, 0xFF=unused)
    $cpuCount = $b[0x11]
    $vehA = $null; $vehB = $null
    if ($cpuCount -ge 1) {
        $idxA = $b[0x12]
        $vehA = if ($idxA -lt $vehicles.Length) { $vehicles[$idxA] } else { "Unknown (index $idxA)" }
    }
    if ($cpuCount -ge 2) {
        $idxB = $b[0x13]
        $vehB = if ($idxB -lt $vehicles.Length) { $vehicles[$idxB] } else { "Unknown (index $idxB)" }
    }
    $veh5 = $null; $veh6 = $null
    if ($includeExtendedCpu) {
        $idx5 = $b[0x16]
        $veh5 = if ($idx5 -eq 0xFF) { $null } elseif ($idx5 -lt $vehicles.Length) { $vehicles[$idx5] } else { "Unknown (index $idx5)" }
        $idx6 = $b[0x17]
        $veh6 = if ($idx6 -eq 0xFF) { $null } elseif ($idx6 -lt $vehicles.Length) { $vehicles[$idx6] } else { "Unknown (index $idx6)" }
    }

    # Traffic: byte 0x18
    $traffIdx = $b[24]
    $traffic  = if ($traffIdx -lt $traffNames.Length) { $traffNames[$traffIdx] } else { "Unknown ($traffIdx)" }

    # Pedestrians: byte 0x19
    $pedestrians = if ($b[25] -eq 0) { "Off" } else { "On" }

    # Checkpoint count: uint16 LE at 0x1A-0x1B (max 64)
    $count = [BitConverter]::ToUInt16($b, 26)

    # Checkpoint node IDs: count x uint16 LE starting at 0x1C
    #   Slots  1-50 live at 0x1C-0x7F; slots 51-64 overflow into 0x80-0x9B
    $nodes = for ($i = 0; $i -lt $count; $i++) {
        [BitConverter]::ToUInt16($b, 28 + $i * 2)
    }

    # Time bonuses (seconds per checkpoint): 1 byte each starting at 0x9C
    #   Slots  1-48 live at 0x9C-0xCB; slots 49-64 overflow into 0xCC-0xDB
    $bonuses = for ($i = 0; $i -lt $count; $i++) {
        $b[156 + $i]
    }

    # Laps: uint16 LE at 0xDC-0xDD (high byte 0xDD is always 0x00 since max is 4)
    $laps = if ($raceType -eq "Unordered") { $null } else { [int][BitConverter]::ToUInt16($b, 0xDC) }

    # Build checkpoint array (node + bonus pairs)
    $checkpoints = for ($i = 0; $i -lt $count; $i++) {
        [PSCustomObject]@{
            node       = [int]$nodes[$i]
            timeBonus  = [int]$bonuses[$i]
        }
    }

    # Assemble result object
    $result = [ordered]@{
        name         = $name
        city         = $city
        timeOfDay    = $tod
        weather      = $weather
        raceType     = $raceType
        timeMode     = $timeMode
        laps         = $laps
        traffic      = $traffic
        pedestrians  = $pedestrians
        cpuPlayers   = [int]$cpuCount
        cpuVehicleA  = $vehA
        cpuVehicleB  = $vehB
    }
    if ($includeExtendedCpu) {
        $result['cpuVehicle5'] = $veh5
        $result['cpuVehicle6'] = $veh6
    }
    $result['checkpoints'] = @($checkpoints)

    return $result
}

$userdataDir = Join-Path $PSScriptRoot "userdata"
$userjsonDir = Join-Path $PSScriptRoot "userjson"

if (-not (Test-Path $userjsonDir)) {
    New-Item -ItemType Directory -Path $userjsonDir | Out-Null
}

$canValidate = $PSVersionTable.PSVersion -ge [version]"6.1"
if (-not $canValidate) {
    Write-Warning "Schema validation requires PowerShell 6.1 or later - skipping."
}

$redFiles  = Get-ChildItem (Join-Path $userdataDir "*.red") | Sort-Object { [regex]::Replace($_.BaseName, '\d+', { $args[0].Value.PadLeft(10, '0') }) }
$fileCount = 0

foreach ($file in $redFiles) {
    $data = Read-RedFile $file.FullName
    if ($null -eq $data) { continue }

    $jsonName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".json"
    $jsonPath = Join-Path $userjsonDir $jsonName
    $raw = $data | ConvertTo-Json -Depth 5 -Compress

    if ($canValidate) {
        $isValid = Test-Json -Json $raw -Schema $schemaJson -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
        if (-not $isValid) {
            Write-Warning "$($file.Name): schema validation failed:"
            foreach ($e in $schemaErrors) { Write-Warning "  $($e.Exception.Message)" }
        }
    }

    Format-JsonAllman $raw | Set-Content -Encoding UTF8 -Path $jsonPath
    Write-Host "Wrote $jsonName"
    $fileCount++
}

Write-Host ""
Write-Host "$fileCount file(s) written to: $userjsonDir"
