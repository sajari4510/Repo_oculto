param(
    [string]$OutputDir = ".\Comparisons",
    [bool]$UseProfiler = $false
)

$versions = @(
    @{Name="Version1"; ExePath="C:\Users\Isaac\OneDrive\Desktop\Progra\copia\FamilyGraph\Proyecto Grafos\bin\x64\Release\Proyecto Grafos.exe"},
    @{Name="Version2"; ExePath="C:\Users\Isaac\OneDrive\Desktop\Progra\copia 2\FamilyGraph\Proyecto Grafos\bin\x64\Release\Proyecto Grafos.exe"},
    @{Name="Version3"; ExePath="C:\Users\Isaac\OneDrive\Desktop\Progra\copia 3\FamilyGraph\Proyecto Grafos\bin\x64\Release\Proyecto Grafos.exe"}
)

$testSizes = @(100, 500, 1000, 2000, 5000)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultsDir = Join-Path $OutputDir "Comparison_$timestamp"
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

# Usar punto y coma como separador: Excel en espanol lo reconoce como columnas automaticamente
$sep = ","
$csvFile = Join-Path $resultsDir "all_results.csv"
"Version${sep}TestCase${sep}Iteration${sep}AddTimeMs${sep}SearchTimeMs${sep}LayoutTimeMs${sep}PeakMemoryMB" | Out-File $csvFile -Encoding UTF8

# Verificar que los tres exe existen antes de empezar
$missingAny = $false
foreach ($version in $versions) {
    if (-not (Test-Path $version.ExePath)) {
        Write-Host "ERROR: No se encontro el ejecutable de $($version.Name):" -ForegroundColor Red
        Write-Host "  $($version.ExePath)" -ForegroundColor Red
        $missingAny = $true
    } else {
        Write-Host "OK $($version.Name): $($version.ExePath)" -ForegroundColor Green
    }
}
if ($missingAny) {
    Write-Host ""
    Write-Host "Compila los proyectos faltantes en Visual Studio (Release / x64) y vuelve a intentarlo." -ForegroundColor Yellow
    exit 1
}

foreach ($version in $versions) {
    Write-Host "`n=== Testing $($version.Name) ===" -ForegroundColor Cyan
    $versionDir = Join-Path $resultsDir $version.Name
    New-Item -ItemType Directory -Path $versionDir -Force | Out-Null

    foreach ($size in $testSizes) {
        for ($iter = 1; $iter -le 3; $iter++) {
            Write-Host "Running $($version.Name) size $size iter $iter" -ForegroundColor Yellow

            if ($UseProfiler) {
                $profilerDir = Join-Path $versionDir "Size${size}_Iter${iter}"
                New-Item -ItemType Directory -Path $profilerDir -Force | Out-Null
                & .\RunVSPerf.ps1 -Version $version.Name -ExePath $version.ExePath -TestCase $size -OutputDir $profilerDir
                $summary = Get-ChildItem -Path $profilerDir -Recurse -Filter summary.txt -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($summary) {
                    $content = Get-Content $summary.FullName -ErrorAction SilentlyContinue
                    $time = 0
                    foreach ($line in $content) {
                        if ($line -match "Elapsed Time") { $time = ($line -replace '\D','') }
                    }
                    "$($version.Name)${sep}$size${sep}$iter${sep}$time${sep}0${sep}0${sep}0" | Out-File -Append $csvFile -Encoding UTF8
                }
            } else {
                $outFile = Join-Path $versionDir "${size}_${iter}.txt"
                & $version.ExePath -bench -size $size -output $outFile 2>&1 | Out-Null

                $addTime    = 0
                $searchTime = 0
                $layoutTime = 0
                $peak       = 0
                $status     = "NO_OUTPUT"

                if (Test-Path $outFile) {
                    $lines = Get-Content $outFile -ErrorAction SilentlyContinue
                    foreach ($l in $lines) {
                        if ($l -match "^TimeMs:(\d+)")        { $addTime    = $matches[1] }
                        if ($l -match "^SearchTimeMs:(\d+)")  { $searchTime = $matches[1] }
                        if ($l -match "^LayoutTimeMs:(\d+)")  { $layoutTime = $matches[1] }
                        if ($l -match "^PeakMemory:(\d+)")    { $peak       = $matches[1] }
                        if ($l -match "^Status:(.+)")         { $status     = $matches[1] }
                    }
                    if ($status -ne "OK") {
                        Write-Host "  WARNING: Status=$status" -ForegroundColor DarkYellow
                    }
                } else {
                    Write-Host "  WARNING: Output file not created" -ForegroundColor DarkYellow
                }

                "$($version.Name)${sep}$size${sep}$iter${sep}$addTime${sep}$searchTime${sep}$layoutTime${sep}$peak" | Out-File -Append $csvFile -Encoding UTF8
            }
        }
    }
}

Write-Host "`nComparison finished. Results at: $resultsDir" -ForegroundColor Green