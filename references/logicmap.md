# Workflow: /logicmap

## Goal
为当前项目生成业务逻辑地图（Logic Map），遵循两层文档结构：根索引 + 模块索引页 + 二级文档。输出到 `docs/LOGIC_MAP.md` 和 `docs/logic-map/`。

## 前置条件
- 项目根目录存在，且能识别项目类型（package.json / pyproject.toml / go.mod 等）
- 如果 `docs/logic-map/` 已存在，询问用户是覆盖还是只更新变化的部分

## Steps

### Phase 1: 项目结构分析

1. **识别项目类型和框架**：
   - 读 `package.json`（或等效文件），确定语言、框架、关键依赖
   - 识别路由结构（Next.js App Router / Pages Router / React Router / Vue Router / Express / FastAPI / 等）
   - 识别认证方案（Better Auth / NextAuth / Auth0 / Clerk / JWT / 等）
   - 识别支付方案（Stripe / Creem / LemonSqueezy / 等）
   - 识别数据库（PostgreSQL / MySQL / MongoDB / SQLite / 等）
   - 识别内容系统（Fumadocs / Contentlayer / MDX / CMS / 等）
   - 识别外部服务（Mail / Storage / Notification / AI / 等）

2. **扫描目录结构**：
   - 扫描 `src/app/`、`src/pages/`、`src/routes/` 或等效路由目录
   - 扫描 `src/actions/`、`src/api/` 或等效服务端入口
   - 扫描 `src/lib/`、`src/services/`、`src/providers/` 等核心模块
   - 扫描 `src/config/`、环境变量文件等配置入口
   - 扫描 `src/db/`、`src/models/` 等数据层

3. **绘制模块归属**：
   - 把每个路由、API、Action 归属到 A-F 模块之一（或标记为需要新模块）
   - A: 全局骨架（路由、布局、Provider、配置）
   - B: 公共页面（首页、营销、定价、About、法务）
   - C: 认证账户（登录、注册、OAuth、邮箱验证、密码重置）
   - D: 工作台（Dashboard、Settings、Admin、用户后台）
   - E: 商业闭环（支付、订阅、积分、webhook、账单）
   - F: 内容与接口集成（Blog、Docs、Storage、Mail、Notification、Cron）

### Phase 2: 生成文档

4. **创建目录结构**：
   ```
   docs/logic-map/
   ├── README.md
   ├── NUMBERING.md
   └── templates/
       ├── MODULE_TEMPLATE.md
       └── SECOND_LEVEL_TEMPLATE.md
   ```

5. **生成 `docs/logic-map/README.md`**：
   - 使用 `templates/logic-map/README.md` 为模板
   - 如项目有特殊约定，微调说明文字

6. **生成 `docs/logic-map/NUMBERING.md`**：
   - 使用 `templates/logic-map/NUMBERING.md` 为模板
   - 确保顶层模块表反映实际项目模块

7. **复制模板到项目中**：
   - 将 `MODULE_TEMPLATE.md` 和 `SECOND_LEVEL_TEMPLATE.md` 复制到 `docs/logic-map/templates/`

8. **为每个识别的模块生成模块索引页**（如 `A-global-routing.md`）：
   - 使用 `MODULE_TEMPLATE.md` 模板
   - X0: 写清楚该模块的业务目的、用户入口、关键文件
   - X1-Xn: 划分编号段，每个二级文档一个段
   - 表底附迁移记录（首次生成时记录"初始创建"）

9. **为每个编号段生成二级文档**（如 `A-global-routing/routing-i18n.md`）：
   - 使用 `SECOND_LEVEL_TEMPLATE.md` 模板
   - Xn.0: 目标说明
   - Xn.1: 路由和 API 入口表
   - Xn.2: 用户动作与服务端入口（调用顺序）
   - Xn.3: 数据、状态和配置
   - Xn.4: Mermaid 流程图（至少一个主流程）
   - Xn.5: 异常、权限和边界
   - Xn.9: 维护注意事项

10. **生成 `docs/LOGIC_MAP.md`**（根索引）：
    - 使用 `templates/logic-map/LOGIC_MAP_TEMPLATE.md` 为模板
    - 模块总览表填实际模块名和文件链接
    - 全局调用图根据实际项目架构定制
    - 维护规则速记按模板

### Phase 3: 同步 AGENTS.md

11. **更新 AGENTS.md**：
    - 检查项目中是否存在 `AGENTS.md` — 如果存在且是软链接，先读目标文件；如果不存在，创建
    - 在 `AGENTS.md` 末尾追加 `## Logic Map` 小节，内容包含：
      - 入口：`docs/LOGIC_MAP.md` 是根索引
      - 阅读路径：根索引 → 模块索引页 → 二级文档
      - 编号规范简述（模块 A-F、二级 Xn.m、编号不复用、删除标记 [已移除]）
      - 维护规则：修改业务逻辑后同步更新对应二级文档和模块索引页；新业务闭环按 NUMBERING.md 归档
      - 交叉引用格式：`参见 Xn.m`、`由 Xn.m 触发`
    - 如果 `AGENTS.md` 已有 "Logic Map" 小节，替换而非追加
    - 如果项目有 `CLAUDE.md` 且是指向 `AGENTS.md` 的软链接，无需额外操作；如果 `CLAUDE.md` 是独立文件，同样在其末尾追加 Logic Map 小节

### Phase 4: 验证和报告

12. **验证完整性**：
    - 确认每个模块索引页的编号段分配表完整
    - 确认每个编号段有对应的二级文档
    - 确认根索引的模块总览表链接正确
    - 确认 `NUMBERING.md` 的模块表与实际匹配
    - 确认交叉引用存在（跨模块调用的地方双向引用）
    - 确认 `AGENTS.md` 包含 Logic Map 小节

13. **报告给用户**：
    - 列出生成的模块索引页和二级文档数量
    - 标注哪些模块/子域信息不足（需要用户补充）
    - 提醒用户验证关键流程图的准确性

## Hard Constraints
- **绝不粘贴源码片段。** 只描述路由、文件名、函数名、表名和调用关系。
- **编号稳定。** 首次分配后不随意更改。删除标记 `[已移除]`，不复用编号。
- **二级文档完整。** 每个二级文档至少覆盖 Xn.0-Xn.5 + Xn.9 六段。
- **交叉引用。** 跨模块调用必须双向引用（如 E 模块 webhook 触发 C 模块积分变更，两边都要标注）。
- **项目类型无关。** 不假设特定框架。根据实际扫描结果适配 A-F 模块定义。

## Acceptance Criteria
- [ ] `docs/LOGIC_MAP.md` 根索引存在，模块总览表完整
- [ ] `docs/logic-map/README.md` 和 `NUMBERING.md` 存在
- [ ] `docs/logic-map/templates/` 下有 `MODULE_TEMPLATE.md` 和 `SECOND_LEVEL_TEMPLATE.md`
- [ ] 每个业务模块有模块索引页（至少 3 个模块）
- [ ] 每个模块索引页有至少 1 个二级文档
- [ ] 每个二级文档覆盖 Xn.0 到 Xn.5 + Xn.9
- [ ] 至少有 1 个 Mermaid 流程图在全局调用图中
- [ ] `AGENTS.md`（或 `CLAUDE.md`）包含 Logic Map 规范小节
- [ ] 所有跨模块调用有双向交叉引用
