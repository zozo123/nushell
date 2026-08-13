$out = 'C:\winconfig'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# 1. Exact VS component set -> .vsconfig (replayable with --config)
$vs   = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$inst = & $vs -latest -products * -property installationPath
$vsi  = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
if (Test-Path $vsi) {
  & $vsi export --installPath "$inst" --config "$out\nushell-windows.vsconfig" --quiet | Out-Null
  Start-Sleep -Seconds 20
}
if (Test-Path "$out\nushell-windows.vsconfig") { "VSCONFIG_OK" } else { "VSCONFIG_FAILED" }

# 2. Toolchain registry state
$reg = @()
$reg += "; MSVC / VS install roots"
$reg += (reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7" 2>$null)
$reg += (reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VC7" 2>$null)
$reg += "; Windows SDK roots"
$reg += (reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots" 2>$null)
$reg += "; .NET"
$reg += (reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2>$null)
$reg | Set-Content "$out\toolchain-registry.txt"

# 3. Full environment
Get-ChildItem Env: | Sort-Object Name |
  ForEach-Object { "$($_.Name)=$($_.Value)" } | Set-Content "$out\environment.txt"

# 4. Installed software
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -EA SilentlyContinue |
  Where-Object DisplayName |
  Select-Object DisplayName, DisplayVersion |
  Sort-Object DisplayName |
  ForEach-Object { "{0}`t{1}" -f $_.DisplayName, $_.DisplayVersion } |
  Set-Content "$out\installed-software.txt"

# 5. VS component list (resolved, human-readable)
& $vs -latest -products * -format json | Set-Content "$out\vswhere.json"

Get-ChildItem $out | ForEach-Object { "{0,-32} {1} bytes" -f $_.Name, $_.Length }
