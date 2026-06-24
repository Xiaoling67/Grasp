# Grasp · Product Requirements Document
**macOS AI Lecture Assistant · v1**
Last updated: 2026-06-08

---

## 1. Problem Statement

大学课堂的信息密度极高，学生同时要做三件互相冲突的事：听讲、理解、记录。
这三件事争夺同一块认知资源，结果是每一件都做不好。

**具体痛点：**

| 场景 | 现实 | 现有方案的缺陷 |
|---|---|---|
| 教授讲得很快 | 手写笔记跟不上，只能记关键词，课后看不懂 | 录音回放太耗时；ChatGPT 没有课堂上下文 |
| 出现不懂的词 | 要么忍着不查（错过后续内容），要么掏手机（打断专注） | Google 结果与当前课堂内容无关 |
| 重要金句/公式 | 要一边听一边手动抄，经常来不及 | 没有工具支持"划词即存" |
| 教授突然 cold call | 没有任何辅助，只能凭已有知识硬答 | 无针对性工具 |
| 留学生全英文授课 | 语言障碍导致理解滞后，笔记更无从谈起 | 通用翻译 App 无课堂上下文 |

**核心洞察：** 学生不需要课后总结工具——他们需要的是**课堂实时认知辅助层**，
在不打断听课状态的前提下，处理掉所有需要额外认知资源的任务。

---

## 2. Target Users

**Primary: Standard Mode 用户**
英语母语大学生，课程内容密度高（STEM / 商科 / 法律），希望提升笔记质量和课堂理解。

**Secondary: International Mode 用户**
非英语母语留学生，全英文授课环境，同时面对语言障碍和内容理解两重挑战。

**Non-users（不是我们的用户）：**
- 录播课学生（不是实时场景）
- 高中生（课堂节奏较慢，痛点不够尖锐）
- 教授（视角不同，需求不同）

---

## 3. Goals & Non-Goals

### Goals（v1 必须做到）
- 学生在课堂上无需手动记笔记，AI 自动生成的笔记质量足以用于复习
- 划词搜索的结果比 Google 更快、更贴合当前课堂语境
- International 用户能跟上全英文授课的节奏
- Cold call 发生时，学生能在 5 秒内看到参考答案

### Non-Goals（v1 明确不做）
- 课后作业辅助、考前复习功能（不是课堂场景）
- 多人协作笔记
- 录播课 / 视频课支持
- 移动端（iOS/Android）
- 与学校教务系统的双向写入（Canvas 只读）
- 离线模式（所有 AI 功能依赖网络）

---

## 4. User Stories

### Story 1: 核心笔记场景
> 作为一名商科学生，我在上 Corporate Finance 课时，
> 我希望 AI 能自动把教授说的关键点记录成笔记，按幻灯片章节组织，
> 这样我可以专心听讲，课后直接用这份笔记复习，不需要重新整理。

**验收条件：**
- 笔记按 slide 章节组织，不是按时间流
- 每条笔记 ≤ 20 词，简洁可读
- 笔记覆盖教授强调的核心概念，不是无关细节
- 用户可随时编辑、增删任意笔记条目

### Story 2: 划词搜索场景
> 作为一名 CS 学生，我在上 Distributed Systems 课时听到"Byzantine fault tolerance"，
> 我希望划词后立刻看到一个结合当前课堂上下文的解释，
> 这样我不需要切换到浏览器，也不会打断听课。

**验收条件：**
- 从划词到开始显示结果 < 1 秒（streaming 开始）
- 解释明确基于当前课堂内容，不是通用百科定义
- 附一个零先验知识的人也能理解的生活类比
- 结果可以一键保存

### Story 3: 留学生翻译场景
> 作为一名来自中国的留学生，我在上 Macroeconomics 课，
> 我希望每段英文转录下面自动出现中文译文，
> 这样在语言障碍的情况下我也能跟上课堂节奏。

**验收条件：**
- 中文译文出现在对应 Block 的英文下方
- 专业术语翻译与课程约定一致（如 GDP 保留英文，"边际效用"用统一译法）
- 翻译展示可在 Settings 一键关闭，不影响其他功能

### Story 4: Cold Call 场景
> 作为一名法学院学生，教授突然点名让我解释某个法律概念，
> 我希望 AI 能立刻给我一个基于本节课内容的参考答案，
> 这样我不会因为紧张或遗忘而在课上出丑。

**验收条件：**
- 检测到教授提问后，卡片自动弹出
- 答案严格基于本节课已讲内容，不引入课外知识
- 包含短答案（≤ 60 词）+ 2 条支撑论点
- 从检测到答案显示完整 < 5 秒

### Story 5: 课后复习场景
> 作为一名学生，课后我希望回顾这节课，
> 找到我收藏的所有知识点和搜索记录，并能导出成 Word 文档。

**验收条件：**
- 历史课程在 Transcript / Saved / Searches 三个子页面展示完整记录
- Export 支持按内容类型选择导出项
- 课程名称支持重命名

---

## 5. Requirements

### P0 — 必须有，没有就不能上线

| # | 需求 | 验收标准 |
|---|---|---|
| P0-1 | 实时语音转录，逐词显示 | 延迟 < 500ms，英文识别准确率 > 90% |
| P0-2 | 语义 Block 自动分段封存 | 封存规则正确：句末停顿 + 50-100 词区间 |
| P0-3 | AI 笔记实时生成，按 slide 章节组织 | Notes Eval 平均分 ≥ 75（见 Section 8） |
| P0-4 | 划词弹出菜单（Save / Search） | 点击 Block 和拖拽选择均可触发 |
| P0-5 | AI Search 流式输出 | 首 token 延迟 < 1s，超时 8s 自动重试 1 次 |
| P0-6 | Save Knowledge，一键保存 | 保存无需二次确认，立即写入 DB |
| P0-7 | 幻灯片上传与结构解析 | SlideItem 包含 title + concepts + keywords |
| P0-8 | 历史课程查阅（Transcript / Saved / Searches） | 数据完整，支持按类型过滤 |

### P1 — 应该有，影响核心体验但有 workaround

| # | 需求 | 验收标准 |
|---|---|---|
| P1-1 | Cold Call 自动检测与答案生成 | Detection Precision ≥ 0.80；Groundedness ≥ 0.65 |
| P1-2 | International 模式：Block 封存后自动翻译 | 译文延迟 P95 < 3s；专业术语正确率人工核查 |
| P1-3 | International 模式：Save Language 类型 | 独立类型标记，在 Saved Items 可按类型过滤 |
| P1-4 | 开课关键词注入 Deepgram | 专业术语 WER 相比不注入有可测量改善 |
| P1-5 | Session 级搜索缓存 | 同一课堂内重复搜索同一词返回缓存，不再调用 API |
| P1-6 | Export 导出为 .docx | 内容可选，⌘⇧X 触发 |

### P2 — 可以有，锦上添花

| # | 需求 | 验收标准 |
|---|---|---|
| P2-1 | MemoryService：历史收藏注入 Search Context | Search Engagement Rate 环比提升 |
| P2-2 | Search 追问（Follow-up questions） | 支持多轮对话，context 保留前序问答 |
| P2-3 | Canvas LMS 集成 | OAuth 连接；Search 结果显示相关作业截止日期 |
| P2-4 | Cold Call LLM 检测替代正则 | Detection Precision 从基线提升 |

---

## 6. UX Flow

### Flow 1: 开始一节课

```
点击 New Lecture
    → 填写课程名称 + subject（必填）
    → 选择 mode（Standard / International）
    → 可选：上传 PDF 幻灯片
         → SlideAgent 解析幻灯片结构（后台，不阻塞录音开始）
    → 点击 Start Recording
         → LLM 生成 20 个领域关键词，注入 Deepgram
         → 开始转录，逐词显示
         → AI 笔记面板在右侧出现（若有 slides）
```

### Flow 2: 课堂中使用 Search

```
听到不懂的词
    → 点击 Block 或拖拽选择文字
    → 弹出菜单：[ Save ] | [ Search ]
    → 点击 Search（⌘⇧E）
         → SearchCard 出现在底部面板
         → 流式输出：定义（≤50词）| 类比（≤25词）
         → 可选：点击 Save 保存此结果
    → 按 Esc 或点击其他区域关闭
```

### Flow 3: Cold Call 触发

```
教授说 "Who can tell me..."
    → ColdCallAgent 检测到提问模式
    → ColdCall 卡片弹出：显示检测到的问题
    → 两个选项：
         [Generate Answer]  →  AI 生成答案，显示 shortAnswer + supportingPoints
         [Dismiss]          →  关闭卡片
    → 答案显示后：
         [Save to Notes]    →  写入 note_blocks
         [Dismiss]          →  关闭
```

### Flow 4: 结束课程 & 课后复习

```
点击 Stop Recording
    → 当前 Block 封存
    → 课程记录出现在侧边栏历史列表
    → 点击打开：Transcript / Saved / Searches 三个 Tab
    → 可选：Export（⌘⇧X）→ 选择导出内容 → 下载 .docx
```

---

## 7. Model Behavior Spec

> 这一节定义每个 AI 功能"应该做什么"和"绝对不能做什么"。
> 这是 Prompt 设计和 Eval 的共同依据。

### 7.1 AI Search

**应该做：**
- 用一句话直接定义被搜索的词，从词本身开始（"NPV is..."）
- 定义基于课堂 context，但可以补充通用知识
- 附一个零先验知识的人也能理解的生活类比
- 如果选中的是句子而非单词，解释核心概念

**绝对不能做：**
- 以"教授说"、"In this lecture"、"The transcript mentions"开头（meta-reference）
- 输出超过 2 句话（格式严格：定义 | 类比）
- 引入与课堂或词汇无关的信息
- 输出 markdown 格式（**粗体**、列表等）

**边界情况处理：**

| 情况 | 期望行为 |
|---|---|
| 选中文字是问句 | 解释问句描述的核心概念 |
| 选中文字是乱码 / 无意义 | 输出空结果，不编造解释 |
| subject 为空 | 使用通用大学课程语境 |
| transcript context 为空 | 给出通用定义，不拒绝回答 |

### 7.2 AI Notes

**应该做：**
- 每次只生成一条笔记（append 模式，非重写）
- 内容 ≤ 20 词，简洁精准
- slideIndex 映射到当前教授正在讲的章节
- level 0 = 核心概念（慎用），level 1 = 支撑点（默认），level 2 = 细节举例

**绝对不能做：**
- 重复已有笔记的内容（语义重复）
- 捏造 transcript 中没有出现的知识点
- 生成超过 20 词的笔记条目
- 输出任何 JSON 格式以外的内容（非结构化输出直接丢弃）

**边界情况处理：**

| 情况 | 期望行为 |
|---|---|
| Transcript 只有过渡性语言（"so, uh, moving on..."） | 返回 null，不生成笔记 |
| 无幻灯片上传 | slideIndex 统一为 0，正常生成 |
| Transcript 与上一条笔记内容高度重复 | 跳过本次生成 |

### 7.3 Cold Call

**应该做：**
- 答案严格基于本节课 transcript + 已生成笔记
- shortAnswer ≤ 60 词
- supportingPoints 每条必须能在 transcript 中找到来源
- questionType 准确分类（概念解释 / 应用分析 / 观点表达 / 知识回忆）

**绝对不能做：**
- 引入 transcript 中未提及的知识（即使是正确的通用知识）
- 答案超过 2 条 supportingPoints
- 在没有任何课堂 context 的情况下仍然生成答案（应提示"内容不足"）

**边界情况处理：**

| 情况 | 期望行为 |
|---|---|
| 检测到提问但 transcript < 3 个 Block | 弹出卡片但禁用 Generate，显示"需要更多课堂内容" |
| 问题与课堂内容完全无关 | 生成答案但标注"本课暂未涉及此内容" |
| 重复检测（90 秒内再次触发） | 忽略，不重复弹卡片 |

### 7.4 Translation

**应该做：**
- 忠实翻译，不增减原文信息
- 专业术语按课程约定统一译法
- 译文通顺，符合中文表达习惯

**绝对不能做：**
- 意译到改变原意
- 把英文专有名词随意翻译（NPV 应保留或统一译为"净现值"，不能有时译"净值"有时译"现值"）

---

## 8. Prompt Spec

> Prompt 是产品逻辑，和代码一样需要版本管理。
> 修改 Prompt = 修改产品，必须经过 Eval 验收才能合并。

### Search Prompt（当前部署版本 v2）

```
You are a concise study-card generator. A student highlighted a term during a
university lecture and needs an instant explanation.

Course: {subject}
Recent lecture transcript (for context only):
{context}            ← 选中位置之前的 10 个 Block
Term to explain: "{query}"

Rules:
- Output exactly 2 sentences separated by " | ". No headers, no labels, no markdown.
- NEVER start with "The professor", "In this lecture", "The transcript",
  "As mentioned", or any meta-reference.
- If the highlighted text is a phrase or concept rather than a single term,
  explain the core idea directly.

Sentence 1 (max 50 words): Direct definition of "{query}" grounded in lecture context.
                            Start with the term itself.
Sentence 2 (max 25 words): One concrete everyday analogy. Zero jargon.
                            Assume no prior knowledge of {subject}.
```

**设计决策记录：**
- 为什么禁止 meta-reference：定义应自包含，"教授在讲课中提到"这类措辞让定义依赖上下文，无法单独复习
- 为什么是 50+25 而非更长：SearchCard 是浮层，不是文章，字数越少越快阅读完
- 为什么用 " | " 分隔：便于前端 split 解析，分别渲染定义和类比两块 UI

### Notes Prompt（含 slides，当前部署版本 v1）

```
You are taking notes for a live university lecture on "{subject}".

Course structure:
{slide_structure}    ← SlideItem 列表

Recent transcript:
{recent_transcript}  ← 最近 3 个 Block

Generate ONE concise note entry based on the most recent key point.
Output ONLY a JSON object (no markdown):
{ "slideIndex": <one of: {valid_indices}>,
  "content": "<concise phrase or sentence, under 20 words>",
  "level": <0, 1, or 2> }

level 0 = main concept (use sparingly)
level 1 = supporting point (default)
level 2 = specific detail or example
slideIndex must match which slide topic the professor is currently discussing.
```

**设计决策记录：**
- 为什么只用最近 3 个 Block：Notes 要追踪当前进展，不是总结全课，窗口太大会"回头"生成已有的笔记
- 为什么 JSON 输出：便于解析 slideIndex 和 level，纯文本无法结构化映射到章节

### Cold Call Prompt（当前部署版本 v1）

```
You are a real-time study assistant helping a student answer a cold-call question
during a live university lecture.

Course: {subject}
Course topics covered:
{slide_structure}

Recent transcript (chronological):
{recent_transcript}   ← 最近 15 个 Block

The professor just asked: "{question}"

Based ONLY on what was discussed in the lecture transcript above, generate a helpful answer.
Do NOT introduce knowledge beyond what was mentioned in the lecture.

Output ONLY a JSON object (no markdown):
{
  "questionType": "<Concept Explanation | Applied Analysis | Opinion Expression | Recall>",
  "shortAnswer": "<2-3 sentences, max 60 words>",
  "supportingPoints": ["<point from lecture>", "<point from lecture>"]
}
```

**设计决策记录：**
- 为什么限制"只能用课堂内容"：Cold Call 的价值是帮学生用课上学的知识回答，不是开卷考试
- 为什么是 15 个 Block 而非全部：全部 transcript 会超出 context，且越近的内容越相关

---

## 9. Eval as Acceptance Criteria

> 这是 AI 功能的 QA 标准。每次修改对应功能的 Prompt 或模型参数，
> 必须先跑 Eval，通过后方可合并。

### 9.1 Notes Eval

**方法：** GPT-4o 作为裁判，评分维度如下：

| 维度 | 定义 | 权重 |
|---|---|---|
| Accuracy | 笔记内容与 transcript 一致，无幻觉 | 40% |
| Coverage | 最核心概念是否被记录 | 40% |
| Conciseness | 是否在 20 词以内 | 20% |

**门控规则：** 综合平均分 < 75 → 本次 Prompt 修改不得合并

**Golden Dataset：** 手写 10 条标准样本（覆盖 Finance / CS / History 三类学科），
每条包含：slide_structure + transcript 片段 + 理想笔记输出

### 9.2 Cold Call Groundedness Eval

**方法：** 自动化脚本扫描答案中的核心论点，在 transcript 中检索依据

```python
def groundedness(answer: str, transcript: str) -> float:
    claims = extract_noun_phrases(answer)
    grounded = sum(1 for c in claims if c.lower() in transcript.lower())
    return grounded / len(claims) if claims else 0
```

**门控规则：** Groundedness < 0.65 → 回滚

### 9.3 Search 隐式 Eval（用户行为）

**埋点规则：**

| 事件 | 记录 |
|---|---|
| 用户在 SearchCard 停留 > 3 秒 | `engaged = 1` |
| 用户点击 Save | `engaged = 1` |
| 用户在 5 秒内关闭 | `dismissed_at = now()`，视为负信号 |

**门控规则：**
- Engagement Rate 环比下降 > 5% → 人工 Review
- Bounce Rate 环比上升 > 10% → 回滚

### 9.4 全局 Eval 门控表

| Feature | 指标 | 门控阈值 | 运行时机 |
|---|---|---|---|
| Notes | Accuracy + Coverage 综合分 | < 75 → 不合并 | 每次改 Notes Prompt |
| Cold Call | Groundedness | < 0.65 → 回滚 | 每次改 ColdCall Prompt |
| Cold Call | Detection Precision | < 0.80 → 回滚 | 每次改检测逻辑 |
| Search | Engagement Rate | 环比 -5% → Review | 每次改 Search Prompt |
| Translation | Latency P95 | > 3s → 优化 | 每次换翻译模型 |

---

## 10. Failure Mode Spec

> AI 一定会出错。这一节定义出错时用户看到什么，以及如何恢复。

| 功能 | 失败情况 | 用户看到的 | 恢复路径 |
|---|---|---|---|
| **Transcription** | Deepgram 断连 | 状态栏显示"Reconnecting..."，10 秒后自动重连 | 自动重连，最多 3 次；失败后提示手动重启 |
| **AI Search** | API 超时（> 8s） | "Search failed. Check your connection." | 自动重试 1 次；仍失败显示错误，用户可手动重试 |
| **AI Search** | 输出格式错误（无" \| "分隔） | 整体作为 Sentence 1 显示，Sentence 2 为空 | 不报错，静默降级 |
| **AI Notes** | JSON 解析失败 | 本次不生成笔记，下一个 Block 正常继续 | 静默跳过，不打断用户 |
| **AI Notes** | 生成内容为空或全空格 | 同上，静默跳过 | — |
| **Cold Call** | 生成答案失败 | 卡片消失，Toast 提示"Could not generate answer" | 用户可点击"Retry"重新生成 |
| **Cold Call** | 误触发（非学术提问） | 卡片弹出，用户点 Dismiss | 用户主动关闭，90 秒内不再触发 |
| **Translation** | 翻译 API 失败 | Block 下方无中文，Block 正常显示英文 | 静默降级，不影响转录；用户可在设置里重试 |
| **Slide 解析** | max_tokens 截断 | 后面几张 slides 的 SlideItem 缺少 concepts | 仍然可以开始录音，Notes 在无 slide 信息的章节退化为 slideIndex=0 |

**设计原则：** AI 功能出错时，永远不阻塞用户的核心流程（录音和转录）。
所有 AI 功能出错都是静默降级或 Toast 提示，不弹 modal，不要求用户操作才能继续。

---

## 11. Success Metrics

### North Star Metric
**每节课的 AI 笔记被用户保留（未删除）的条目比例**

> 如果学生保留了 AI 生成的笔记，说明笔记是有用的。
> 如果大量删除，说明质量不达标或不符合笔记风格。

目标：笔记保留率 > 60%

### Supporting Metrics

| 指标 | 定义 | 目标 |
|---|---|---|
| Search Engagement Rate | 搜索后用户有交互行为（停留/保存）的比例 | > 40% |
| Cold Call Trigger-to-Use Rate | 检测到提问后用户点击 Generate 的比例 | > 50% |
| Session Length | 单次录音时长（越长说明用户持续使用） | 中位数 > 30 分钟 |
| Save per Session | 每节课平均保存条目数 | > 3 条 |
| International Mode Retention | International 模式用户第 2 次使用的比例 | > 60% |

### Anti-Metrics（不应该上升的指标）
- Cold Call 误触发率（教授不在提问时卡片弹出的比例）
- Search Bounce Rate（搜索后 5 秒内关闭）
- 用户手动删除 AI 笔记的比例

---

## 12. Open Questions

| 问题 | 影响范围 | 决策截止 | 负责人 |
|---|---|---|---|
| Search 是否支持追问（Follow-up）？需要多轮对话架构，UI 设计未确定 | Search UX，P2 | 有第一批用户后做访谈再决定 | PM |
| Cold Call 检测是否升级为 LLM 二分类替代正则？需要 Detection Eval 基线数据 | ColdCall Precision | 有 20 条标注样本后 | Eng |
| Notes 的 slideIndex 映射是否引入 Embedding 提升准确率？需要评估 infra 成本 | Notes Accuracy | Notes Eval 平均分稳定后评估 | Eng |
| Canvas LMS 集成优先级？需要用户调研验证需求真实性 | Phase 4 | 有 50 名用户后做问卷 | PM |
| Export 的 .docx 格式是否是用户真实需求，还是 PDF/Markdown 更常用？ | Export 格式 | 上线前用户访谈 3 人 | PM |
