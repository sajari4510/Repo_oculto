param(
    [string]$TestName = "Benchmark",
    [string]$OutputDir = ".\BenchmarkResults",
    [int]$Iterations = 3
)

# Configuración de rutas de las 3 versiones (ajusta rutas a tus ejecutables)
$versions = @{
    "Version1" = "C:\Users\Isaac\OneDrive\Desktop\Progra\copia\FamilyGraph\Proyecto Grafos.sln"
    "Version2" = "C:\Users\Isaac\OneDrive\Desktop\Progra\copia\FamilyGraph\Proyecto Grafos.sln"
    "Version3" = "C:\Users\Isaac\OneDrive\Desktop\Progra\copia\FamilyGraph\Proyecto Grafos.sln"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultDir = Join-Path $OutputDir "$TestName_$timestamp"
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null

$summaryFile = Join-Path $resultDir "summary.csv"
"Version,Iteration,TestCase,TotalTime(ms),PeakMemory(MB)" | Out-File $summaryFile

$testCases = @(100, 1000, 5000)

function Run-Benchmark {
    param(
        [string]$ExePath,
        [string]$Version,
        [int]$Iteration,
        [int]$TestSize
    )

    $args = "-bench -size $TestSize -output $resultDir\${Version}_Size${TestSize}_Iter${Iteration}.txt"
    $proc = Start-Process -FilePath $ExePath -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $resultDir "${Version}_Size${TestSize}_Iter${Iteration}.log")
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc.WaitForExit()
    $sw.Stop()

    # Try to parse peak memory from output log
    $log = Get-Content (Join-Path $resultDir "${Version}_Size${TestSize}_Iter${Iteration}.log") -ErrorAction SilentlyContinue
    $peak = 0
    foreach ($line in $log) {
        if ($line -match "PeakMemory:(\d+)") { $peak = [int]$matches[1]; break }
    }

    "$Version,$Iteration,$TestSize,$($sw.Elapsed.TotalMilliseconds),$peak" | Out-File -Append $summaryFile
}

foreach ($version in $versions.Keys) {
    foreach ($size in $testCases) {
        for ($i = 1; $i -le $Iterations; $i++) {
            Write-Host "Running $version size $size iter $i"
            $exe = $versions[$version]
            if (-not (Test-Path $exe)) { Write-Host "Executable not found: $exe" -ForegroundColor Red; continue }
            Run-Benchmark -ExePath $exe -Version $version -Iteration $i -TestSize $size
        }
    }
}

Write-Host "Results: $resultDir"
