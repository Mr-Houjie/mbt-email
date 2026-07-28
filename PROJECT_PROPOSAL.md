# 2026 MoonBit 国产基础软件开源大赛 项目申报书

## 一、项目名称与 GitHub 仓库

- **项目名称**：mbt-markdown（基于 MoonBit 的 Markdown 解析与 HTML 渲染库）
- **GitHub 仓库**：https://github.com/Mr-Houjie/mbt-markdown
- **许可证**：MIT ｜ **语言**：MoonBit ≥ 0.1.20260629

## 二、项目简介

`mbt-markdown` 是一个使用 MoonBit 语言原生实现的 Markdown 解析与 HTML 渲染库。它将 Markdown 文本解析为自定义 AST（抽象语法树），再将 AST 渲染为规范 HTML，为 MoonBit 生态提供开箱即用的文档处理基础设施。

**架构上分为三层**：
1. **词法/内联解析层（Lexer）**：字符级扫描，处理 emphasis、strong、code span、link、image 等内联元素的精确解析与嵌套
2. **语法/块级解析层（Parser）**：逐行扫描的递归下降解析器，自动识别 heading、paragraph、code fence、blockquote、list、thematic break 等块级元素
3. **HTML 渲染层（Renderer）**：基于 AST 遍历的递归渲染器，输出带规范 HTML 转义的字符串

**核心特色**：MoonBit 原生实现、纯 MoonBit 零外部依赖、手写递归下降解析器、支持 CommonMark 核心语法子集、8 项单元测试全覆盖。

## 三、项目方向与适用场景

**大赛方向归属**：对应大赛"**应用生态**"方向下的"**Markdown to HTML 工具**"（见大赛章程《项目方向》章节），同时可作为 MoonBit 生态的基础设施组件服务于文档生成、静态网站构建等场景。

**定位**：MoonBit 生态的 Markdown 处理基础库，填补 MoonBit 在文档解析与渲染领域的空白。生态中虽有 `cmark.mbt`（CommonMark 解析器）和 `mizchi/markdown`（增量解析器）等项目，但本项目的差异化定位在于：

- **简洁轻量**：~1235 行有效代码，核心逻辑清晰可读，适合作为 MoonBit 学习参考与二次开发起点
- **零外部依赖**：仅依赖 MoonBit 标准库 `builtin`，无任何第三方包依赖
- **手写解析器**：非编译生成或移植，代码完全原创可控

**适用场景**：
- MoonBit 生态中的文档渲染与文档站生成
- MoonBit 项目的 README/文档预览工具
- LLM 输出的 Markdown 内容渲染
- 静态网站生成器（SSG）的基础组件
- MoonBit 语言教学与解析器实现参考

## 四、核心功能

1. **完整的内联解析**：Text、SoftBreak、HardBreak、Emphasis、Strong、Code、Link、Image 共 8 种 AST 节点
2. **完整的块级解析**：Heading(1-6)、Paragraph、CodeBlock、ThematicBreak、Blockquote、ListBlock（有序/无序）、RawHtmlBlock
3. **HTML 渲染器**：递归 AST 遍历 + 5 字符 HTML 转义（`& < > " '`）
4. **公共 API**：`parse()` 返回 AST Document、`md_to_html()` 一步完成 Markdown → HTML
5. **CLI 演示**：`moon run cmd/main` 可直接运行展示
6. **工程化**：8 项单元测试（moon test 全通过）+ GitHub Actions CI 就绪

## 五、项目性质

**原创实现**（非移植）。代码 100% 由作者独立编写，解析器设计借鉴 CommonMark 规范的公开文法定义（属公开标准参考，非代码复制）。

**原创工程工作**：
- 基于 MoonBit 代数数据类型（enum）自定义 AST 类型系统
- 手写递归下降解析器（内联解析 → 块级解析两阶段设计）
- 基于 `StringBuilder` 的增量 HTML 渲染器
- 基于 `while` 循环而非函数式 `loop` 的线性扫描算法（适配 MoonBit 最新语法）

**外部参考**：CommonMark Spec 0.31.2（公开规范，https://spec.commonmark.org/）


