# Windows Release Security Checklist

Use this checklist before publishing a tagged release that will be consumed by `winget-pkgs`.

## 0) One-command preflight (recommended)
- Run the full local gate before creating a release tag:
  - `pwsh -File .\scripts\preflight-release.ps1 -Version 1.0.3`
- This command verifies packaging, WinGet manifest generation/validation, Defender scan, WinGet Links launcher behavior, and `.cmd` launcher behavior.
- If it fails, do not tag. Fix the issue and rerun until it passes.

## 1) Prerequisites
- Required tools on Windows:
  - Git Bash at `C:\Program Files\Git\bin\bash.exe`
  - `winget`
  - Windows Defender `MpCmdRun.exe`
- Local packaging also requires a Windows resource-capable compiler toolchain (`x86_64-w64-mingw32-gcc` + `x86_64-w64-mingw32-windres`, or equivalent `gcc` + `windres` on `Windows_NT`).
- If the toolchain is missing, `scripts/package.sh` will fail when `REQUIRE_WINDOWS_SHIM_EXE=true`. Do not bypass this for release.

## 2) Expected artifacts after preflight
- `dist/git-tangle_<version>.tar.gz`
- `dist/git-tangle_<version>.tar.gz.sha256`
- `dist/git-tangle_<version>_windows_x64.zip`
- `dist/git-tangle_<version>_windows_x64.zip.sha256`
- `dist/preflight-manifests/manifests/t/taygunsavas/git-tangle/<version>`

## 3) If a false positive is detected
- Submit the flagged sample/hash to Microsoft Security Intelligence:
  - https://www.microsoft.com/en-us/wdsi/filesubmission
- Provide:
  - SHA256 of flagged file
  - Release URL
  - Detection name from logs (for example: `Trojan:Win32/Wacatac.H!ml`)
- In the `winget-pkgs` PR, leave a note that remediation submission is in progress.

## 4) PR hygiene
- If a release PR is blocked by malware detection, close it as superseded.
- Ship a new patch version (`x.y.(z+1)`) after mitigation.
