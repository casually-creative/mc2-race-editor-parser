# Build.ps1
# Builds standalone scripts into dist/ by inlining src/race.schema.json.
# The source scripts in src/ reference the schema file at runtime.
# The built scripts in dist/ are self-contained and have no external dependencies.

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcDir   = Join-Path $repoRoot "src"
$distDir  = Join-Path $repoRoot "dist"

if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

$schemaContent = (Get-Content (Join-Path $srcDir "race.schema.json") -Raw).TrimEnd()

# The 2-line schema-load block present in every source script
$sourceBlock = '$schemaJson = Get-Content (Join-Path $PSScriptRoot "race.schema.json") -Raw' + "`n" +
               '$schema     = $schemaJson | ConvertFrom-Json'

# Replacement: single-quoted here-string so the JSON content is never interpreted
$inlinedBlock = '$schemaJson = @''' + "`n" + $schemaContent + "`n'@`n" +
                '$schema     = $schemaJson | ConvertFrom-Json'

# Minify: strip comments/blanks and compress each code segment to one line.
# Here-string content is preserved verbatim (the @'...'@ syntax requires real newlines).
function Compress-Lines([System.Collections.Generic.List[string]]$lines) {
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $cur  = ($lines[$i].Trim()) -replace '\s{2,}', ' '
        if ($i -gt 0) {
            $prev = $lines[$i - 1].TrimEnd()
            if ($prev.Length -gt 0 -and $prev[-1] -eq '`') {
                $sb.Remove($sb.Length - 1, 1) | Out-Null          # strip backtick continuation
            } elseif ($prev -match '[{(|,]$') {
                # no separator - block/expression continues on next line
            } elseif ($cur -match '^(else|elseif|catch|finally)\b') {
                $sb.Append(' ') | Out-Null                        # must not use ; before else/catch
            } else {
                $sb.Append(';') | Out-Null
            }
        }
        $sb.Append($cur) | Out-Null
    }
    return $sb.ToString()
}

function Invoke-Minify([string]$content) {
    $lines     = $content -split "`n"
    $segments  = [System.Collections.Generic.List[string]]::new()
    $codeBuf   = [System.Collections.Generic.List[string]]::new()
    $inHereStr = $false
    foreach ($line in $lines) {
        if ($inHereStr) {
            $segments.Add($line)
            if ($line -match "^'@") { $inHereStr = $false }
            continue
        }
        $t = $line.TrimEnd()
        if ($t -match "@'$") {
            if ($codeBuf.Count -gt 0) { $segments.Add((Compress-Lines $codeBuf)); $codeBuf.Clear() }
            $segments.Add($t)
            $inHereStr = $true
            continue
        }
        if ($t.Length -gt 0 -and $t -notmatch '^\s*#') { $codeBuf.Add($t) }
    }
    if ($codeBuf.Count -gt 0) { $segments.Add((Compress-Lines $codeBuf)) }
    return $segments -join "`n"
}

foreach ($file in Get-ChildItem (Join-Path $srcDir "*.ps1")) {
    $content = (Get-Content $file.FullName -Raw) -replace "`r`n", "`n"
    $built   = $content.Replace($sourceBlock, $inlinedBlock)

    if ($built -eq $content) {
        Write-Warning "$($file.Name): schema-load block not found - file was not modified."
    } else {
        $built = Invoke-Minify $built
        [System.IO.File]::WriteAllText((Join-Path $distDir $file.Name), $built, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Built $($file.Name)"
    }
}

Write-Host ""
Write-Host "Build complete. Output: $distDir"
