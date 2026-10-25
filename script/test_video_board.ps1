# Human-in-the-loop board check, adapted from diagnosing-bugs/hitl-loop.template.sh.
# RecordOnly imports an observation already supplied by the person operating the board.
param(
    [Parameter(Mandatory=$true)][string]$Bitstream,
    [Parameter(Mandatory=$true)][string]$Mode,
    [switch]$RecordOnly,
    [string]$ObservedOrder,
    [ValidateSet('yes','no')][string]$EdgesAtSides,
    [string]$Photo
)
$ErrorActionPreference = 'Stop'
$bit = Get-Item -LiteralPath $Bitstream
if (-not $RecordOnly) {
    Write-Host "Download to SRAM: $($bit.FullName). Do not program Flash."
    Read-Host "Select mode $Mode; release KEY4 and wait for the monitor to lock. Press Enter when ready"
    $ObservedOrder = Read-Host 'Read the ten column numbers from left to right (space separated)'
    $EdgesAtSides = Read-Host 'Are the red and green borders at the LEFT and RIGHT screen edges? (yes/no)'
}
if ($EdgesAtSides -notin @('yes','no')) { throw 'EdgesAtSides must be yes or no.' }
$numbers = @($ObservedOrder.Trim() -split '[,\s]+' | ForEach-Object { [int]$_ })
if ($numbers.Count -ne 10 -or (@($numbers | Sort-Object -Unique) -join ' ') -ne '0 1 2 3 4 5 6 7 8 9') {
    throw 'Record each column number 0 through 9 exactly once; incomplete/no-signal observations require a separate report.'
}
$passed = (($numbers -join ' ') -eq '0 1 2 3 4 5 6 7 8 9') -and ($EdgesAtSides -eq 'yes')
$photoInfo = $null
if ($Photo) {
    $photoFile = Get-Item -LiteralPath $Photo
    $photoInfo = @{ path=$photoFile.FullName; sha256=(Get-FileHash -LiteralPath $photoFile.FullName -Algorithm SHA256).Hash.ToLower() }
}
$result = [ordered]@{
    recorded_at=(Get-Date -Format o); mode=$Mode; passed=$passed
    source='human board observation; not simulation or automatic capture'
    imported=[bool]$RecordOnly; bitstream=$bit.FullName
    candidate_sha256=(Get-FileHash -LiteralPath $bit.FullName -Algorithm SHA256).Hash.ToLower()
    hardware_bitstream_readback_verified=$false
    column_order=$numbers; edges_at_sides=($EdgesAtSides -eq 'yes'); photo=$photoInfo
}
$outputDir = Join-Path $PSScriptRoot '..\build\video_board'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$outputFile = Join-Path $outputDir ("observation-{0}.json" -f [guid]::NewGuid().ToString('N'))
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputFile -Encoding UTF8
Write-Host "MODE=$Mode ORDER=$($numbers -join ' ') EDGES_AT_SIDES=$EdgesAtSides"
Write-Host "RECORD=$outputFile"
if (-not $passed) { Write-Host 'FAIL: horizontal wrap or displaced borders remain on the physical display.'; exit 1 }
Write-Host 'PASS: this human observation has ordered columns and borders at the screen edges.'
