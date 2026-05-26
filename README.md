# APK Reverse

English | [简体中文](./README_CN.md)

A Codex skill for **APK reverse static analysis**:

- Installs and verifies a portable local toolchain (JRE / jadx / apktool)
- Runs first-pass APK unpacking and structured inspection
- Produces reusable analysis outputs for downstream MCP capability design

## Naming

- Skill name: `apk-reverse`
- GitHub repository name (recommended skill naming convention): `skill-apk-reverse`

## What's Included

- `SKILL.md`: Skill instructions, workflow, safety boundaries, and output format
- `scripts/install_apk_tools.ps1`: One-command installer for portable APK reverse tools
- `agents/openai.yaml`: Agent UI display name and default prompt

## Quick Start

1. Invoke this skill in Codex (`$apk-reverse`).
2. If required tools are missing locally, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_apk_tools.ps1 -Workspace .
```

3. Verify tools:

```powershell
_tools\bin\java.cmd -version
_tools\bin\jadx.cmd --version
_tools\bin\apktool.cmd --version
```

4. Analyze an APK:

```powershell
apktool d -f app.apk -o out\apktool
jadx -d out\jadx app.apk
```

## Use Cases

- Android APK static analysis
- Enumerating API domains, auth fields, and request models
- Collecting evidence for MCP read/write tool design

## Notes

- Default scope is static analysis only; no security bypass techniques.
- Never expose sensitive data such as tokens, cookies, or keys.
