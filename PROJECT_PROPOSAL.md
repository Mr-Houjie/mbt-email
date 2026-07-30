# 2026 MoonBit 国产基础软件开源大赛 项目申报书

## 一、项目名称与 GitHub 仓库

- **项目名称**：mbt-email（基于 MoonBit 的邮件地址与 MIME 消息解析库）
- **GitHub 仓库**：https://github.com/Mr-Houjie/mbt-email
- **许可证**：MIT ｜ **语言**：MoonBit ≥ 0.1.20260629

## 二、项目简介

`mbt-email` 是一个使用 MoonBit 语言原生实现的 RFC 5322 邮件地址解析与 RFC 2045/2046 MIME 消息解析库。它将原始邮件文本解析为 MoonBit 原生数据结构（基于代数数据类型的 AST），并支持将数据结构序列化回标准邮件格式，为 MoonBit 生态提供邮件协议处理基础设施。

**架构上分为四层**：
1. **词法分析层（Lexer）**：字符级扫描，处理邮件头字段名/值、引用字符串、域字面量、MIME 边界标记、编码字等 Token
2. **语法解析层（Parser）**：递归下降解析器，处理邮件地址（local-part@domain）、邮件头、MIME 多部分消息体、Content-Type/Content-Disposition 等结构化头字段
3. **中间表示层（AST）**：基于代数数据类型的邮件消息 AST，含 EmailAddress、Header、MimePart、Message 等核心类型
4. **序列化层（Serializer）**：将 MoonBit AST 序列化为符合 RFC 5322/2045 规范的邮件文本

**核心特色**：MoonBit 原生实现、纯 MoonBit 零外部依赖、手写递归下降解析器、覆盖 RFC 5322/2045/2046 三层规范、双向解析与序列化。

## 三、项目方向与适用场景

**大赛方向归属**：对应大赛"**应用生态**"方向下的**协议解析/网络基础设施**工具。邮件是互联网最基础的通信协议之一，但 MoonBit 生态中尚无原生邮件解析器，本项目填补这一关键空白，为 MoonBit 的邮件客户端、自动化邮件处理、安全审计等场景提供基础设施。

**定位**：MoonBit 生态的原生邮件/MIME 协议解析库，为 MoonBit 网络应用提供标准化的邮件处理能力。

**适用场景**：
- 邮件客户端开发（解析和生成标准邮件格式）
- 自动化邮件处理管道（新闻订阅、通知系统）
- 邮件安全分析与审计工具
- MIME 附件提取与内容识别
- 邮件归档与检索系统

## 四、核心功能

1. **RFC 5322 邮件地址解析**：完整支持 dot-atom、quoted-string、domain-literal 等地址格式
2. **邮件头解析**：From、To、Cc、Subject、Date、Message-ID 等标准头字段的结构化解析
3. **MIME 多部分解析**：RFC 2046 multipart/mixed、multipart/alternative、multipart/related 等类型支持
4. **Content-Type 解析**：MIME 类型/子类型及参数（charset、boundary、name 等）
5. **Content-Disposition 解析**：inline/attachment 及 filename 参数提取
6. **编码处理**：RFC 2047 编码字（encoded-word）解码、Base64/Quoted-Printable 内容传输编码识别
7. **序列化支持**：将 AST 序列化为符合规范的邮件文本
8. **工程化**：单元测试全覆盖 + GitHub Actions CI

## 五、项目性质

**原创实现**（非移植）。代码 100% 由作者独立编写，解析器设计参照 RFC 5322（Internet Message Format）、RFC 2045/2046（MIME）公开标准中的 ABNF 文法定义（属公开标准参考，非代码复制）。

**原创工程工作**：
- 基于 MoonBit 代数数据类型（enum）自定义邮件/MIME AST 类型系统
- 手写递归下降解析器（词法分析 → 语法分析两阶段设计）
- 针对邮件头折叠（folding）、编码字（encoded-word）、MIME 边界识别等特性的专用解析算法
- 基于 MoonBit Trait 系统的可扩展序列化框架

**外部参考**：RFC 5322（https://datatracker.ietf.org/doc/html/rfc5322）、RFC 2045/2046（https://datatracker.ietf.org/doc/html/rfc2046）
