param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$Version,

  [string]$SourceRepo = "taygunsavas/git-tangle",
  [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

function Get-ToolchainBinCandidates {
  $candidates = @(
    "C:\msys64\mingw64\bin",
    "C:\msys64\ucrt64\bin"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      $candidate
    }
  }
}

function Get-MpCmdRunPath {
  $platformRoot = Join-Path $env:ProgramData "Microsoft\Windows Defender\Platform"
  if (Test-Path $platformRoot) {
    $latestPlatform = Get-ChildItem $platformRoot -Directory |
      Sort-Object Name -Descending |
      Select-Object -First 1
    if ($latestPlatform) {
      $platformPath = Join-Path $latestPlatform.FullName "MpCmdRun.exe"
      if (Test-Path $platformPath) {
        return $platformPath
      }
    }
  }

  $fallbackCandidates = @(
    (Join-Path $env:ProgramFiles "Windows Defender\MpCmdRun.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Windows Defender\MpCmdRun.exe")
  )

  foreach ($candidate in $fallbackCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  throw "MpCmdRun.exe not found."
}

function Assert-ZipContainsRequiredEntries {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
  )

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $requiredEntries = @(
      "git-tangle.exe",
      "git-tangle.cmd",
      "bin/git-tangle",
      "libexec/tangle/utils.sh"
    )

    $entryMap = @{}
    foreach ($entry in $archive.Entries) {
      $entryMap[$entry.FullName] = $true
    }

    foreach ($required in $requiredEntries) {
      if (-not $entryMap.ContainsKey($required)) {
        throw "Required entry missing from ZIP: $required"
      }
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Assert-ExitCodeZero {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  if ($LASTEXITCODE -ne 0) {
    throw "$Message (exit code: $LASTEXITCODE)"
  }
}

function Assert-WindowsShimToolchainAvailable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BashPath
  )

  $probe = @'
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 && command -v x86_64-w64-mingw32-windres >/dev/null 2>&1; then
  exit 0
fi
if command -v gcc >/dev/null 2>&1 && command -v windres >/dev/null 2>&1 && [[ "${OS:-}" == "Windows_NT" ]]; then
  exit 0
fi
exit 1
'@

  & $BashPath -lc $probe
  if ($LASTEXITCODE -ne 0) {
    throw "Required Windows shim compiler toolchain not found. Install x86_64-w64-mingw32-gcc + x86_64-w64-mingw32-windres, or gcc + windres on Windows."
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$bash = Join-Path $env:ProgramFiles "Git\bin\bash.exe"
if (-not (Test-Path $bash)) {
  throw "Git Bash not found at $bash"
}

$toolchainBins = @(Get-ToolchainBinCandidates)
$originalPath = $env:PATH
if ($toolchainBins.Count -gt 0) {
  $env:PATH = (($toolchainBins -join ";") + ";" + $env:PATH)
  Write-Host "[preflight] Added toolchain paths to PATH: $($toolchainBins -join ', ')"
}

$distRoot = Join-Path $repoRoot "dist"
$zipPath = Join-Path $distRoot "git-tangle_${Version}_windows_x64.zip"
$zipShaPath = Join-Path $distRoot "git-tangle_${Version}_windows_x64.zip.sha256"
$manifestRoot = Join-Path $distRoot "preflight-manifests"
$manifestPath = Join-Path $manifestRoot "manifests\t\taygunsavas\git-tangle\$Version"
$tempRoot = Join-Path $env:TEMP "git-tangle-preflight-$Version"
$pkgRoot = Join-Path $tempRoot "Packages\taygunsavas.git-tangle__Preflight"
$linksRoot = Join-Path $tempRoot "Links"
$linkedExe = Join-Path $linksRoot "git-tangle-preflight.exe"

Push-Location $repoRoot
try {
  Write-Host "[preflight] Checking Windows shim compiler toolchain..."
  Assert-WindowsShimToolchainAvailable -BashPath $bash

  Write-Host "[preflight] Packaging with required Windows EXE shim..."
  $oldRequireShim = $env:REQUIRE_WINDOWS_SHIM_EXE
  $env:REQUIRE_WINDOWS_SHIM_EXE = "true"
  try {
    & $bash -lc "./scripts/package.sh $Version"
    Assert-ExitCodeZero -Message "package.sh failed"
  }
  finally {
    if ($null -eq $oldRequireShim) {
      Remove-Item Env:REQUIRE_WINDOWS_SHIM_EXE -ErrorAction SilentlyContinue
    }
    else {
      $env:REQUIRE_WINDOWS_SHIM_EXE = $oldRequireShim
    }
  }

  if (-not (Test-Path $zipPath)) {
    throw "Expected ZIP not found: $zipPath"
  }
  if (-not (Test-Path $zipShaPath)) {
    throw "Expected ZIP checksum not found: $zipShaPath"
  }

  Write-Host "[preflight] Verifying required ZIP contents..."
  Assert-ZipContainsRequiredEntries -ZipPath $zipPath

  $sha256 = ((Get-Content $zipShaPath | Select-Object -First 1) -split " ")[0].Trim().ToLowerInvariant()
  if ($sha256 -notmatch "^[0-9a-f]{64}$") {
    throw "Invalid SHA256 format in ${zipShaPath}: $sha256"
  }

  if (Test-Path $manifestRoot) {
    Remove-Item -Recurse -Force $manifestRoot
  }

  Write-Host "[preflight] Generating WinGet manifests..."
  & $bash -lc "./scripts/generate-winget-manifests.sh $Version $SourceRepo $sha256 dist/preflight-manifests"
  Assert-ExitCodeZero -Message "generate-winget-manifests.sh failed"

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw "winget command not found."
  }
  if (-not (Test-Path $manifestPath)) {
    throw "Generated manifest path not found: $manifestPath"
  }

  Write-Host "[preflight] Running winget validate..."
  & $winget.Source validate --manifest $manifestPath --verbose-logs
  Assert-ExitCodeZero -Message "winget validate failed"

  if (Test-Path $tempRoot) {
    Remove-Item -Recurse -Force $tempRoot
  }
  New-Item -ItemType Directory -Path $pkgRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $linksRoot -Force | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $pkgRoot -Force

  $pkgExe = Join-Path $pkgRoot "git-tangle.exe"
  $pkgCmd = Join-Path $pkgRoot "git-tangle.cmd"
  if (-not (Test-Path $pkgExe)) { throw "Packaged EXE not found: $pkgExe" }
  if (-not (Test-Path $pkgCmd)) { throw "Packaged CMD wrapper not found: $pkgCmd" }

  $mpCmdRun = Get-MpCmdRunPath
  Write-Host "[preflight] Running Windows Defender scan..."
  & $mpCmdRun -Scan -ScanType 3 -File $zipPath
  Assert-ExitCodeZero -Message "Defender scan failed for ZIP"
  & $mpCmdRun -Scan -ScanType 3 -File $pkgExe
  Assert-ExitCodeZero -Message "Defender scan failed for launcher EXE"

  if (Test-Path $linkedExe) {
    Remove-Item -Force $linkedExe
  }
  New-Item -ItemType HardLink -Path $linkedExe -Target $pkgExe | Out-Null

  Write-Host "[preflight] Smoke testing WinGet Links launcher..."
  & $linkedExe --version
  Assert-ExitCodeZero -Message "WinGet Links launcher failed for --version"
  & $linkedExe --help | Out-Null
  Assert-ExitCodeZero -Message "WinGet Links launcher failed for --help"

  Write-Host "[preflight] Smoke testing .cmd launcher..."
  cmd /c "`"$pkgCmd`" --version" | Out-Null
  Assert-ExitCodeZero -Message "git-tangle.cmd failed for --version"
  cmd /c "`"$pkgCmd`" --help" | Out-Null
  Assert-ExitCodeZero -Message "git-tangle.cmd failed for --help"

  Write-Host ""
  Write-Host "[preflight] SUCCESS"
  Write-Host "[preflight] version: $Version"
  Write-Host "[preflight] zip: $zipPath"
  Write-Host "[preflight] sha256: $sha256"
  Write-Host "[preflight] manifests: $manifestPath"
}
finally {
  $env:PATH = $originalPath
  Pop-Location
  if ((-not $KeepTemp) -and (Test-Path $tempRoot)) {
    Remove-Item -Recurse -Force $tempRoot
  }
}
