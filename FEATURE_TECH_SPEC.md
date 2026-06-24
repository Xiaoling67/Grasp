# Grasp · Feature × Technical Architecture Spec
**macOS AI Lecture Assistant · v1**

> 本文档将产品功能规格与三个技术框架（Multi-Agent / Evals / MCP）统一描述，
> 作为产品迭代和技术决策的单一参考来源。

---

## 产品定位

Grasp 是一款面向在校学生的 macOS 桌面 AI 课堂助手，解决以下核心痛点：

| 痛点 | 功能 | 功能简介 |
|---|---|---|
| 跟不上课堂语速，难以记下高质量、重点突出的 notes | **AI Notes** | 实时解析 slides 结构，课上自动生成按章节组织的增量笔记 |
| 课堂中遇到不懂的概念需要立刻查，但查手机/Google 会打断专注 | **AI Search** | 划词即搜，结合课堂 transcript 给出定义 + 类比，流式输出 |
| 难以把所有重点、金句记录下来，课后复习没有依据 | **Save** | 划词即存，自动翻译，支持添加备注，跨课可检索 |
| 教授突然提问不会答，影响课堂参与分 | **Cold Call** | 自动识别教授提问，实时生成基于课堂内容的参考答案 |
| 留学生语言障碍，难以跟上全英文授课 | **实时转录 + 翻译** | 逐词显示英文转录，Block 完成后自动追加中文译文 |

### 支持模式

| Mode | 目标用户 | 功能 |
|---|---|---|
| Standard | 英语母语学生 | 实时转录 · AI 笔记 · AI 搜索 · 手动收藏 |
| International | 非英语母语学生 | Standard 全部功能 + 实时翻译 + 词汇/语言类收藏 |

---

## 全局速览

| Feature | Owner Agent | 核心 Eval 指标 | MCP Tool |
|---|---|---|---|
| Transcript 实时转录 | — (ASR，非LLM) | Word Error Rate · Block Seal Latency | — |
| Notes 笔记生成 | `NoteAgent` | Accuracy + Coverage (Judge 评分) | `CourseNotesTool` |
| Search 词汇解释 | `SearchAgent` | Engagement Rate · Bounce Rate | `SavedItemsTool` + `CanvasTool` |
| Cold Call 课堂提问 | `ColdCallAgent` | Groundedness · Detection Precision | `CourseNotesTool` |
| Translation 实时翻译 | `TranslationAgent` | Terminology Accuracy · Latency P95 | — |
| Saved Items 收藏 | — (数据层) | Memory Hit Rate · Cross-Lecture Hit | `SavedItemsTool` |
| Slide Structure 幻灯片解析 | `SlideAgent` | Structural Fidelity · Keyword Coverage | — |

---

## Feature 1: Transcript 实时转录

### 产品规格

- **逐词显示**：每个识别词立即渲染到屏幕，不等句子完成。目标延迟 < 500ms，识别准确率 > 90%。
- **语义分块（Block）规则**：
  - 触发封存：句末标点 + 停顿 ≥ 500ms
  - 强制封存：词数达到上限 100 词
  - 封存许可：词数 ≥ 50 词时方可触发封存（不满 50 词不封存）
- **视图行为**：默认展示最近 5 个 Block；用户未交互时视图固定不滚动。
- **开课关键词注入**：录音开始时，用课程 subject 调用 LLM 生成 20 个领域专属关键词，传入 Deepgram 的 `keywords` 参数，提升专业术语识别准确率（一次性调用，非逐 Block 触发）。

### Multi-Agent

Transcript 不经过 LLM，由 `DeepgramService` 直接产出，是所有 Agent 的原始数据源。
架构中的角色：**数据入口层，非 Agent**。

```
Microphone → AudioService → DeepgramService → Block (sealed)
                                                    ↓
                                  NoteAgent / SearchAgent / ColdCallAgent
```

**开课关键词注入调用链：**
```
startLecture()
    ↓
LLMClient.call(
  prompt: "Generate 20 domain keywords for: {subject}",
  maxTokens: 80
) → ["elasticity", "NPV", "marginal cost", ...]
    ↓
DeepgramService.connect(sr:, keywords: [...])
```

### Evals

| 指标 | 定义 | 测量方式 |
|---|---|---|
| Word Error Rate (WER) | 转录词与实际词的偏差率 | 人工对照录音逐字校对，5 段样本 |
| WER（专业术语子集） | 领域词汇的识别准确率（注入关键词前后对比） | 注入前后各录 3 段同类课程对比 |
| Block Seal Latency | 从说完到 Block 封存的延迟 | App 日志时间戳差值，P95 目标 < 2s |

### MCP
暂无。Transcript 是数据产出方，不是消费方。

---

## Feature 2: AI Notes 笔记生成

### 产品规格

**课前准备：** 上课前上传课程幻灯片。录音开始前，`SlideAgent` 解析幻灯片全文，提取课程结构图（章节 + 概念 + 关键词），存入 `lecture_slides` 表，作为笔记系统的骨架。

**课中实时生成：** 每次 Block 封存后 500ms，`NoteAgent` 读取最近 transcript chunk + 对应章节上下文，生成一条增量笔记（`slideIndex` + `content` + `level`），追加到 `note_blocks`。
- 笔记以 append 方式增量写入，不重写全文
- 每条笔记绑定 `id` 和 `source`（`ai` 或 `user`），用户编辑直接写回同一结构化 Block
- 按幻灯片章节组织，实时跟随课程进度更新

**面板布局：** 笔记面板位于 transcript 面板右侧，双栏并排，右栏可折叠。

**用户编辑：** 用户可随时编辑、增添或删除任意笔记条目，编辑后 `source` 改为 `user`。

**课后保存：** 笔记完整保留，在过去课程记录中可查阅和导出。

**V2 升级方向（当前不实现）：** 引入 embedding 将当前讲述内容对齐到对应 slide 章节，替代当前 LLM 猜测 `slideIndex` 的方式，提升映射准确率。此项需要向量库基础设施，待有真实用户数据后评估必要性。

### Multi-Agent

**Owner: `NoteAgent`**

```
Block sealed
    ↓ (500ms debounce)
NoteAgent.generate(
  slides: [SlideItem],     // 当前课幻灯片结构（课程地图）
  recent: [Block],         // 最近 3 个 Block（当前讲述 chunk）
  subject: String
) → NoteEntry { slideIndex, content, level }
    ↓
append to note_blocks (id, source="ai", level 0/1/2)
```

**NoteAgent 独立的意义：**
笔记 Prompt 需要严格控制在 20 词以内、按 level 分级、映射到 slideIndex。
与 SearchAgent 分离后，任一侧的 Prompt 调整不影响另一侧。

**未来独立升级方向：**
- 切换更快的模型降低生成延迟（Notes 对延迟不如 Search 敏感）
- 增加重复检测：新笔记与已有笔记语义重复则跳过
- 增加重要性权重：教授重复 3 次以上的概念自动标为 level 0

### Evals

**Golden Dataset 格式：**
```json
{
  "id": "notes_001",
  "subject": "Microeconomics",
  "slides": [{ "index": 2, "title": "Price Elasticity", "concepts": ["PED", "demand curve"] }],
  "transcript": "So if the price goes up by 10% and demand drops by 20%, elasticity is 2...",
  "ideal": {
    "content": "Price elasticity = % demand change ÷ % price change",
    "level": 0,
    "slide_index": 2
  }
}
```

**评判维度（GPT-4o as Judge）：**

| 维度 | 定义 | 满分 |
|---|---|---|
| Accuracy | 笔记内容与 transcript 一致，无幻觉 | 40 分 |
| Coverage | 最核心概念是否被记录 | 40 分 |
| Conciseness | 是否在 20 词以内 | 20 分 |

**门控规则：** 平均分 < 75 → Prompt 不得合并。

### MCP

**`CourseNotesTool`（内部工具）**

ColdCallAgent 生成答案时调用，获取"本课已生成的笔记摘要"，
避免 Cold Call 答案与已记录笔记自相矛盾，弥补时间窗口盲区。

```
CourseNotesTool.call({ "lecture_id": "xxx" })
→ "Key concepts noted so far: price elasticity, PED formula, demand curve shift..."
```

---

## Feature 3: AI Search 词汇解释

### 产品规格

**触发方式（两种）：**
- 点击语义 Block：选中整个 Block，弹出操作菜单
- 点击拖拽：选中任意文字片段，弹出操作菜单

**弹出菜单（按模式）：**

| 模式 | 菜单 |
|---|---|
| Standard | `[ Save ]` ｜ `[ Search ]` |
| International | `[ K ]` `[ L ]` ｜ `[ Search ]` |

K = Save as Knowledge，L = Save as Language。按 Esc 或点击菜单外区域关闭。

**快捷键：**
- ⌘⇧K — Save Knowledge
- ⌘⇧L — Save Language（International 模式）
- ⌘⇧E — AI Search

**搜索输出：**

| 部分 | 内容 | 字数上限 |
|---|---|---|
| Sentence 1 | 结合课堂 context 的直接定义，以术语本身开头 | ≤ 50 词 |
| Sentence 2 | 具体的生活类比，零先验知识的读者也能理解，无术语 | ≤ 25 词 |

- 流式输出，实时渲染
- Context：选中位置之前的 10 个语义 Block
- Session 级缓存：同一课堂内重复搜索同一词直接返回缓存结果
- 超时 8 秒，自动重试 1 次
- 所有记录持久化，在 Search History 页面全局可搜索

**当前部署 Prompt（V2）：**
```
You are a concise study-card generator. A student highlighted a term during a
university lecture and needs an instant explanation.

Course: {subject}
Recent lecture transcript (for context only):
{context}
Term to explain: "{query}"

Rules:
- Output exactly 2 sentences separated by " | ". No headers, no labels, no markdown.
- NEVER start with "The professor", "In this lecture", "The transcript",
  "As mentioned", or any meta-reference to the lecture or speaker.
- If the highlighted text is a phrase or concept rather than a single term,
  explain the core idea directly.

Sentence 1 (max 50 words): A direct, self-contained definition of "{query}"
grounded in the lecture context. Start with the term itself or a direct statement.
Sentence 2 (max 25 words): One concrete everyday analogy for someone with zero
prior knowledge of {subject}. No jargon.
```

**V2 说明：** 当前代码已部署 V2。相比 V1，V2 去掉了 meta-reference 禁令
（不得以"教授说"开头），使定义更直接、自包含，与课堂 transcript 解耦。

### Multi-Agent

**Owner: `SearchAgent`**

```
User selects text  (⌘⇧E)
    ↓
MemoryService.buildContext(query, lectureId)
    → relatedSaves: [SavedCard]       // 历史收藏中关键词匹配的条目
    → relatedSearches: [SearchResult] // 历史搜索中相关的查询
    → courseKeywords: [String]        // 当前课 SlideItem.keywords 合集
    ↓
SearchAgent.stream(
  query: String,
  transcript: [Block],      // 最近 10 个 Block
  memory: MemoryContext,    // 来自 MemoryService
  subject: String
) → streaming tokens
```

**Memory 注入后的 Prompt 扩展（Phase 1）：**
```
[Memory block，仅当有相关内容时追加]
Related concepts you've saved before:
- "IRR" (from Intro to Finance, Oct 3): Internal rate of return, the discount rate...

Previously searched related terms in this course:
- "discount rate": the interest rate used to compute present value...

Rule (new): If memory context is provided, add ONE optional sentence at the end
connecting the current term to a related saved concept.
```

**Memory 注入后的体验示例：**
> "NPV is the sum of all future cash flows discounted to present value.
> Like deciding if a lottery ticket is worth buying today based on its future payout.
> **This connects to 'IRR' you saved from Intro to Finance — both measure investment value via discounting.**"

### Evals

| 指标 | 定义 | 测量方式 |
|---|---|---|
| **Engagement Rate** | 用户看完后有后续行为的比例 | `engaged / total`，从 DB 统计 |
| **Bounce Rate** | 5 秒内关闭且无交互的比例 | `dismissed_at NOT NULL AND engaged = 0` |
| **Memory Hit Rate** | Search 时 MemoryContext 有命中的比例 | MemoryService 日志统计 |
| **Cross-Lecture Rate** | 命中的 relatedSaves 来自不同课程的比例 | lectureId 不同的命中数 / 总命中数 |

**隐式 Eval 触发规则（需在 App 中埋点）：**
- 用户在 SearchCard 停留 > 3 秒 → `engaged = 1`
- 用户点击 Save → `engaged = 1`
- 用户在 5 秒内关闭 → `dismissed_at = now()`，视为负信号

**门控规则：** Engagement Rate 环比下降 > 5% 或 Bounce Rate 上升 > 10% → 人工 Review。

### MCP

**`SavedItemsTool`（内部，Phase 1）**
```
SavedItemsTool.call({ "keywords": ["NPV", "discounted"], "exclude_lecture": "current_id" })
→ "From Intro to Finance (Oct 3): 'IRR' — Internal rate of return..."
```

**`CanvasTool`（外部，Phase 4）**
```
CanvasTool.call({ "keywords": ["NPV", "discounted cash flow"] })
→ "Finance HW3 (due Tue Oct 15): Evaluate NPV and IRR for the capital budgeting case"
```

SearchCard 底部呈现（仅 Canvas 已连接且有相关作业时）：
```
────────────────────────────────────
📅  Canvas 关联：Finance HW3 · 下周二截止
    "Evaluate NPV and IRR for the capital budgeting case"
────────────────────────────────────
```

---

## Feature 4: Cold Call 课堂提问辅助

### 产品规格

**功能定位：** 课堂实时认知辅助层，而非开放式问答系统。所有生成内容严格受限于当前课堂上下文。

**核心流程：**
1. **实时问题检测**：区分陈述 vs 提问 vs cold call 场景
2. **问题意图分类**：概念解释 / 应用分析 / 观点表达 / 知识回忆
3. **课堂内容检索**：从 slides + transcript + 课程笔记摘要中定位相关内容
4. **答案生成**：仅基于课堂已讲内容，输出短答案 + 支撑论点
5. **输出格式**：`questionType` + `shortAnswer`（≤ 60 词）+ `supportingPoints`（2 条，来自 transcript）

**当前检测方式（V1）：** 正则表达式匹配提问模式（"who can tell me..."，"does anyone know..."）

**V2 改进方向：** 用 LLM 对每个 Block 做二分类（是否是学术提问，max_tokens=5），
替代正则，解决误触发（"who knows where the bathroom is"）和中文课程不触发的问题。

### Multi-Agent

**Owner: `ColdCallAgent`**（当前检测逻辑在 AppViewModel，应迁移）

```
Block sealed
    ↓
ColdCallAgent.detect(text)
    → nil (非提问) / String (提取的问题)
    ↓ (用户确认 / 自动触发)
CourseNotesTool.call({ "lecture_id": lid })  → 全课笔记摘要
    ↓
ColdCallAgent.generate(
  question: String,
  transcript: [Block],    // 最近 15 个 Block（当前时间窗口）
  slides: [SlideItem],    // 课程章节结构
  courseNotes: String,    // 全课笔记摘要（弥补时间窗口盲区）
  subject: String
) → ColdCallAnswer { questionType, shortAnswer, supportingPoints }
```

**为什么需要 CourseNotes 弥补时间窗口：**
教授可能在问 30 分钟前讲过的概念，该内容已不在"最近 15 个 Block"里。
CourseNotesTool 提供全课笔记摘要，使答案不受时间窗口限制。

### Evals

| 指标 | 定义 | 目标值 |
|---|---|---|
| **Context Groundedness** | 答案中每个论点能在 transcript 中找到依据的比例 | ≥ 0.65 |
| **Detection Precision** | 真实学术提问 / 所有触发次数 | ≥ 0.80 |
| **Response Latency** | 从用户确认到答案完整显示 | P95 < 3s |

**Groundedness 算法（`evals/coldcall_eval.py`）：**
```python
def groundedness(answer: str, transcript: str) -> float:
    claims = extract_noun_phrases(answer)
    grounded = sum(1 for c in claims if c.lower() in transcript.lower())
    return grounded / len(claims) if claims else 0
```

**Detection Eval（人工标注）：**
准备 20 条样本（10 条含真实学术提问，10 条不含），
对比正则 vs LLM 二分类的 Precision / Recall。

### MCP

**`CourseNotesTool`（内部）** — 全课笔记摘要，弥补时间窗口（见上文）

**`CanvasTool`（外部，Phase 4）** — 若问题涉及即将到来的考试内容，在答案末追加：
> "Note: This topic appears in your upcoming midterm on Canvas (Oct 15)"

---

## Feature 5: Translation 实时翻译（International 模式）

### 产品规格

- 每个 Block 封存后异步触发翻译，中文译文追加显示在英文 Block 下方
- 默认目标语言：简体中文（可在 Settings 中配置）
- 译文展示可在 Settings 中随时开关
- 翻译请求包含课程 subject，提升专业术语翻译准确率

**时序说明：** 翻译在 Block **封存后**触发，而非逐词翻译。
这是有意为之的设计——句子完整后翻译质量显著优于逐词翻译，
对于学术内容尤其重要（中英文句法结构差异大，逐词译文语义混乱）。

### Multi-Agent

**Owner: `TranslationAgent`**（当前是独立 Service，迁移成本低）

翻译与其他 Agent 完全解耦，只需要 Block 文本 + subject。

**未来升级方向：**
- 将 `SlideItem.keywords` 作为术语表注入翻译 Prompt，强制统一专有名词译法
  （如：slides 里有"NPV"，翻译时统一保留英文缩写或译为"净现值"）
- 支持用户在 Settings 中自定义术语对照表，存入 `settings` 表

### Evals

| 指标 | 定义 | 测量方式 |
|---|---|---|
| Terminology Accuracy | 专业术语译法是否与课程约定一致 | 人工对照 SlideItem.keywords 检查 10 条样本 |
| Fluency | 译文是否通顺，无机翻痕迹 | 用户主观评分（1-5 星，未来功能） |
| Latency P95 | 从 Block 封存到中文显示的延迟 | 时间戳差值，目标 < 3s |

### MCP
当前无需外部数据。

**未来可能：**`GlossaryTool` — 查询用户自定义术语对照表，注入 TranslationAgent。

---

## Feature 6: Save 收藏

### 产品规格

**触发：** 划词后弹出菜单选择 Save（K / L）

**两种收藏类型（International 模式）：**
- **Save Knowledge ⌘⇧K**：立即保存，无需二次确认。自动触发翻译（International 模式）。
  SaveCard 出现在底部面板中央，供用户添加备注。
- **Save Language ⌘⇧L**：同 Knowledge 流程，类型标记为 Language，
  专为词汇和短语学习设计。

**Standard 模式：** 仅有 Knowledge 类型。

**存储结构：** `saves` 表，字段包括 `type`（knowledge/language）、`original`、
`translation`、`note`、`lectureId`。

**查阅：** 在单次课程记录的 Saved 子页面（按类型过滤），或在全局 Saved Items 页面跨课检索。

### Multi-Agent

Saved Items 本身不是 LLM 功能，是数据存储层。
但它是 `MemoryService` 的核心数据源——每次 Search 时，
MemoryService 扫描 `saves` 表找到语义相关的历史收藏，注入 SearchAgent 的 Prompt，
让 Saved Items 从"被动存储"变成"主动参与 AI 推理"。

```
saves 表
    ↓
MemoryService.getRelatedSaves(keywords, excludeLectureId)
    ↓
SearchAgent / ColdCallAgent 的 MemoryContext 中
```

### Evals

| 指标 | 定义 | 目标值 |
|---|---|---|
| **Memory Hit Rate** | Search 时 MemoryService 找到相关 Saved Items 的比例 | 追踪趋势，无硬性门控 |
| **Cross-Lecture Hit** | 命中的 Saved Items 来自不同课程的比例 | 越高说明跨课联系越丰富 |

### MCP

**`SavedItemsTool`（内部工具，Phase 1 最快交付）**
```
SavedItemsTool.call({ "keywords": ["NPV"], "exclude_lecture": "current_id" })
→ "From Intro to Finance (Oct 3): 'IRR' — internal rate of return, similar concept"
```

---

## Feature 7: Slide Structure 幻灯片解析

### 产品规格

用户在新建课程弹窗中上传 PDF 幻灯片。`SlideAgent` 解析全部幻灯片文本，
生成每页的 `SlideItem`（`index` + `title` + `concepts` + `keywords`），
存入 `lecture_slides` 表，作为整个课程笔记系统的骨架。

NoteAgent（slideIndex 映射）和 ColdCallAgent（课程主题 Context）均依赖此结构。

### Multi-Agent

**Owner: `SlideAgent`**（也是课程关键词的唯一来源）

```
User uploads PDF  (新建课程弹窗)
    ↓
SlideAgent.generate(
  slides: [[String: String]],   // 每页 raw 文本
  subject: String
) → [SlideItem { index, title, concepts, keywords }]
    ↓
存入 lecture_slides 表
    ↓
NoteAgent (slideIndex 映射) · ColdCallAgent (章节 Context) · TranslationAgent (术语表)
```

**已知问题：**
- `max_tokens=600` 对超过 15 页的幻灯片可能截断
- 修复方向：分批处理（每批 10 页），最后合并结果

### Evals

| 指标 | 定义 | 测量方式 |
|---|---|---|
| Structural Fidelity | 生成的 title/concepts 是否准确反映幻灯片内容 | 人工对照原始 PDF，5 份样本 |
| Keyword Coverage | SlideItem.keywords 是否覆盖幻灯片核心术语 | 人工检查关键词缺失情况 |

### MCP

**`CanvasTool` 双向使用（Phase 4）：**
- 方向 1：从 Canvas 拉取 Syllabus 自动生成 SlideItem（无需手动上传）
- 方向 2：SlideItem.keywords 反向注入 CanvasTool 查询，提升作业关联精准度

---

## Feature 8: Past Lecture Review 历史课程

### 产品规格

历史课程在标签页中打开，包含三个子页面：

| 子页面 | 内容 |
|---|---|
| Transcript | 所有语义 Block（含翻译，International 模式） |
| Saved | 收藏的 Knowledge 和 Language 笔记，支持按类型过滤 |
| Searches | 本课全部 AI 搜索记录 |

课程名称支持内联重命名。

### Multi-Agent / Evals / MCP
本功能为纯数据展示层，无 LLM 调用，不涉及 Agent / Eval / MCP。

---

## Feature 9: Export 导出

### 产品规格

导出为 `.docx` 格式，内容可选：
- Full transcript（完整转录文本）
- AI notes（AI 生成的笔记）
- Knowledge notes（手动收藏的知识卡）
- Language notes（词汇/语言笔记，International 模式）
- AI search records（AI 搜索记录）

触发方式：侧边栏按钮 或 ⌘⇧X。

### Multi-Agent / Evals / MCP
纯格式化导出，无 LLM 调用，不涉及 Agent / Eval / MCP。

---

## 三大技术框架横向总结

### Multi-Agent 归属图

```
AppViewModel（隐式 Coordinator，保持不变）
    ├── NoteAgent        →  笔记生成（每 Block 封存后触发）
    ├── SearchAgent      →  词汇解释（用户划词触发，注入 MemoryContext）
    ├── ColdCallAgent    →  提问检测 + 答案生成
    ├── TranslationAgent →  Block 封存后异步翻译
    ├── SlideAgent       →  课前幻灯片解析
    └── MemoryService    →  跨 Agent 的 Context 组装层
                            （不直接调用 LLM，是数据聚合服务）

共享基础设施：LLMClient.swift（统一 HTTP 客户端）
```

### Evals 门控指标总表

| Feature | 指标 | 门控阈值 |
|---|---|---|
| Notes | Accuracy + Coverage（GPT-4o Judge，0-100） | 平均分 < 75 → 回滚 |
| Search | Engagement Rate | 环比下降 > 5% → 人工 Review |
| Search | Bounce Rate | 环比上升 > 10% → 回滚 |
| Cold Call | Groundedness | < 0.65 → 回滚 |
| Cold Call | Detection Precision | < 0.80 → 回滚 |
| Translation | Latency P95 | > 3s → 优化 |
| Slide | Structural Fidelity | 人工 Review（无自动化门控） |

**Eval 运行时机：** 每次修改任一 Agent 的 Prompt 或模型参数前，
必须先跑对应 Eval 脚本，通过后方可合并。

### MCP 工具层架构

```
Phase 1（内部，无外部协议）:
  SavedItemsTool  →  SearchAgent（历史收藏注入）
  CourseNotesTool →  ColdCallAgent（全课笔记摘要注入）

Phase 4（外部，需 Canvas OAuth）:
  CanvasTool      →  SearchAgent（作业截止关联提示）
                  →  SlideAgent（Syllabus 自动导入）
                  →  ColdCallAgent（考试关联提示）
```

### 开发优先级

```
现在（无需等用户数据）:
  ✅ Phase 1 — MemoryService + SavedItemsTool + CourseNotesTool
  ✅ Phase 1 — 隐式反馈埋点（engaged / dismissed_at 字段）
  ✅ Phase 1 — 开课关键词注入 Deepgram（提升 WER）
  ✅ Phase 2 — Agent 文件拆分重构 + LLMClient 提取
  ✅ 手写 10 条 Golden Dataset 样本，建立 Eval 基线

有 50+ 真实用户后:
  ✅ Phase 3 — Notes Eval 自动化流水线
  ✅ Phase 3 — ColdCall Groundedness 自动检测
  ✅ 用户访谈：Canvas 集成需求验证

有用户明确需要 Canvas 后:
  ✅ Phase 4 — CanvasTool + Canvas OAuth 集成
```
