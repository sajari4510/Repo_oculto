param(
    [string]$Version = "Version1",
    [string]$ExePath,
    [string]$TestCase = "100",
    [string]$OutputDir = ".\ProfilerResults"
)

# Ajusta rutas si es necesario
$vsPerfPaths = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Team Tools\Performance Tools\vsperfcmd.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Platform\Profiler\vsperfcmd.exe"
)

$vsPerfCmd = $null
foreach ($path in $vsPerfPaths) {
    if (Test-Path $path) { $vsPerfCmd = $path; break }
}

if (-not $vsPerfCmd) { Write-Host "No se encontró vsperfcmd.exe" -ForegroundColor Red; exit 1 }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportName = "${Version}_${TestCase}_${timestamp}"
$vspFile = Join-Path $OutputDir "$reportName.vsp"
$reportDir = Join-Path $OutputDir $reportName
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

Write-Host "Iniciando profiling para $Version - TestCase $TestCase..." -ForegroundColor Cyan

& $vsPerfCmd /start:sample /output:$vspFile /user:*

# Ejecutar la aplicación con argumentos de benchmark
& $ExePath -bench -size $TestCase -output $reportDir

# Detener profiling
& $vsPerfCmd /shutdown

# Generar reporte
& $vsPerfCmd /report:summary /summary:all /output:"$($reportDir)\summary.txt" $vspFile

Write-Host "Reporte generado en: $reportDir" -ForegroundColor Green
Write-Host "Archivo VSP: $vspFile" -ForegroundColor Green
