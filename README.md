# APK Reverse

一个用于 **APK 逆向静态分析** 的 Codex Skill：

- 自动安装并验证本地可移植工具链（JRE / jadx / apktool）
- 对 APK 做首轮解包与结构化排查
- 面向后续 MCP 能力设计输出可复用分析结论

## 命名

- Skill 名称：`apk-reverse`
- GitHub 仓库名（按 skills 命名范式建议）：`skill-apk-reverse`。

## 包含内容

- `SKILL.md`：Skill 说明、工作流、安全边界、输出规范
- `scripts/install_apk_tools.ps1`：一键安装可移植 APK 逆向工具
- `agents/openai.yaml`：Agent 界面显示名与默认提示词

## 快速使用

1. 在 Codex 中调用该 skill（`$apk-reverse`）。
2. 若本地缺少工具，执行安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_apk_tools.ps1 -Workspace .
```

3. 验证工具：

```powershell
_tools\bin\java.cmd -version
_tools\bin\jadx.cmd --version
_tools\bin\apktool.cmd --version
```

4. 分析 APK：

```powershell
apktool d -f app.apk -o out\apktool
jadx -d out\jadx app.apk
```

## 适用场景

- Android APK 静态分析
- 清点接口域名、认证字段、请求模型
- 为 MCP 读写工具设计准备证据

## 注意事项

- 默认仅做静态分析，不涉及绕过安全机制。
- 禁止泄露 token、cookie、密钥等敏感信息。
