---
name: apk-reverse
description: Install, verify, and use portable APK reverse-engineering/unpacking tools. Use when working with Android APK files, APK static analysis, jadx/apktool setup, decompiling DEX, decoding AndroidManifest/resources, inspecting React Native or Hermes bundles, extracting strings, or preparing APK-derived API/interface analysis for MCP work.
---

# APK Reverse

Use this skill to prepare a workspace-local APK analysis toolchain and run a first-pass static inspection without requiring system-wide installs.

## Workflow

1. Locate APK files with `Get-ChildItem -Recurse -Filter *.apk`.
2. Check tools:
   - Prefer workspace-local wrappers in `_tools/bin`: `java.cmd`, `jadx.cmd`, `jadx-gui.cmd`, `apktool.cmd`.
   - Also check PATH tools with `Get-Command java, jadx, apktool, unzip, tar, curl.exe`.
3. If Java/jadx/apktool are missing, run `scripts/install_apk_tools.ps1` from this skill. It installs portable Temurin JRE, jadx, and apktool into the target workspace `_tools`.
4. Verify:
   - `_tools\bin\java.cmd -version`
   - `_tools\bin\jadx.cmd --version`
   - `_tools\bin\apktool.cmd --version`
5. Triage the APK before deep decompilation:
   - `Get-FileHash <apk> -Algorithm SHA256`
   - `unzip -l <apk>` or `tar.exe -tf <apk>`
   - Look for `classes*.dex`, `AndroidManifest.xml`, `resources.arsc`, `assets/index.android.bundle`, `assets/*.hbc`, `assets/*.bundle`, `lib/*/*.so`, `res/xml/network_security_config*`.
6. Decode/decompile:
   - `apktool d -f <apk> -o <out>\apktool`
   - `jadx -d <out>\jadx <apk>`
7. Search for network/API clues:
   - `rg -n "https?://|grpc|retrofit|okhttp|Authorization|Bearer|token|session|api|oauth|jaccount|treehole|model.TreeHole|GetLatestThreads|PutThread|PutPost" <out>`
   - For React Native APKs, inspect `assets/index.android.bundle` first.
   - For Hermes bundles, look for `.hbc` files and visible strings before deciding whether Hermes-specific tooling is needed.

## Scripts

Run the installer from any workspace:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\dajiaohuang\.codex\skills\apk-reverse\scripts\install_apk_tools.ps1 -Workspace D:\repo\ykst_mcp
```

Useful parameters:

- `-Workspace <path>`: install into `<path>\_tools`; defaults to the current directory.
- `-Force`: redownload and replace existing portable tools.
- `-NoJadx`, `-NoApktool`, `-NoJre`: skip a component when it already exists elsewhere.

## Safety

- Keep installation workspace-local unless the user explicitly asks for system-wide installation.
- Do not log tokens, cookies, keystores, private keys, OAuth codes, or session values found in APKs.
- Do not bypass certificate pinning, authentication, rate limits, or device integrity checks. Static analysis is fine; dynamic interception needs explicit user authorization and should stay within accounts/systems the user owns or is allowed to test.
- Treat write-capable API methods found in APKs as high-risk. Document them first; gate any MCP write tool behind explicit configuration and confirmation.

## Output Expectations

When asked to analyze an APK for MCP work, produce or update a concise document with:

- APK identity: filename, size, SHA256, package name if decoded.
- Stack: native Android, React Native, Flutter, Expo, Hermes, gRPC, REST, etc.
- Discovered endpoints and hosts.
- Auth/session storage and request metadata.
- Data models/protobuf/JSON schemas when recoverable.
- Candidate MCP tools split into read-only and mutation groups.
- Unknowns and next verification steps.
