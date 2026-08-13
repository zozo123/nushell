# Windows image configuration

The Windows build environment nushell's `x86_64-pc-windows-msvc` job runs on,
captured from a live **Namespace Windows instance** on 2026-08-13.

Captured with `nsc create --machine_type windows/amd64:4x8` followed by
`nsc ssh <instance>` — no GitHub App connection required.

Machine: `Microsoft Windows [Version 10.0.20348.5139]` (Server 2022),
user `namespacerunner\runneradmin`.

## Files

| File | What it is |
|---|---|
| `nushell-windows.vsconfig` | **The replayable one.** 217 Visual Studio components, exported with `vs_installer export`. Feed it back to an installer to reproduce this exact VS layout. |
| `vswhere.json` | VS instance metadata — product, version, install path, install date. |
| `toolchain-registry.txt` | Registry state the toolchain resolves through: `SxS\VS7`, `SxS\VC7`, `Windows Kits\Installed Roots`, .NET release. |
| `environment.txt` | Full environment, including `PATH`, `INCLUDE`, `LIB`. |
| `installed-software.txt` | Everything in Add/Remove Programs, with versions. |

## Reproducing the environment

```powershell
# From a VS Build Tools or VS bootstrapper:
vs_BuildTools.exe --quiet --wait --norestart --nocache `
  --installPath C:\BuildTools `
  --config .\nushell-windows.vsconfig
```

Exit code `3010` means success-but-reboot-required and should be treated as
success. Avoid spaces in `--installPath`; a known parsing bug lands the
install in `C:\Program`.

## What nushell actually needs from it

| Requirement | Present | Notes |
|---|---|---|
| MSVC `cl.exe` / `link.exe` / `lib.exe` / `ml64.exe` | yes | toolset **14.44.35207** |
| Windows SDK | yes | 10.0.10240, 17763, 19041, 22621, **26100**, wdf |
| Static CRT (`libcmt.lib`, `libvcruntime.lib`, `libucrt.lib`) | yes | required — `.cargo/config.toml` sets `+crt-static` |
| CMake | yes | `C:\Program Files\CMake` |
| Ninja | yes | via Chocolatey |
| LLVM / libclang | yes | `C:\Program Files\LLVM` — needed by `bindgen`, `clang-sys` |
| Perl, Go, Python, Node, Git | yes | |
| rustup / cargo / rustc | yes | preinstalled, msvc host |
| **NASM** | **no** | the only gap — set `AWS_LC_SYS_PREBUILT_NASM=1` so `aws-lc-sys` uses its shipped prebuilt objects |

## Version note

This image is **VS 2022 / MSVC 14.44.35207**. GitHub's `windows-latest` has
already moved to **VS 18 / MSVC 14.51.36231**, so the two are diverging.
Namespace's Windows image cannot be customised — both
`nsc github profile create --os windows-2022` and
`nsc base-image build-github-image -p windows/amd64` are rejected — so the
version cannot be pinned forward from our side. This `.vsconfig` is therefore
the record of what we actually built against.

## Re-capturing

```bash
nsc create --machine_type windows/amd64:4x8 --duration 2h
nsc ssh <instance-id> -T "cmd /c ver"
# then run .github/windows-image/capture.ps1 on the box
```

`nsc instance download` does not work against Windows instances
(`remote read failed`); base64 the file over `nsc ssh` instead.
