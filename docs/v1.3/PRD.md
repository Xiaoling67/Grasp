# Grasp — Product Requirements Document v1.3

**AI Note-taking and Understanding — 从课堂助手扩展为通用实时知识协作工具**

**Version:** 1.3
**Date:** 2026-06-29
**Supersedes:** v1.1-r3（`docs/v1.1/PRD.md`，2026-06-28）
**Platform:** macOS 14.0+ | Swift 5.9 | SwiftUI + AppKit
**Status:** 待开发 — 本文档是 v1.3 全部产品范围的唯一依据，PM 写 spec / Engineer 实现 / QA 验收均以此为准

---

## 0. v1.3 变更总览

v1.1-r3 把 Grasp 的执行细节钉死在"完全像 Apple Notes 一样顺滑"上，但产品定位文档一直停留在 v1.0 的"大学课堂助手"叙事（`PRD.md` 根目录文件，2026-06-08，从未跟上 v1.1 的进展）。v1.3 做两件事：

1. **重新对齐产品定位** — 用 Founder 最新的产品文档替换掉过时的"课堂助手"叙事，Grasp 现在是"AI Note-taking and Understanding"：一个在任何信息密集的实时场景（课堂、会议、培训、知识分享）中与用户协同记笔记、并主动消除理解障碍的工具，对标 Granola 但路线完全不同。
2. **补齐愿景文档里两个完全没做的能力**：Template-driven Notes、Inline AI Editing。其余愿景条目（实时生成、人机协同编辑、Slide-driven、Personalized Memory、Proactive Explanation、Highlight-to-Explain、Knowledge Profile）在 v1.1-r3 中已经做到，本文档只做"对齐确认 + 小幅扩展"，不重新设计。

| 维度 | v1.1-r3（已上线） | v1.3（本次新增/变更） |
|---|---|---|
| 产品定位叙事 | "macOS 课堂 AI 助手"，唯一目标用户=大学生 | "AI 笔记与理解协作工具"，覆盖课堂 + 会议 + 培训 + 知识分享；International Mode 仅保留为语言辅助能力 |
| 结构化笔记来源 | 仅 Slide-driven（上传幻灯片 → AI 解析章节结构） | **新增 Template-driven**：用户上传或手写自定义框架（如 VC 评估框架 Market/Team/Product/Business Model/Competition），AI 把会话内容持续填充进对应 section |
| 笔记编辑方式 | 仅"整篇 Apple Notes 风格自由编辑"（手动改 / AI 追加） | **新增 Inline AI Editing**：划选笔记里任意一段文字，弹出对话式编辑面板，让 AI 只改写这一段（Rewrite / Expand / Shorten / Clarify / Change tone），不重新生成全文 |
| Personalized Memory | `noteStyleGuide` 是一个纯字符串，由 `AppViewModel.inferNoteStyleGuide(from:)` 对笔记最终文本做启发式分析得出（详简度/编号深度/表格使用），**并不比较 AI 草稿与用户编辑的差异** | 正式纳入"草稿 vs 编辑后版本"对比信号：每一次 Inline AI Editing 的"选中文本 → 替换后文本"作为最高质量样本喂给 style guide 更新逻辑；扩展追踪术语替换、保留/删除模式 |
| Auto Explain / Highlight-to-Explain / Knowledge Profile | 已上线（`docs/v1.1/SPEC.md`、`docs/v1.1/spec-knowledge-profile.md`） | 不变，确认已满足愿景文档"AI Understanding Assistant"全部要求 |
| International Mode | v1.0-v1.1 的课堂语言辅助能力之一 | 保留为非母语用户的语言辅助能力，但不作为核心叙事 |

---

## 1. 产品愿景与定位

### 1.1 一句话定位

Grasp 是下一代 AI 笔记应用：不是会后总结工具，而是让用户和 AI 在听课/开会的**当下**协同把笔记写完，使会后几乎不需要再编辑。

### 1.2 为什么不是另一个 Granola

Granola 等现有 AI 笔记产品的核心模式是"会后总结"：会议/课程结束后，AI 重新整理转录稿生成摘要。这个模式有结构性问题：

- **信息会被悄悄丢弃或改写。** AI 在事后重建对话时不知道用户当时真正想保留什么——原话、特定措辞、重点句子——这些常常在"清理"过程中被合并或删除。
- **用户不会花时间精修会后摘要。** 会议一结束，多数人不会再回头大改 AI 生成的总结，所以总结里的失真会一直留在最终笔记里。
- **同类会议产出几乎相同的笔记。** 没有预先结构化的输入，AI 只能按通用模板总结，无法体现每次会话的真实重点。
- **没有记忆。** 每次生成都是无状态的，AI 不会随着使用变得更懂这个用户。
- **笔记不会"在会议中就完成"。** 用户仍然要在会后重新阅读、整理、补充。

Grasp 用五个原则解决这些问题，并已经在 v1.0-v1.1 中验证：

1. **实时协同生成**，笔记反映用户当下的真实意图，而不是事后重建的猜测。
2. **人机共创**而不是被动接收 AI 总结——用户随时可以引导结构、强调重点、保留原话。
3. **"先定结构，再生成"**——会话开始前用户可以给定结构（幻灯片或模板），AI 在结构内生成，而不是生成千篇一律的笔记。
4. **记忆系统**，随着使用持续学习用户的笔记习惯，让用户需要手写/修改的部分越来越少。
5. **会话结束即笔记完成**，不需要会后重新组织。

### 1.3 核心能力一览（I. AI Note-taking）

| # | 能力 | 状态 |
|---|---|---|
| 1 | Real-Time AI Note Generation | ✅ 已上线（v1.0+，体验在 v1.1-r3 重做为 Apple Notes 风格） |
| 2 | Human + AI Collaborative Editing | ✅ 已上线（AI 从不覆盖用户编辑，手动笔记标记为 `source = "manual"`） |
| 3 | Structured Note Generation — Slide-driven | ✅ 已上线 |
| 3b | Structured Note Generation — **Template-driven** | 🆕 **v1.3 新增**，见 §4.3.2 |
| 4 | Personalized Memory | 🟡 已部分实现，v1.3 扩展，见 §4.4 |
| 5 | Human + AI Hybrid Notes（综合效果） | ✅ 是上面四项的自然结果，无需单独实现 |
| 6 | **Inline AI Editing** | 🆕 **v1.3 新增**，见 §4.6 |

### 1.4 核心能力一览（II. AI Understanding Assistant）

| # | 能力 | 状态 |
|---|---|---|
| 1 | Proactive AI Explanation | ✅ 已上线（即 Auto Explain，`AutoExplainCardView` + `detectUnfamiliarTerm`） |
| 2 | Highlight-to-Explain | ✅ 已上线（划词菜单的 Search 按钮，`streamSearch`） |
| 3 | Personalized Knowledge Profile | ✅ 已上线（`MemoryService` + `KnowledgeProfileView`） |

这三项在 v1.1-r3 已经完整覆盖愿景文档的要求，本文档不再重新定义，详细行为/边界情况见 `docs/v1.1/SPEC.md` 与 `docs/v1.1/spec-knowledge-profile.md`，v1.3 不改动其行为。

---

## 2. 目标用户

### 2.1 主要用户

任何需要在**信息密集、实时发生、无法暂停**的场景中记录和理解知识的人：

- 大学课堂（STEM / 商科 / 法律等高密度课程）
- 工作会议、知识分享会、内部培训（如愿景文档举例的 VC 投资人用固定框架评估创业项目）
- 留学生 / 非母语者在全英文授课或全英文会议环境中

这些场景的共同特征：**用户必须同时做三件互相争抢认知资源的事——听、理解、记**，而且事后回放/补录的成本很高（要么没有录音权限，要么补录耗时远超会议本身）。

### 2.2 非用户（明确不做）

- 只看录播视频、可以无限暂停回放的学习场景（不是实时场景，Grasp 的核心价值不成立）
- 只想要"会后一份摘要，不关心过程"的用户——这正是 Granola 的目标用户，不是 Grasp 的目标用户
- 多人协作记笔记（一份笔记多人同时编辑）——v1.3 仍不做

### 2.3 已有的场景化能力（收敛）

Standard/International 双模式在 v1.3 中收敛为语言辅助叙事：仅保留 International Mode 作为非母语用户在英文课堂或会议中的语言辅助能力；产品定位以 §1.2-1.3 的通用笔记/学习能力为主。

---

## 3. v1.3 目标与非目标

### Goals（v1.3 必须做到）

- 没有幻灯片的会话（典型如商务会议、投资评估）也能获得结构化笔记，而不是被迫退化成时间顺序流水账
- 用户能够像跟 AI "聊"一样，针对笔记里的某一句/某一段要求改写，而不需要手动改或者重新生成整篇笔记
- 每一次 Inline AI Editing 都成为可被系统利用的个性化信号，让后续 AI 生成的笔记越来越贴近用户习惯
- 产品定位文档（README、根目录 PRD）不再让新接触项目的人以为 Grasp 只能用于"大学课堂"

### Non-Goals（v1.3 明确不做）

- 不做模板的多人共享/模板市场（留作 P2 的开放问题）
- 不把 Inline AI Editing 扩展到 Past Lecture 的只读笔记视图（那里笔记是只读展示，详见 v1.1-r3 clarification #2）
- 不引入向量数据库或 embedding 检索（模板/记忆匹配继续用关键词 + LLM，和 `PRODUCT_ROADMAP.md` Phase 1 的判断一致）
- 不做移动端、不做多人协作、不做离线模式（沿用 v1.0 起的既定 Non-Goals）

---

## 4. Feature Spec — I. AI Note-taking

### 4.1 Real-Time AI Note Generation — ✅ 已上线，无变化

每个 sealed transcript block 触发一次 `DeepSeekService.generateNoteEntry`，按当前结构（slide 或 v1.3 新增的 template）追加笔记。行为细节、质量门控、重复检测均维持 v1.1-r3 clarification #8/#17/#22/#23 的规定，不在本文档重复。

### 4.2 Human + AI Collaborative Editing — ✅ 已上线，无变化

用户可在会话进行中随时编辑 AI 生成的笔记；一旦用户修改，AI 不再覆盖该笔记。维持 v1.1-r3 Apple Notes 风格连续文档编辑（NSTextView + NSScrollView），无变化。

### 4.3 Structured Note Generation

#### 4.3.1 Slide-driven — ✅ 已上线，无变化

上传 PDF 幻灯片 → `SlideParserService` 提取文本 → `DeepSeekService.generateSlideStructure` 解析出 `[SlideItem]`（index/title/concepts/keywords）→ 会话中按章节追加笔记。

#### 4.3.2 Template-driven Notes — 🆕 v1.3 新增

**问题：** 没有幻灯片的场景（投资评估会、产品评审会、客户访谈）一样需要结构化笔记，但用户没有"幻灯片"这种素材，他们有的是**自己的评估框架**——例如 VC 投资人看创业项目固定看 Market / Team / Product / Business Model / Competition 五个维度。今天唯一能表达这种偏好的方式是 AI Notes 设置齿轮里的自由文本"note framework"字段（v1.1-r3 #28），但那只是一句*提示*，不会产生真正分 section 的结构化文档，也不会在会话开始前就把空白结构展示给用户。

**目标行为：** 让"模板"和"幻灯片"成为同一种"预定义结构"机制的两种输入方式，复用 Slide-driven 已经验证过的"解析结构 → 按结构追加笔记"管线，但**模板模式下界面要先把全部 section 标题铺好（像一张待填的表格），而不是像幻灯片模式那样随着话题推进才出现**。

**输入方式（New Lecture / New Session 弹窗新增 "Use a structure template" 路径，与现有 "Upload slides" 并列、互斥）：**

| 优先级 | 方式 | 行为 |
|---|---|---|
| P0 | **快速手写** | 用户逐行输入 section 标题，每行可选附一句 guidance（如 `Market: TAM/SAM/SOM, growth, market dynamics`）。直接在本地生成 `TemplateSection` 列表，不调用 LLM。 |
| P1 | **保存为可复用模板** | 用户可以把刚输入的结构存成一个命名模板（如"VC Pitch Evaluation"），下次新建会话时直接从列表选用，不用重新输入。本地 SQLite 新表 `templates(id, name, sections_json, created_at)`。 |
| P1 | **上传文档解析** | 用户上传一份已有模板文件（PDF/Word/纯文本）→ 复用 `SlideParserService` 的文本抽取 → 新增 `DeepSeekService.generateTemplateStructure(rawText:) -> [TemplateSection]`，做法与 `generateSlideStructure` 对称。 |

**数据模型：**

```swift
struct TemplateSection: Codable {
    var index: Int
    var title: String       // e.g. "Market"
    var guidance: String    // e.g. "TAM/SAM/SOM, growth, market dynamics — what AI should listen for"
}
```

- `Lecture` 新增字段 `structureType: String`（`"none" | "slides" | "template"`），一次会话只能用一种结构来源，互斥。
- 复用现有 `NoteBlock.slideIndex` / `slideTitle` 字段存储"笔记属于哪个 section"，不新增笔记表字段——`generateNoteEntry` 的调用方按 `structureType` 把 `[TemplateSection]` 转换成与 `[SlideItem]` 同形的结构传入即可（两者本质上都是"index + title + 一段描述当前章节该装什么内容的文本"，可以提取一个共享协议，但这是工程实现细节，不在本 PRD 里强制具体写法）。

**会话中的行为：**

1. 会话开始（Start Recording）时，Notes 文档**立刻**按模板顺序插入全部 section 标题作为加粗的标题行（例如 `Market`、`Team`、`Product`…），每个标题下方留空——用户从第一秒就能看到完整的待填结构，这是和 Slide-driven 模式（章节随专教学进度才出现）的关键差异。
2. 每个 sealed block 触发笔记生成时，AI 必须从 `TemplateSection.guidance` 中选出内容最匹配的一个 section，把生成的笔记**插入到该 section 标题正下方**（不是追加到文档末尾）。
3. 内容无法匹配任何已定义 section 时，归入文档末尾一个隐式追加的 `Other` 区块（每个模板自动带有，index = `sections.count`），不强行塞进不合适的 section。
4. Section 内部仍然遵循 v1.1-r3 既有的"扁平、不重建层级数据"约束——一个 section 下可以有多条编号笔记（`1.` / `1.1` / `1.1.1`），但 section 标题本身只是普通加粗文本，不是树状数据。
5. Detail level（Concise/Balanced/Detailed）、duplicate 检测、emphasis cue 捕捉（统一使用更通用的 "Key point:"，不再使用考试语境的 "Exam cue:"）等既有规则原样适用于模板模式。

**验收标准（草稿，供 PM 写 spec 时细化）：**
- [ ] New Session 弹窗可以选择"Upload slides"或"Use a template"二选一，互斥
- [ ] 快速手写模板：每行一个 section，可选 guidance，不调用网络
- [ ] 保存模板后，下次新建会话能从已保存模板列表里一键选用
- [ ] 上传文档可被解析为 `[TemplateSection]`，解析失败时用户可以退回手写模式，不阻塞开始录音
- [ ] Start Recording 后立刻看到全部 section 标题，内容为空
- [ ] 每条 AI 笔记插入到匹配 section 标题正下方，而不是文档末尾
- [ ] 无法匹配任何 section 的内容进入文档末尾的 `Other` 区块
- [ ] 模板模式下笔记依然是扁平文本，没有树状结构、没有 bullet
- [ ] 模板与幻灯片是互斥的两条路径，共用同一条"结构化生成"底层逻辑（不是两套并行实现）

### 4.4 Personalized Memory — 🟡 v1.3 扩展

**现状（v1.1-r3 实际实现，比愿景文档描述的浅）：** `AppViewModel.noteStyleGuide` 是一个纯字符串，由 `inferNoteStyleGuide(from: plainText)` 对笔记**最终文本**做启发式分析（编号深度使用情况、是否用表格等），存入本地 settings（`db.setSetting(key: "noteStyleGuide", ...)`），再拼进每次笔记/总结生成的 prompt。**它从未真正比较"AI 草稿"与"用户编辑后版本"的差异**——这正是愿景文档第 4 节描述的核心机制，但目前没有做。

**v1.3 要补的信号：**

1. **Inline AI Editing 的每一次"替换"都是最高质量的训练信号。** 选中文本（可能是 AI 写的，也可能是用户自己写的）→ AI 改写后的最终版本，这个 pair 精确对应愿景文档"比较 AI 原始草稿与用户编辑版本"的描述，且比起监听整篇文档的模糊启发式，这是用户**主动确认**的修改，信号质量更高。每次用户点击 Replace 后，把 `(selectedText, finalText, instruction)` 传入 `inferNoteStyleGuide` 的输入来源（具体是扩展现有启发式函数，还是在足够样本积累后改成调用 LLM 总结风格规律，由工程在实现时判断；本 PRD 只约束输入信号必须被采集和使用，不规定具体算法）。
2. **术语偏好。** 当用户的替换结果把某个词系统性换成另一个词（如把 AI 写的 "stakeholders" 换成 "investors"），多次出现后应该被记录为术语偏好，后续生成提示里体现。
3. **保留 vs 删除模式。** 这一项愿景文档提到但目前没有任何信号采集（没有删除笔记的埋点）。v1.3 暂不要求实现独立的删除埋点基础设施（属于 `PRODUCT_ROADMAP.md` Phase 1 范围，已部分存在 `engaged`/`dismissed_at` 但没有用在 Notes），列为 §6 的 P1 而非 P0。

**验收标准：**
- [ ] 每次 Inline AI Editing 的 Replace 操作都会把 `(selectedText, finalText)` 传给 style guide 更新逻辑
- [ ] 多次相同方向的术语替换后，后续生成的笔记/总结 prompt 中体现该术语偏好
- [ ] style guide 的更新是本地、增量的，不需要用户做任何额外设置

### 4.5 Human + AI Hybrid Notes — ✅ 概念性结果，无需单独实现

这是 4.1-4.4（以及 4.6）共同作用的产物：每个用户拿到的最终笔记因为自己的编辑历史、模板选择、Inline Editing 习惯而互不相同。v1.3 不需要为此单独写代码，只需要确保上面几项都正确落地。

### 4.6 Inline AI Editing — 🆕 v1.3 新增

**问题：** 今天 Notes 面板的划词菜单**不存在**——划词只在 Transcript 面板生效（`SelectionPopupView`，K/L/Search/Note 四个按钮，作用于转录文字）。用户想让 AI 改写自己笔记里的某一句话，唯一办法是手动删了自己重打，或者祈祷下一次 AI 追加生成时碰巧覆盖到——但 v1.1-r3 明确规定"AI 从不覆盖用户编辑"（#1 collaborative editing 原则），所以这条路径其实走不通。愿景文档第 6 点描述的"划选笔记一部分 → 弹窗和 AI 对话式编辑该部分"完全没有实现。

**目标行为：**

1. **触发：** 用户在 Notes 面板的连续 `NSTextView` 文档里选中 ≥2 个字符（复用 v1.1-r3 #6/#7 的选区计算与 dismiss 规则：面板相对坐标、外部点击/Esc/输入/滚动均会关闭）。
2. **第一层弹窗（即时）：** 选区上方出现一个迷你 pill（视觉复用 `SelectionPopupView` 的 `VisualEffectView` + 圆角样式），只有一个按钮：**"✨ Edit with AI"**（图标 `wand.and.stars`）。这一层必须像 Transcript 划词菜单一样在 ≤1 帧内出现，不能有 debounce。
3. **第二层卡片（点击后展开）：** 类似 `SearchCardView` 的浮层卡片，包含：
   - 选中文字的只读预览（超长截断显示前 ~80 字符）
   - 5 个快捷动作 chip：**Rewrite / Expand / Shorten / Clarify / Change tone**——点击任意一个立即用该动作对应的默认指令发起请求
   - 一个单行自由文本输入框（"Or tell AI what to change…"），支持自定义指令，可在快捷动作生成结果之后继续追加指令做下一轮修改（多轮、可叠加，对应愿景文档"chat with AI"的描述）
   - 流式输出区域：AI 改写结果逐字流出
   - 完成后出现 **Replace**（把结果写回原选区）和 **Discard**（关闭卡片不做任何改动）两个按钮
4. **作用范围必须严格限定在原选区。** 用 `NSTextStorage.replaceCharacters(in:with:)` 仅替换原 `NSRange`，绝不重新生成或触动文档其他部分。这是和"AI 追加新笔记"完全不同的写入路径，必须分开实现，不能和 sealed-block 笔记生成共用写入逻辑。
5. **Replace 之后，新文本保持选中状态**，用户可以立刻再次点击 "Edit with AI" 做下一轮迭代（链式编辑）。
6. 每次成功 Replace，必须把 `(selectedText, finalText)` 传给 §4.4 的 style guide 更新逻辑。

**Change tone 的二级选项：** 点击 Change tone 展开三个 tone 预设（Formal / Casual / Concise-professional），自由文本框依然可用于自定义 tone（如"更幽默一点"）。

**默认指令文案（供 Prompt Spec 参考，§10 给出完整 prompt）：**

| 动作 | 默认指令 |
|---|---|
| Rewrite | 在保持原意和信息不变的前提下，把这段文字改写得更清晰、更好读 |
| Expand | 给这段文字补充更多细节、有用的延展或支撑性上下文，不要编造原文未暗示的事实 |
| Shorten | 把这段文字压缩到只保留核心意思，去掉冗余 |
| Clarify | 把这段文字改写得更容易理解，消除歧义 |
| Change tone (Formal) | 把这段文字改写得更正式、更专业 |

**约束（must / must not）：**
- 必须只调用一次 LLM 请求，等用户主动点击快捷动作或按下 Enter 提交自定义指令才发起；自由文本框打字过程中**不能**逐字触发请求
- 必须把原选区前后各 ~200 字符的文档内容作为 `documentContext` 传入，让 AI 理解上下文但不重写它
- 不能自动应用结果——必须用户点击 Replace 才落盘
- 首 token 延迟目标与 Search 一致：< 1s（沿用根目录 PRD.md P0-5 的标准）
- 必须在 Past Lecture 只读笔记视图中**不可用**（那里笔记是只读展示，详见 v1.1-r3 clarification #2），仅在 live 会话的 Notes 面板生效

**新增服务方法：**

```swift
func streamInlineEdit(
    selectedText: String,
    instruction: String,
    documentContext: String,
    onToken: @escaping (String) -> Void
) async throws -> String
```

行为模式与现有 `streamSearch` 对称（流式、私有 `stream(system:prompt:maxTokens:onToken:)` 复用）。

**验收标准：**
- [ ] Notes 面板划选 ≥2 字符后，≤1 帧内出现 "Edit with AI" pill，无 debounce
- [ ] 点击后展开卡片，含选中文字预览、5 个快捷动作 chip、自由文本输入框
- [ ] 5 个快捷动作分别触发对应默认指令，结果流式展示
- [ ] Change tone 展开三个 tone 预设
- [ ] Replace 仅替换原选区对应的 `NSRange`，不触动文档其他内容
- [ ] Replace 之后新文本保持选中，可连续多轮编辑
- [ ] Discard / Esc / 外部点击 / 新选区均会关闭卡片且不写回任何内容
- [ ] 每次 Replace 都把 `(selectedText, finalText)` 传给 style guide 更新逻辑
- [ ] Past Lecture 的只读笔记视图中不出现此入口
- [ ] 首 token 延迟 < 1s

---

## 5. Feature Spec — II. AI Understanding Assistant

三项能力（Proactive AI Explanation / Highlight-to-Explain / Personalized Knowledge Profile）已经在 v1.1 完整实现并通过验收（参见 `docs/v1.1/SPEC.md` 第 2 节、`docs/v1.1/spec-knowledge-profile.md`），完全覆盖愿景文档对这部分的要求。v1.3 不改动其行为，仅在此确认：

- **Proactive AI Explanation** = Auto Explain：`detectUnfamiliarTerm` 按置信度阈值（0.65）自动检测未知概念/术语，结果展示在常驻的 Auto Explain 区块（v1.1-r3 §5 四象限布局中"始终可见，不藏在 tab 后面"）。
- **Highlight-to-Explain** = 划词菜单的 Search 按钮：`streamSearch` 流式输出定义 + 类比，≤1s 首 token。
- **Personalized Knowledge Profile** = `MemoryService`（`KnowledgeStatus` / `KnowledgeAction` / `KnowledgeRecord`）+ 独立设置页 `KnowledgeProfileView`，用户可声明已掌握的概念，Auto Explain 据此跳过已知内容。

---

## 6. v1.3 需求清单（仅新增/变更项，已上线能力不重复列出）

### P0 — 必须有，没有就不能算完成 v1.3

| # | 需求 | 验收标准 |
|---|---|---|
| P0-1 | New Session 支持手写模板（section 列表 + 可选 guidance） | 不调用网络，本地直接生成 `[TemplateSection]` |
| P0-2 | 模板模式下，会话开始即铺好全部 section 标题 | Start Recording 后立刻可见，内容区为空 |
| P0-3 | AI 笔记按 section guidance 匹配插入对应标题下方 | 不匹配任何 section 时进入文档末尾 `Other` 区块 |
| P0-4 | Notes 面板划词出现 "Edit with AI" 入口 | ≤1 帧内出现，无 debounce |
| P0-5 | Inline Editing 5 个快捷动作 + 自由文本输入 + 流式预览 | 默认指令按 §4.6 表格执行 |
| P0-6 | Replace 仅替换原选区 | 验证文档其他部分字节级不变 |
| P0-7 | Inline Edit 结果反哺 style guide | `(selectedText, finalText)` 进入 §4.4 更新逻辑 |

### P1 — 应该有，影响完整体验但有 workaround

| # | 需求 | 验收标准 |
|---|---|---|
| P1-1 | 模板可保存为命名模板并复用 | 本地 `templates` 表，新建会话时可选用 |
| P1-2 | 上传文档解析为模板 | `generateTemplateStructure` 解析失败时不阻塞开始录音 |
| P1-3 | Change tone 三档预设 | Formal / Casual / Concise-professional |
| P1-4 | style guide 显式追踪术语替换偏好 | 同方向替换出现 ≥N 次后体现在生成 prompt |
| P1-5 | README / 根目录 PRD 更新产品定位叙事 | 不再仅描述"大学课堂助手" |

### P2 — 可以有，锦上添花

| # | 需求 |
|---|---|
| P2-1 | 模板跨用户分享/模板市场 |
| P2-2 | Inline AI Editing 扩展到 Past Lecture 只读笔记（需要先把那里的笔记重新做成可编辑） |
| P2-3 | 没有显式模板/幻灯片时，AI 根据已上传素材自动建议一个模板结构 |
| P2-4 | Notes 删除行为埋点（保留 vs 删除模式的完整信号采集，对应 `PRODUCT_ROADMAP.md` Phase 1 思路扩展到 Notes） |

---

## 7. UX Flow

### Flow 1：会话开始前设置模板

```
点击 New Lecture / New Session
    → 填写名称 + subject
    → 选择结构来源：[ Upload Slides ] | [ Use a Template ] | [ None ]
         选择 Use a Template：
             → 从已保存模板列表选一个   或   手写新模板（逐行 section + 可选 guidance）
                  或   上传文档解析（PDF/Word/纯文本）
             → 可选：保存为命名模板供下次复用
    → 点击 Start Recording
         → Notes 文档立刻插入全部 section 标题，内容为空
         → 开始转录；每个 sealed block 的笔记按 section 匹配插入对应标题下方
```

### Flow 2：对笔记里的一段文字做 Inline AI Editing

```
在 Notes 面板划选一段文字（≥2 字符）
    → 出现 "✨ Edit with AI" pill
    → 点击展开卡片：
         选中文字预览
         [Rewrite] [Expand] [Shorten] [Clarify] [Change tone]
         自由文本输入框
    → 点击某个快捷动作，或输入自定义指令后回车
         → AI 流式输出改写结果
    → [Replace]  → 写回原选区，新文本保持选中，可继续下一轮编辑
    → [Discard]  → 关闭卡片，不做任何改动
    → 按 Esc / 点击外部 → 关闭卡片，不做任何改动
```

---

## 8. 数据模型与架构变更

| 改动 | 说明 |
|---|---|
| `TemplateSection: Codable { index, title, guidance }` | 新结构，与 `SlideItem` 同构但字段名贴合模板语境 |
| `Lecture.structureType: String`（`none`/`slides`/`template`） | 标记当前会话用哪种结构来源，二者互斥 |
| 新表 `templates(id, name, sections_json, created_at)` | 存储用户保存的可复用模板（P1） |
| `NoteBlock.slideIndex` / `slideTitle` 复用 | 模板模式下复用既有字段存储"笔记属于哪个 section"，不新增笔记表字段 |
| `DeepSeekService.generateTemplateStructure(rawText:) -> [TemplateSection]` | 新方法，对称于现有 `generateSlideStructure` |
| `DeepSeekService.streamInlineEdit(selectedText:instruction:documentContext:onToken:) async throws -> String` | 新方法，对称于现有 `streamSearch` |
| Notes 写入路径分叉 | "sealed-block 追加笔记"与"Inline Edit 替换选区"必须是两条独立的写入逻辑，不能合并，否则容易破坏 §4.6 的"只改选区"约束 |
| `AppViewModel.inferNoteStyleGuide` 输入扩展 | 增加 Inline Edit 的 `(selectedText, finalText)` pair 作为输入来源，具体算法（仍用启发式，或样本足够后换成 LLM 总结）由工程实现时决定 |

---

## 9. Model Behavior Spec

### 9.1 Template Structure Parsing（`generateTemplateStructure`）

**应该做：**
- 从上传文档中识别出"评估维度/章节标题"层级的结构，每个 section 配一句 guidance 描述这个 section 应该装什么内容
- guidance 要具体到能指导后续笔记生成判断"这段话该归哪个 section"，不能只是复述标题

**绝对不能做：**
- 编造文档中不存在的 section
- 把正文细节误判成新的 section 标题

**边界情况处理：**

| 情况 | 期望行为 |
|---|---|
| 文档没有清晰的章节结构 | 返回空列表，前端提示用户改用手写模式，不阻塞开始录音 |
| 文档过长导致截断 | 已解析出的 section 仍然可用，不因为后半部分丢失而整体失败 |

### 9.2 Template-Driven Note Placement（在 `generateNoteEntry` 基础上的新分支）

**应该做：**
- 每条候选笔记必须从 `[TemplateSection]` 中选出 guidance 最匹配的一个 section index
- 找不到合适 section 时归入隐式 `Other` 区块，不能强行塞进不合适的 section

**绝对不能做：**
- 同一会话里混用 slide index 语义和 template section 语义（调用方必须明确传入哪一种结构）
- 因为找不到匹配 section 就跳过整条笔记（找不到匹配 ≠ 内容没价值，应该进 `Other`，而不是丢弃）

### 9.3 Inline AI Editing（`streamInlineEdit`）

**应该做：**
- 严格只输出"选中文字的改写结果"，不包含任何解释性前后缀（如"Here's the rewritten version:"）
- 参考 `documentContext` 理解上下文，但绝不在输出里重复或改写 context 部分
- 长度策略跟随动作类型：Shorten 必须比原文短；Expand 必须比原文长；其余动作不强制长度方向

**绝对不能做：**
- 输出 markdown 代码块包裹（如 \`\`\`）
- 引入选中文字和 context 之外的新事实
- 在没有用户明确指令（快捷动作或自定义文本）时主动生成内容

**边界情况处理：**

| 情况 | 期望行为 |
|---|---|
| 选区是空白或纯标点 | 不发起请求，pill 不出现（沿用 v1.1-r3 选区最小长度规则） |
| 选区跨越了一个 section 标题行 | 仍按用户实际选区原样处理，不自动排除标题行——这是用户自己的选择 |
| 自定义指令为空但用户直接回车 | 不发起请求，提示需要选择快捷动作或输入指令 |

---

## 10. Prompt Spec

### Template Structure Prompt（`generateTemplateStructure`，新增）

```
You are extracting a structured note-taking template from a user-provided document.

Document text:
{raw_text}

Identify the section headings the user wants to organize notes around (e.g. evaluation
criteria, agenda items, framework categories). For each section, write one guidance
sentence describing what kind of content belongs in it — specific enough to help a
future note-generation model decide whether a piece of transcript belongs here.

Output ONLY a JSON array (no markdown):
[
  { "index": 0, "title": "<section title>", "guidance": "<what belongs here>" },
  ...
]

If no clear section structure exists in the document, output an empty array.
```

**设计决策记录：**
- 为什么要求 guidance 而不是只要 title：标题本身（如"Market"）信息量不够，后续按 section 分流笔记时需要更具体的判断依据
- 为什么允许返回空数组：没有结构化文档时应该让用户退回手写模式，而不是让 AI 硬编出一个错误的结构

### Inline Edit Prompt（`streamInlineEdit`，新增）

```
You are editing one selected piece of text inside a note document. Edit ONLY the
selected text below. Do not include any explanation, prefix, or markdown formatting
in your output — output only the replacement text itself.

Surrounding document context (for understanding only, do NOT rewrite this part):
{document_context}

Selected text to edit:
{selected_text}

Instruction: {instruction}

Output only the rewritten version of the selected text.
```

**设计决策记录：**
- 为什么明确要求"不要重写 context"：模型容易把上下文也一起"顺手改写"，必须明确约束输出范围只对应选区
- 为什么不让模型输出解释：Replace 操作要把输出原样写回选区，任何额外文字都会污染笔记内容

---

## 11. Eval as Acceptance Criteria（新增部分）

### 11.1 Template Section Placement Eval

**方法：** 人工标注 10 条"transcript 片段 + 模板（5 个 section）+ 理想归属 section"的 golden dataset（参考 `PRODUCT_ROADMAP.md` §3.1 Notes Eval 的数据格式），评判 AI 实际选择的 section index 是否与人工标注一致。

**门控规则：** 归属准确率 < 80% → 不得合并对应 Prompt 改动。

### 11.2 Inline Edit Quality Eval

**方法：** GPT-4o 作为裁判，对 (原文, 指令, AI 输出) 三元组评分：

| 维度 | 定义 | 权重 |
|---|---|---|
| Instruction Adherence | 输出是否确实执行了指令（如 Shorten 是否真的更短） | 50% |
| Faithfulness | 是否引入了原文和指令之外的新信息 | 30% |
| Cleanliness | 是否包含解释性前后缀或 markdown 包裹 | 20% |

**门控规则：** 综合平均分 < 75 → 不得合并对应 Prompt 改动。

---

## 12. Failure Mode Spec（新增部分）

| 功能 | 失败情况 | 用户看到的 | 恢复路径 |
|---|---|---|---|
| Template 上传解析 | LLM 返回空数组 / 解析失败 | 提示"无法识别模板结构，可手动输入"，自动切换到手写模式 | 用户手写 section 列表，不阻塞开始录音 |
| Template 笔记归属 | 找不到匹配 section | 笔记静默归入文档末尾 `Other` 区块 | 不报错，用户可在 Other 区块看到内容并手动移动 |
| Inline Edit 生成失败 | API 超时/报错 | 卡片显示错误提示，Replace 按钮禁用 | 用户可点击重试，或直接 Discard |
| Inline Edit 输出异常 | 模型输出包含解释性前缀或 markdown 包裹 | 前端按规则尝试剥离常见包裹（如三引号代码块），剥离失败则禁用 Replace 并提示 | 用户点击 Discard，可重新发起一次请求 |

**设计原则沿用 v1.0 起的既定原则：** AI 功能出错永远不阻塞用户的核心流程（录音、转录、手动编辑笔记）。

---

## 13. Success Metrics（新增部分）

| 指标 | 定义 | 目标 |
|---|---|---|
| Template Adoption Rate | 新建会话中选择"Use a Template"的比例 | 上线 1 个月后 > 15%（非幻灯片场景的会话中占比更高） |
| Template Section Hit Rate | AI 笔记被分配到非 `Other` section 的比例 | > 80% |
| Inline Edit Usage per Session | 平均每场会话使用 Inline AI Editing 的次数 | > 1 次（验证功能被发现和使用） |
| Inline Edit Replace Rate | 发起 Inline Edit 后实际点击 Replace（而非 Discard）的比例 | > 60% |
| Style Guide Influence | 同一术语替换偏好出现后，后续生成内容采纳该偏好的比例（人工抽样核查） | 可观察到提升趋势即可，不设硬性阈值（数据量小，先观察） |

---

## 14. Files to Modify / Create

| 文件 | 改动 |
|---|---|
| `Grasp/Models/Models.swift` | 新增 `TemplateSection`；`Lecture` 增加 `structureType` |
| `Grasp/Services/DeepSeekService.swift` | 新增 `generateTemplateStructure(rawText:)`、`streamInlineEdit(selectedText:instruction:documentContext:onToken:)` |
| `Grasp/Services/SlideParserService.swift` | 复用文本抽取逻辑供模板文档解析调用，或抽出共享的文本提取函数 |
| `Grasp/Services/DatabaseService.swift` | 新表 `templates`；`lectures` 表增加 `structure_type` 列迁移 |
| `Grasp/Views/Modals/NewLectureModalView.swift` | 新增 "Use a Template" 路径：手写输入 / 已保存模板选择 / 上传文档 |
| `Grasp/Views/Notes/NotesPanelView.swift` | 模板模式下会话开始即插入全部 section 标题；新增划词后的 "Edit with AI" pill 与展开卡片；新增"仅替换选区"的写入路径 |
| `Grasp/Views/Transcript/SelectionPopupView.swift` | 参考其 pill 样式实现 Notes 面板的新选区 pill（建议新建 `NotesSelectionPopupView.swift` 而不是直接复用，因为按钮集合完全不同） |
| `Grasp/ViewModels/AppViewModel.swift` | 模板状态管理、Inline Edit 触发与 Replace 写入逻辑、`inferNoteStyleGuide` 输入扩展 |

---

## 15. Open Questions

| 问题 | 影响范围 | 决策截止 | 负责人 |
|---|---|---|---|
| 模板 section 标题在文档中具体用什么排版区分（加粗 / 字号 / 颜色）？ | NotesPanelView 视觉实现 | Engineer 实现前由 PM 出 UI spec | PM |
| `inferNoteStyleGuide` 积累足够 Inline Edit 样本后，是否应该从启发式升级为调用 LLM 总结风格规律？ | Personalized Memory 长期演进 | 上线 1 个月、积累真实样本后评估 | Eng |
| 模板与幻灯片是否应该允许同时使用（如上传幻灯片的同时也指定一个评估模板）？v1.3 当前设计是互斥 | Template-driven Notes 范围 | 有真实用户反馈后再评估 | PM |
| README / 根目录 PRD 的产品定位重写，是否需要同步改动 App 内 Onboarding 文案？ | Onboarding 一致性 | 与 v1.3 实现同批上线 | PM |
