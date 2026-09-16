# 双智能体协作协议

v0.1 · 2026-09-17 · 仓库内位置：`agent-system/`

本文件是这套系统的宪法。以后每接一个新模型、新工具、新 Agent，先改这里再改脚本；README 里没写的机制不算机制。

---

## 1. 这套系统要解决什么

两个 AI 各自在跑，但它们互不相见。GPT 侧和 DeepSeek 侧没有共享上下文，**唯一的通道是磁盘上的文件**。所以这里真正的工作不是"让 AI 更聪明"，而是定一份两个 AI 都能遵守的文件协议，让人类用最小的搬运成本把一件事从计划推到验收。

一句话定义：**GPT 负责想和判，DeepSeek 负责做和反馈，人负责调度与授权。**

v0.1 只验证三件事：

1. GPT 能稳定产出可执行的计划；
2. DeepSeek 能按计划执行，并如实报告（包括没做成、没验证的地方）；
3. GPT 能拿着计划 + 结果做出一致判断。

承载这三件事的是三个文件：`tasks/PLAN.md`、`tasks/RESULT.md`、`tasks/REVIEW.md`。

## 2. v0.1 明确不做的事

- **不调用 API，不做自动循环。** GPT 侧是 Plus 订阅，没有可编程接口；硬做自动化的成本高于收益。当前要验证的是协议，不是调度器。
- 不做多 Agent 框架，不做向量库，不做 RAG。
- 不做并行。同一时刻只有一个 Builder 在改文件。
- 不让 AI 自己决定下一步该谁干活。每一次推进都由人发起。
- 不把"流程跑通"本身当成果。流程是容器，真正的工作内容（代码、文档）才是产出。

## 3. 双环境架构（现状记录）

两个环境是同一个桌面应用 `ChatGPT.exe`（MSIX 包 `OpenAI.Codex`）的两个实例，靠启动参数区分。

| 项目 | GPT 环境 | DeepSeek 环境 |
| --- | --- | --- |
| 角色 | Planner / Reviewer | Builder |
| 入口 | 官方默认实例（开始菜单 / 任务栏） | 桌面快捷方式「DeepSeek Codex」 |
| 启动脚本 | `scripts/start-gpt.ps1`（体检、可选启动） | `scripts/start-deepseek.ps1`（转发到 `%USERPROFILE%\Start-DeepSeek-Codex.ps1`） |
| `CODEX_HOME` | `%USERPROFILE%\.codex` | `%USERPROFILE%\.codex-deepseek` |
| 浏览器数据 | `%APPDATA%\Codex\web\Codex` | `%LOCALAPPDATA%\CodexProfiles\deepseek\web-data` |
| 模型 | 官方 ChatGPT / Codex 模型（Plus 订阅） | `deepseek-flash`，provider `deepseek`（`https://api.deepseek.com/`），API key 模式 |
| 联网搜索 | 可用 | `web_search = "disabled"` |
| 任务栏身份 | 默认 | `Andy.DeepSeekCodex`，标题「DeepSeek Codex」 |
| 能否被脚本调用 | 不能（无 API key） | 不能（没有人操作就不会动） |
| 能否读写本机文件、跑命令 | 不作为执行者 | 能 |

进程识别方法：命令行里带 `CodexProfiles\deepseek\web-data` 的 `ChatGPT.exe` 属于 DeepSeek 实例，不带的是 GPT 实例。两个环境可以同时运行。

两条必须记住的推论：

1. **两个环境的聊天记录互不可见。** 让 GPT 审核时，必须把 `PLAN.md` 与 `RESULT.md` 的正文一起贴过去，它看不到 DeepSeek 那一侧的对话。
2. **文件是唯一接口。** 任何"口头说好"的机制，只要没写进本目录的文件，下一个 Agent 就不知道。

长期记忆也只能靠文件：跨任务的结论写进一个 `WORK_MEMORY.md`，单个任务的内容写进 `tasks\`。**不要指望 AI 记得上一轮**——不只两个环境的会话互不可见，同一个环境里不同模块的会话也互不可见。

## 4. 三个角色

### Planner（GPT）

- 输入：人用自然语言给出的目标与背景。
- 输出：`tasks/PLAN.md`。
- 可以做：把模糊目标拆成有顺序、可执行的动作；写清约束与验收标准；信息不足时直接把问题列出来问人。
- 不做：不写最终代码；不假设自己能看到执行现场。

### Builder（DeepSeek）

- 输入：`tasks/PLAN.md`（只读）。
- 输出：`tasks/RESULT.md` 与实际文件改动。
- 可以做：按计划执行；发现计划过时或不可行时停下来报告。
- 不做：**不改 `PLAN.md`**；不扩大范围；不美化结果——失败、跳过、没验证的部分都要写进 `Problems`。

### Reviewer（GPT）

- 输入：`PLAN.md` 与 `RESULT.md` 两份正文（缺一不可）。
- 输出：`tasks/REVIEW.md`。
- 可以做：按 Done Criteria 逐条判定；指出计划本身的缺陷。
- 不做：不直接改代码；不写 `RESULT.md`；不给"总体不错"这类无法执行的结论。

人在这个系统里不是传话筒：喂什么、什么时候允许动文件、要不要继续，都由人决定。

## 5. 协议

### 5.1 文件头

三个文件都以同一段 front matter 开头，字段固定，供 `orchestrator.ps1` 解析：

```
---
task: 001-file-organizer
stage: PLAN          # PLAN | BUILD | REVIEW | DONE
author: gpt-planner  # gpt-planner | deepseek-builder | gpt-reviewer
date: 2026-09-17
status: empty        # empty | ready | draft | revise | accepted
---
```

`status: empty` 的意思是"还没人填"。谁真正开始写，就把 status 改成对应的值。`orchestrator.ps1` 靠这个字段判断阶段，所以不要留着 `empty` 去写正文，也不要写完忘了改 status。

### 5.2 `tasks/PLAN.md`

```
# Task Plan

## Goal

## Background
- 项目位置：
- 当前状态：
- 相关历史：

## Required Actions
1.

## Constraints

## Expected Result

## Done Criteria
- [ ]
```

写法要求：

- `Goal` 一句话，说清做完之后世界上多了什么。
- `Required Actions` 有顺序、一步一件事。不要写"调研一下"这类没有终点的动作。
- `Constraints` 写死不许碰的文件、不许引入的依赖。
- `Done Criteria` 每条都要能判真假。宁可少写，也不要写"代码质量良好"。

`Done Criteria` 是三个文件互相咬合的钩子：Planner 写，Builder 逐条自答，Reviewer 逐条核。

### 5.3 `tasks/RESULT.md`

```
# Execution Result

## Completed

## Files Changed

## Problems

## Need Review

## Done Criteria Check
| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
```

`Result` 一列只允许 `PASS` / `FAIL` / `SKIP`，`SKIP` 必须写原因。不允许"基本完成"。`Evidence` 写命令与输出摘要，或文件路径。

### 5.4 `tasks/REVIEW.md`

```
# Review

Status: ACCEPT | REVISE

## Criteria Verification

## Problems

## Next Action
```

- `ACCEPT` 的前提是 Done Criteria 全部 PASS，任务结束。
- `REVISE` 时 `Next Action` 必须写成能直接当作下一份 `PLAN.md` 的 `Required Actions` 的指令：改哪个文件、改成什么样、怎么验证。禁止"再优化一下"。

### 5.5 生命周期：谁在什么时候写哪个文件

| 时刻 | 谁 | 动作 | 文件 |
| --- | --- | --- | --- |
| 开始 | 人 | 把目标与背景给 GPT，说明这是 Planner 角色 | — |
| 计划完成 | GPT Planner | 输出 PLAN 全文，人粘贴进 `tasks/PLAN.md`，status 改 `ready` | PLAN |
| 执行 | 人 | 在 DeepSeek 里说：读 `tasks/PLAN.md`，按它执行，结果写进 `tasks/RESULT.md` | — |
| 执行完成 | DeepSeek Builder | 写 RESULT，status 改 `draft` | RESULT |
| 审核 | 人 | 把 PLAN + RESULT 两份正文一起贴给 GPT，说明这是 Reviewer 角色 | — |
| 审核完成 | GPT Reviewer | 输出 REVIEW，人粘贴进 `tasks/REVIEW.md`，status 改 `accepted` 或 `revise` | REVIEW |
| 若 REVISE | 人 | 把 `Next Action` 变成下一轮 PLAN 的 Required Actions，覆盖 `tasks/PLAN.md` | PLAN |
| 结束 | 人 | 三个文件移到 `tasks/done/<task-id>/`，`current_task.md` 追加一行 | — |

### 5.6 状态怎么前进

`orchestrator.ps1` 的全部逻辑就是这张表：

```
PLAN.status = empty      → 等 GPT Planner 写计划
PLAN.status 已填          → 等 DeepSeek Builder 执行
RESULT.status 已填        → 等 GPT Reviewer 审核
REVIEW.status = revise   → 回到 Builder，从新一轮 PLAN 开始
REVIEW.status = accepted → 任务结束，归档
```

## 6. 目录结构

```
agent-system/
├── README.md               本文件（协议全文）
├── agents/                 角色卡，可以直接把整段贴进对应 AI 的对话
│   ├── planner/
│   ├── builder/
│   └── reviewer/
├── scripts/
│   ├── orchestrator.ps1    只读状态检查：现在该谁干活
│   ├── start-gpt.ps1       GPT 环境体检 / 启动
│   ├── start-deepseek.ps1  DeepSeek 环境体检 / 启动
│   └── tests/
│       └── orchestrator.selftest.ps1   状态机自测（改协议后跑一遍）
└── tasks/                  三个文件的空白模板，复制出来填
    ├── PLAN.md
    ├── RESULT.md
    └── REVIEW.md
```

脚本用 `pwsh -NoProfile -File <路径>` 运行；默认只预览不启动，要启动加 `-Run`。脚本文件必须存成**带 UTF-8 BOM**，否则 Windows PowerShell 5.1 会按 ANSI 解析，中文会把语法撑坏。

环境本身怎么搭（`CODEX_HOME`、模型目录、任务栏身份、沙箱坑）见仓库根目录的 `docs/`。

## 7. 阶段路线

**v0.1（现在）：人工调度。** 脚本只做环境体检与状态检查，搬运全靠人。目标是三个文件跑通至少一轮真任务。

**v0.2：半自动。** `orchestrator.ps1` 从只读检查升级为能启动环境、能写状态，人只需确认。

**v0.3：状态机。** 引入 `STATE.json`（`task` / `stage` / `agent`），由脚本生成与维护，人只处理异常。

进入下一阶段的判断标准：**当前阶段跑满 5 个任务，且中途不需要临时解释规则。**

## 8. 第一个真实任务

任务 001：一个 Python 文件整理工具，工程放在 `D:\codex-test\AI-Agent-Test`。

选它的原因：小到能在一次对话里做完，又完整到有输入、有输出、有边界情况，足以暴露协议的问题。不拿小游戏或玩具脚本测试，那种任务会掩盖协议本身的缺陷。

通过标准：

- `PLAN.md` 的 Done Criteria 全部可判定；
- Builder 只按 PLAN 执行，没有额外承诺；
- Reviewer 的判决能直接指向下一步；
- 全程没有出现"只有 DeepSeek 知道、GPT 不知道"的信息。

## 9. 铁律

1. 一个任务同时只有一个 Builder。同一批文件不要两个执行者同时改。
2. Builder 不改 `PLAN.md`，Reviewer 不写代码，Planner 不替人决定要不要执行。
3. 没写进文件的结论等于没发生。对话里说定的改动，必须落进 `PLAN.md` 或 `RESULT.md`。
4. 未验证的东西必须标出来。"没跑""跳过了""只在脑子里通过对"都要写进 `Problems`。
5. 路径、命令、数字写具体。不写"某处""适当调整"。
6. 计划或结果里出现的新机制、新数值，必须让人知情。
7. 破坏性操作（删除、覆盖、批量重命名）只走"默认预览、确认后执行"的脚本，不在对话里直接动手。
8. 输出中文；数学公式用 `\[ ... \]`（单个 `$` 在客户端渲染不出来）；不写过渡性的"AI 味"句子，不用不确定措辞。

## 10. 变更记录

| 日期 | 版本 | 变更 |
| --- | --- | --- |
| 2026-09-17 | v0.1 | 建立目录、宪法、三个文件的协议、角色卡与脚本 |
