# Workflow: /agentslink

## Goal
Consolidate agent-specific instruction files into a single `AGENTS.md`, then symlink all known agent filenames to it. One file to maintain, all agents stay in sync.

## 已知 Agent 文件
Recognized agent filenames:
- `CLAUDE.md` — Claude Code
- `GEMINI.md` — Gemini CLI
- `CODEX.md` — OpenAI Codex CLI
- `CURSOR.md` — Cursor IDE
- `.cursorrules` — Cursor IDE (legacy)
- `.windsurfrules` — Windsurf IDE

## Steps

### Mode 1: Project-level (default, 当前项目目录)

1. **检测已有文件**：
   - 扫描当前目录下列出的已知文件名
   - 区分真实文件（非软链接）和已有软链接
   - 如果没有任何真实文件且 `AGENTS.md` 不存在 → 提示用户"没有内容可合并"，退出

2. **收集内容**：
   - 如果 `AGENTS.md` 已存在且为真实文件（非软链接），保留其内容作为基础
   - 逐个读取所有真实存在的已知文件，追加到 `AGENTS.md`
   - 每个迁移的文件内容前加分隔标记：`# === Migrated from {filename} ===`

3. **写入 AGENTS.md**：
   - 将所有收集的内容写入 `AGENTS.md`
   - 如果之前 `AGENTS.md` 是软链接，先移除再写入

4. **创建软链接**：
   - 移除所有已知文件名的真实文件（内容已迁移到 AGENTS.md）
   - 为每个已知文件名创建指向 `AGENTS.md` 的软链接
   - 如果某个文件名不存在且也不是软链接，同样创建软链接（确保覆盖面）

5. **确保 CLAUDE.md 存在**：
   - 如果 `CLAUDE.md` 不存在，创建指向 `AGENTS.md` 的软链接

6. **报告**：
   - 列出哪些文件被迁移（真实文件 → 内容合并）
   - 列出哪些文件是新创建的软链接
   - 提醒用户：之后只需编辑 `AGENTS.md`，所有软链接自动同步

### Mode 2: Global-level (`--global`)

1. 以上所有操作在 `~/.claude/` 目录下执行
2. 用于统一管理用户级别的全局 agent 指令

### Mode 3: Dry-run (`--dry-run`)

1. 只分析，不修改任何文件
2. 展示将要执行的操作：哪些文件会被迁移、哪些软链接会被创建
3. 展示合并后 `AGENTS.md` 的前 20 行预览

## Hard Constraints
- **绝不删除用户数据。** 所有真实文件的内容先合并到 `AGENTS.md`，再创建软链接。
- **软链接目标用相对路径或文件名**（`AGENTS.md`），不用绝对路径，确保目录移动后不失效。
- **如果 AGENTS.md 已是软链接，先移除再创建真实文件。** 防止递归软链接。
- **检测递归软链接。** 如果某个文件名已是 `AGENTS.md` 的软链接，跳过。
- **幂等。** 重复运行不会产生副作用（已软链接的文件不会重复迁移）。

## Acceptance Criteria
- [ ] 所有已知 agent 文件（存在的）都被软链接指向 `AGENTS.md`
- [ ] 所有原始文件内容都合并到 `AGENTS.md`
- [ ] `CLAUDE.md` 始终存在（至少是软链接）
- [ ] 无递归软链接
- [ ] 重复运行无副作用
