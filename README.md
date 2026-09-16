# 大学生自己的国产 Codex

**Build your personal AI Agent system on Windows.**

把一个 ChatGPT Desktop 客户端跑成两个互不干扰的 AI：一个负责想和判，一个负责做和反馈。两个环境之间没有共享上下文，磁盘上的文件是唯一接口。

```
            你
             │
      GPT Planner ──────→  tasks/PLAN.md
             │                     │
             │        DeepSeek Executor ──→ 代码 / 文件 / 测试
             │                     │
             │             tasks/RESULT.md
             │                     │
      GPT Reviewer ─────→  tasks/REVIEW.md ──→ 下一轮
```

## 这是什么

ChatGPT Desktop（微软商店的 MSIX 包 `OpenAI.Codex`）把配置、会话、插件、浏览器数据都放在 `%USERPROFILE%\.codex` 里。这个仓库做的事是：**让同一个 `ChatGPT.exe` 跑出第二个实例**，把它的家目录换掉、浏览器数据换掉、模型供应商换成 DeepSeek，再让 Windows 任务栏把它显示成一个独立程序。

结果：桌面上同时开着两个互不干扰的 AI。官方实例的账号、模型、会话原封不动；DeepSeek 实例有自己的目录和配置，能读写文件、跑命令、跑测试。

## 为什么做这个

现在大多数人的 AI 用法还是：

```
人 → AI → 答案
```

聊得越多越会发现，一次性问答解决不了长期项目：上下文会丢，状态没有地方放，计划和执行混在一段对话里。这个项目把它变成：

```
人 → AI 规划 → AI 执行 → AI 审查 → 人决策
```

要做到这一点，第一步不是写框架，是**先让两个 AI 真的互相独立**——所以这个仓库一半是环境隔离，一半是协作协议。

## 特性

| | 说明 |
| --- | --- |
| 环境隔离 | 两个 `CODEX_HOME`，配置、会话、技能、插件完全分开 |
| 数据隔离 | 浏览器数据、缓存、登录态各自独立，不会互相污染 |
| 桌面身份分离 | 用 `AppUserModelID` 让 Windows 认为这是两个程序，任务栏出现两个图标 |
| DeepSeek 接入 | 走 DeepSeek 官方 `responses` 接口，API Key 模式，不占用 ChatGPT 账号 |
| 协作协议 | PLAN / RESULT / REVIEW 三个文件 + 只读状态机脚本，带自测 |
| 踩坑记录 | 沙箱 ACL、PowerShell BOM、配置热更新等问题的根因与修法都写下来了 |

## 目录

```
domestic-codex/
├── README.md                       本文件
├── launcher/                       启动器（实测可用，未修改）
│   ├── Start-DeepSeek-Codex.ps1    启动 + 任务栏身份分离（内嵌 C#）
│   ├── Stop-DeepSeek-Codex.ps1     按进程树干净退出
│   └── DeepSeek-Codex.ps1          CLI 入口
├── config/
│   └── config.deepseek.template.toml   脱敏后的配置模板
├── docs/
│   ├── STORY.md                    为什么做这个项目
│   ├── LEARNING.md                 从零到一的开发总结
│   ├── 实现细节.md                 双环境原理、六个配置点、已知坑
│   └── 复现步骤.md                 从零到跑通的七步
└── agent-system/                   双智能体协作协议
    ├── README.md                   协议全文（角色、三个文件、状态机）
    ├── agents/                     三张角色卡，可直接贴给对应 AI
    ├── scripts/                    状态检查器 + 自测 + 两个环境体检脚本
    └── tasks/                      三个文件的空白模板
```

## 安装

**目前没有一键安装器。** 仓库里是三个实测跑通的启动脚本、一份配置模板和一套协议，部署需要手动做，大约十分钟。完整步骤见 `docs/复现步骤.md`，要点如下。

前置条件：

- Windows 10/11
- 已安装 ChatGPT Desktop（MSIX 包 `OpenAI.Codex`），并用官方账号正常跑过一次
- 一个 DeepSeek API Key

三步：

1. 把 `%USERPROFILE%\.codex` 复制成 `%USERPROFILE%\.codex-deepseek`。
2. 用 `config/config.deepseek.template.toml` 覆盖其中的 `config.toml`，填入自己的 API Key 与用户名路径，再把你自己造的 `models.json` 放进去。
3. 把 `launcher/` 下三个脚本放到 `%USERPROFILE%`，建两个桌面快捷方式指向它们，双击「DeepSeek Codex」。

> 没有 `install.ps1`。写一个能自动完成上面三步的安装器，是这个项目的下一个目标，不是现状。

## 项目状态

版本 `v0.1`。

**已实现，且在本机真实运行过**：环境隔离、数据隔离、桌面身份分离、DeepSeek 接入、启动/关闭/CLI 三个入口、协作协议与状态机自测。

**没做**：一键安装器、卸载脚本、自动任务调度、长期记忆、多 Agent 并行。协作协议目前靠人搬运文件推进，这是刻意的——先验证协议，再谈自动化。

## 三个必须知道的关键点

- `model_catalog_json` 必须指向你自己的模型目录文件。**没有它，模型下拉框里不会出现 DeepSeek。**
- 改完 `config.toml` 必须**完全退出**应用（含托盘图标）再启动，否则读的还是旧配置。
- 沙箱建议用 `sandbox = "unelevated"`。用 `elevated` 时本机出现过每条命令都失败的情况，根因是沙箱目录的 ACL 拿不到 `WRITE_DAC`，详见 `docs/实现细节.md`。

## 这个仓库里没有什么，以及为什么

| 缺的东西 | 原因 |
| --- | --- |
| `models.json` 原文 | 这个文件里包含从官方客户端复制的**系统提示词原文**，不属于我，不便公开分发。仓库给出字段结构与生成思路，你自己造一份（见 `docs/实现细节.md` 第 3 节） |
| API Key | 模板里是 `<YOUR_DEEPSEEK_API_KEY>` 占位符 |
| 聊天记录、`.codex` 数据目录 | 个人数据，与项目无关 |
| 原始安装脚本 | 当初那版脚本已经丢失，只剩下它写下的 manifest。本仓库是按现存文件反推整理的 |
| 一键安装器 | 还没写。仓库里是能用的零件，不是装好的成品 |

## 三份文档

同一个项目，面对三种读者，刻意分开写：

| 文档 | 读者 | 内容 |
| --- | --- | --- |
| 本文件 | 开发者、使用者 | 这是什么、怎么装、怎么用 |
| `docs/STORY.md` | 普通读者、未来的自己 | 为什么做、踩了什么坑、这个项目意味着什么 |
| `docs/LEARNING.md` | 自己 | 从零到一学到了什么 |

## 许可

MIT，见 [LICENSE](LICENSE)。`launcher/` 下的脚本、配置模板和文档都可以自由使用、修改、再发布，保留版权声明即可。

仓库里不含第三方代码或素材（`models.json` 因为是官方的系统提示词原文，本来就没有收录），所以这个许可是干净的。

## 更新记录

| 日期 | 内容 |
| --- | --- |
| 2026-09-17 | 首次发布：launcher、配置模板、实现细节、复现步骤、双智能体协作协议 |
| 2026-09-17 | 加 MIT 许可 |