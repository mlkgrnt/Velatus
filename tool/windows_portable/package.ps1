<#
.SYNOPSIS
Packs a Flutter Windows release folder into one portable .exe.

.DESCRIPTION
Embeds the whole release as a ZIP resource in a small C# launcher (compiled
with the .NET Framework compiler that ships with Windows). The launcher
unpacks to %LOCALAPPDATA%\Velatus\<version> on first run and then starts the
real velatus.exe from there.

.EXAMPLE
./tool/windows_portable/package.ps1 -ReleaseDir build/windows/x64/runner/Release `
    -Version 0.4.1 -Out velatus-0.4.1-windows.exe
#>
param(
    [Parameter(Mandatory = $true)][string] $ReleaseDir,
    [Parameter(Mandatory = $true)][string] $Version,
    [Parameter(Mandatory = $true)][string] $Out
)

$ErrorActionPreference = 'Stop'

$release = (Resolve-Path $ReleaseDir).Path
if (-not (Test-Path (Join-Path $release 'velatus.exe'))) {
    throw "No velatus.exe in $release - build Windows first."
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("velatus-portable-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

try {
    $zip = Join-Path $work 'payload.zip'
    Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip -CompressionLevel Optimal

    $versionSource = Join-Path $work 'Version.cs'
    "internal static class BuildInfo { internal const string Version = `"$Version`"; }" |
        Set-Content -Path $versionSource -Encoding utf8

    $csc = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) {
        throw "The .NET Framework C# compiler is missing: $csc"
    }

    $outPath = Join-Path (Get-Location).Path $Out
    & $csc /nologo /target:winexe /optimize+ "/out:$outPath" `
        "/resource:$zip,payload.zip" `
        /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll `
        (Join-Path $PSScriptRoot 'launcher.cs') $versionSource
    if ($LASTEXITCODE -ne 0) {
        throw "csc failed with exit code $LASTEXITCODE"
    }
    "Built $outPath ($((Get-Item $outPath).Length) bytes)"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -Confirm:$false
}
