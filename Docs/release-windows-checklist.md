# Windows Release Security Checklist

Use this checklist before publishing a tagged release that will be consumed by `winget-pkgs`.

## 1) Build requirements
- `scripts/package.sh <version>` must produce:
  - `dist/git-tangle_<version>_windows_x64.zip`
  - `dist/git-tangle_<version>_windows_x64.zip.sha256`
- The packaged ZIP must include:
  - `git-tangle.exe`
  - `bin/git-tangle`
  - `libexec/tangle/utils.sh`

## 2) Manifest validation
- Generate manifests:
  - `scripts/generate-winget-manifests.sh <version> <owner/repo> <sha256> <out-root>`
- Validate with WinGet:
  - `winget validate --manifest manifests/t/taygunsavas/git-tangle/<version> --verbose-logs`

## 3) Windows Defender gate
- Scan both archive and launcher executable:
  - `MpCmdRun.exe -Scan -ScanType 3 -File <zip>`
  - `MpCmdRun.exe -Scan -ScanType 3 -File <extracted git-tangle.exe>`
- Release must be blocked on any non-zero scan result.

## 4) If a false positive is detected
- Submit the flagged sample/hash to Microsoft Security Intelligence:
  - https://www.microsoft.com/en-us/wdsi/filesubmission
- Provide:
  - SHA256 of flagged file
  - Release URL
  - Detection name from logs (for example: `Trojan:Win32/Wacatac.H!ml`)
- In the `winget-pkgs` PR, leave a note that remediation submission is in progress.

## 5) PR hygiene
- If a release PR is blocked by malware detection, close it as superseded.
- Ship a new patch version (`x.y.(z+1)`) after mitigation.
