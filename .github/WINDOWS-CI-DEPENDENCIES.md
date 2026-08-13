# Windows CI dependencies

What a nushell Windows build (`x86_64-pc-windows-msvc`) needs from the machine
it runs on, and how the runners we care about compare.

Generated 2026-08-13 from `cargo tree --target x86_64-pc-windows-msvc
--edges normal,build --workspace` at commit `4648a23b7`, plus the
`DEPS:` steps in `.github/workflows/nsc-windows-ci-flow.yml`.

Re-generate the crate side with:

```bash
cargo tree --target x86_64-pc-windows-msvc --edges normal,build \
  --prefix none --workspace | sed 's/ (\*)$//' | awk 'NF' | sort -u
```

## Scale

| | Count |
|---|---|
| Unique crate names in the Windows graph | 752 |
| Unique `crate@version` entries | 831 |
| Crates that compile C/C++/assembly at build time | 15 |

## What the machine must provide

`rustup target add x86_64-pc-windows-msvc` is a no-op on an x64 Windows host —
host triple already equals target triple — and it never ships a linker, a C
compiler, the CRT, or the SDK. All of that has to already exist on the machine.

| Requirement | Needed by | Fails as |
|---|---|---|
| MSVC `cl.exe` | every `cc`-driven crate below | `error occurred: could not find cl.exe` |
| MSVC `link.exe` | all linking | `linker 'link.exe' not found` |
| `ml64.exe` | `ring`, `aws-lc-sys` assembly | assembler not found |
| `rc.exe` (Windows SDK) | resource compilation | `rc.exe` not found |
| Windows SDK import libs | `kernel32`, `advapi32`, `bcrypt`, `ntdll`, `crypt32`, … | `LNK1104: cannot open file` |
| **Static CRT** — `libcmt.lib`, `libvcruntime.lib`, `libucrt.lib` | `.cargo/config.toml` sets `+crt-static` | `LNK1104: cannot open file 'libcmt.lib'` |
| CMake | `aws-lc-sys`, `cmake` crate | `cmake` not found |
| `libclang.dll` | `bindgen`, `clang-sys` | `Unable to find libclang` |

> `+crt-static` is the sharp edge. A VS install with only the dynamic CRT will
> build and link a hello-world perfectly, then fail on this workspace. Check
> for `libcmt.lib` specifically, not just for `cl.exe`.

## Crates that compile native code

These carry build scripts that invoke a C compiler, an assembler, CMake, or
libclang. They are the reason the toolchain above is mandatory.

| Crate | Version | Needs |
|---|---|---|
| `aws-lc-sys` | 0.39.0 | cc + CMake + assembler (`AWS_LC_SYS_PREBUILT_NASM=1` avoids a NASM dependency) |
| `ring` | 0.17.14 | cc + assembler |
| `bindgen` | 0.72.1 | libclang |
| `clang-sys` | 1.8.1 | libclang |
| `cc` | 1.2.56 | the C compiler driver itself |
| `cmake` | 0.1.57 | CMake |
| `libgit2-sys` | 0.18.7+1.9.6 | cc (vendored libgit2) |
| `libsqlite3-sys` | 0.38.1 | cc (vendored SQLite) |
| `libz-sys` | 1.1.25 | cc (vendored zlib) |
| `lz4-sys` | 1.11.1+lz4-1.10.0 | cc |
| `zstd-sys` | 2.0.16+zstd.1.5.7 | cc |
| `curl-sys` | 0.4.85+curl-8.18.0 | cc |
| `lmdb-master-sys` | 0.2.6 | cc |
| `psm` | 0.1.30 | cc + assembly |
| `nix` | 0.31.3 | platform bindings |

`windows-sys` appears at four versions (0.48.0, 0.59.0, 0.60.2, 0.61.2) and
`winapi` at 0.3.9; these are binding crates and need no C toolchain.

## Runner comparison

Both runners satisfy every requirement above. The difference is the toolset
version, and it is widening.

| | GitHub `windows-latest` | Namespace `nscloud-windows-2022` |
|---|---|---|
| Visual Studio | **18** Enterprise | **2022** Enterprise |
| MSVC toolset | **14.51.36231** | **14.44.35207** |
| Windows SDK | 10.0.26100.0 | 10.0.26100.0 |
| Static CRT | present | present |
| LLVM / libclang | `C:\Program Files\LLVM\bin` | `C:\Program Files\LLVM\bin` |
| CMake / Ninja / vcpkg | present | present |
| Git / PowerShell 7 | present | present |
| rustup + cargo | present | preinstalled, msvc host |
| Workspace drive | `D:\a\<repo>\<repo>` | same |
| Cache volume | — | `K:\cache` via `NSC_CACHE_PATH` |

Namespace's Windows image cannot be customised — `nsc github profile create
--os windows-2022` and `nsc base-image build-github-image -p windows/amd64`
are both rejected — so its MSVC version cannot be pinned or advanced.

> Do not read capability from `nsc github base-image describe windows-2022`.
> It reports 7 packages and no Visual Studio. It is a curated highlight list,
> demonstrably incomplete: Git and the actual runner version are both absent
> from it while plainly present on the machine.

## Shell

The `cargo test` step in `ci.yml` is a bash conditional. GitHub Actions
defaults to **pwsh** on Windows, which cannot parse it:

```
ParserError: Missing '(' after 'if' in if statement.
```

Any step whose body is bash must set `shell: bash`. Git bash ships on both
runners at `C:\Program Files\Git\bin\bash.exe`.
