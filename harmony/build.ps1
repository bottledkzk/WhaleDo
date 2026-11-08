param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidateSet('debug','release')][string]$BuildMode = 'debug'
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if ($projectRoot -match '[^\x00-\x7F]') {
    throw 'Hvigor requires an English project path. Clone the repository to a path containing ASCII characters only.'
}
$nodeHome = Join-Path $DevEcoHome 'tools\node'
$hvigorScript = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
if (!(Test-Path -LiteralPath $hvigorScript)) {
    throw "Official Hvigor was not found under: $DevEcoHome"
}
$variables = @('NODE_HOME','JAVA_HOME','DEVECO_SDK_HOME','HVIGOR_USER_HOME','npm_config_cache','PATH')
$oldValues = @{}
foreach ($variable in $variables) {
    $oldValues[$variable] = [Environment]::GetEnvironmentVariable($variable, 'Process')
}
Push-Location -LiteralPath $projectRoot
try {
    $env:NODE_HOME = $nodeHome
    $env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
    $env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
    $env:HVIGOR_USER_HOME = Join-Path (Split-Path $projectRoot -Parent) '.hvigor-home'
    $env:npm_config_cache = Join-Path (Split-Path $projectRoot -Parent) '.npm-cache'
    $env:PATH = "$nodeHome;$(Join-Path $DevEcoHome 'tools\ohpm\bin');$env:PATH"
    & (Join-Path $nodeHome 'node.exe') $hvigorScript --mode module -p product=default -p module=entry@default -p "buildMode=$BuildMode" assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) {
        throw "Hvigor failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
    foreach ($variable in $variables) {
        [Environment]::SetEnvironmentVariable($variable, $oldValues[$variable], 'Process')
    }
}
