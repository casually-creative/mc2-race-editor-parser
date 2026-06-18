# PowerShell Notes

## Critical: everything must be on one line

**Multi-line script blocks sent via the `run_in_terminal` tool are silently ignored** in the VS Code PowerShell Extension terminal. The prompt returns immediately with no output and no error — the code simply does not run.

**Write all code as a single semicolon-delimited line.** PowerShell `foreach`, `for`, `if/else`, and nested blocks all work on one line:

```powershell
# WRONG — multi-line block, silently does nothing
foreach ($f in Get-ChildItem "*.red") {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    Write-Host $b.Length
}

# CORRECT — identical logic, one line
foreach ($f in (Get-ChildItem "*.red")) { $b = [System.IO.File]::ReadAllBytes($f.FullName); Write-Host $b.Length }
```

This applies to all block constructs. Use semicolons between every statement inside `{ }`. Variable assignments, loops, and conditionals all chain with `;` on a single line without issue.

## Critical: output method matters

**`Format-List` and `Format-Table` produce no visible output** when run inside the VS Code PowerShell Extension terminal (and certain other non-interactive hosts). This is a PowerShell formatting-subsystem behaviour, not a parsing error. The script runs and the objects are constructed correctly — they are simply never rendered.

**Always end a pipeline with `| Out-String`** when running in a VS Code terminal, or write each value explicitly with `Write-Host`.

```powershell
# WRONG — silent in VS Code terminal
$objects | Format-List

# CORRECT
$objects | Out-String | Write-Host
# or
$objects | ForEach-Object { Write-Host $_ }
```

## Critical: hashtable key type mismatch with byte arrays

**Indexing a `[byte[]]` array returns a `[byte]`, not an `[int]`.** PowerShell hashtable keys defined with integer literals are stored as `[int]`. A `[byte]` key will **not** match an `[int]` key — the lookup silently returns `$null` with no error.

This affects any enum-lookup hashtable used with raw byte data (e.g. race mode, city, weather).

```powershell
$rmn = @{ 4 = 'Unordered/None'; 7 = 'Ordered/None' }
$b = [System.IO.File]::ReadAllBytes($file)

# WRONG — $b[16] is [byte]; lookup returns $null
$rmn[$b[16]]

# CORRECT — cast to [int] first
$rmn[[int]$b[16]]
```

Always cast byte-array elements to `[int]` before using them as hashtable keys.