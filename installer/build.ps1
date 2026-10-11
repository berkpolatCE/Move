param(
    [string] $Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$publishDir = Join-Path $root "artifacts\publish"
$outputDir = Join-Path $root "artifacts\installer"

dotnet publish (Join-Path $root "src\Move\Move.csproj") `
    -c Release `
    -r win-x64 `
    --self-contained `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=none `
    -p:Version=$Version `
    -o $publishDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dotnet build (Join-Path $PSScriptRoot "Move.Installer.wixproj") `
    -c Release `
    -p:Version=$Version `
    -p:AppPublishDir=$publishDir `
    -o $outputDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-ChildItem $outputDir -Filter *.msi
