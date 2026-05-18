# Workflow: /htmlForStudy

## Goal
将用户提供的代码逻辑、调用链、架构或任何复杂概念，转换成一个**自包含的交互式 HTML 可视化文件**，帮助用户直观理解。

输出文件可以直接用浏览器打开（需本地 HTTP 服务器），无需任何构建工具。

## Steps

### 1. 理解用户意图
- 确认用户想可视化的内容：调用链？架构图？算法流程？状态机？数据流？
- 确认输出路径（默认 `~/Inbox/<topic>.html`）
- 评估复杂度：简单（单图）→ 中等（多图 + 标签页）→ 复杂（多图 + 脑图 + 交互）

### 2. 设计可视化结构
根据内容类型选择合适的可视化组件：

| 内容类型 | 推荐组件 | Mermaid 语法 |
|---------|---------|-------------|
| 调用链 / 时序 | 时序图 | `sequenceDiagram` |
| 业务流程 / 算法 | 流程图 | `graph TD` 或 `graph LR` |
| 架构概览 | 子图分组流程图 | `graph TB` + `subgraph` |
| 层级关系 / 全貌 | D3 交互树脑图 | D3 `tree()` + `hierarchy()` |
| 状态变化 | 状态图 | `stateDiagram-v2` |

### 3. 编写 HTML 文件
遵循以下**强制模板规范**（踩坑后的最佳实践）：

#### 3a. 主题系统
```html
<html lang="zh-CN" data-theme="light">
<head>
<style>
:root { /* 亮色变量 */ }
[data-theme="dark"] { /* 暗色变量 */ }
</style>
<!-- 阻塞脚本：在任何渲染前设置主题，防止闪烁 -->
<script>
(function() {
  var s = localStorage.getItem('study-theme');
  var t = s || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  document.documentElement.setAttribute('data-theme', t);
})();
</script>
</head>
```

#### 3b. Mermaid 图（关键约束）
```
硬性规则：
- 使用 Mermaid 10（稳定）：cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js
- 使用 <pre class="mermaid">（非 <div>）
- 禁止在标签内使用 <br/> → HTML 解析器会破坏 Mermaid 文本
- 标签精简到单行，中文可直接使用
- 边标签 (-->|label|) 可正常使用
- style 指令可正常使用
- 使用 --> 原始箭头，不要 HTML 编码 (--&gt;)
```

#### 3c. 懒渲染（最重要）
```
Mermaid 必须 startOnLoad: false
原因：display:none 面板中容器宽度为 0，Mermaid 布局引擎算出 NaN，报错 "translate(undefined, NaN)"
```

```javascript
mermaid.initialize({
  startOnLoad: false,
  // ...
});

// 页面加载后只渲染当前可见 tab
setTimeout(function() {
  var activePanel = document.querySelector('.panel.active');
  var els = activePanel.querySelectorAll('.mermaid');
  mermaid.run({ nodes: els });
}, 100);

// 切换 tab 时懒渲染新可见的图
var renderedTabs = {};
function switchTab(name) {
  // ...切换面板...
  if (!renderedTabs[name]) {
    renderedTabs[name] = true;
    setTimeout(function() {
      var els = document.getElementById('panel-' + name).querySelectorAll('.mermaid');
      mermaid.run({ nodes: els });
    }, 150);
  }
}
```

#### 3d. D3 脑图
```html
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
```
- 数据格式：`{ name: "根", children: [{ name: "子1", children: [...] }, ...] }`
- 使用 `d3.tree().nodeSize([dx, dy])` 布局
- 用 `d3.zoom()` 支持缩放拖拽
- 点击节点折叠/展开
- 按深度着色区分层级

#### 3e. 标签页系统
- CSS 类 `.tab.active` / `.panel.active` 控制显示
- 简单 onclick 切换，无框架依赖

### 4. 保存并启动服务
- 保存 HTML 到指定路径
- 自动启动本地 HTTP 服务器：`cd <dir> && python3 -m http.server 8899 &`
- 告知用户浏览器打开 `http://localhost:8899/<filename>.html`
- 提醒：不要直接 `file://` 打开（浏览器阻止 CDN 脚本加载）

## Hard Constraints
- **必须**单 HTML 文件，零构建工具，零框架
- **必须** `startOnLoad: false`，懒渲染 Mermaid
- **禁止**在 Mermaid 标签内使用 `<br/>`
- **禁止** `location.reload()` 用于主题切换
- **必须**在 `<head>` 中用阻塞脚本设置主题，防止闪烁
- **必须**使用 Mermaid 10（非 11），避免布局引擎 bug
- **禁止**使用 `file://` 协议打开 → 必须启动本地 HTTP 服务器
- CDN 只用 jsdelivr（国内可用），D3 和 Mermaid 分开加载

## Styling Guidelines
- 极简现代风格，充足的留白
- 用 CSS 变量管理亮/暗色主题
- 卡片式布局（`.card`），圆角 10px，淡淡阴影
- 标签页用底部边框指示器，hover 变色
- 响应式：移动端阶段流改竖向，标签页字号缩小
- 图表容器可横向滚动（`overflow-x: auto`）

## Acceptance Criteria
- [ ] HTML 文件保存到指定路径
- [ ] 本地 HTTP 服务器已启动
- [ ] 用户浏览器打开无报错（检查控制台）
- [ ] 所有 Mermaid 图正常渲染（包括隐藏 tab 切过去后）
- [ ] 主题切换无闪烁、无死循环
- [ ] D3 脑图（如有）可缩放拖拽、节点可折叠
- [ ] 移动端布局不溢出
- [ ] 所有 tab 切换流畅，图能正常显示
