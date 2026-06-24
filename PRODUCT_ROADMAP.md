# Grasp 产品技术路线图

> 基于当前代码状态（2026-06）制定，分四个阶段落地。

---

## 现状分析

```
当前调用链：
  AppViewModel.seal()
    → DeepSeekService.generateNoteEntry()      [500ms debounce后触发]
  AppViewModel.triggerSearch()
    → DeepSeekService.streamSearch()           [用户划词触发，streaming]
  AppViewModel.generateCCAnswer()
    → DeepSeekService.generateColdCallAnswer() [Cold Call检测后触发]
```

**核心问题：每次LLM调用完全无状态。**
- `streamSearch` 只能看到当前课的最近10个Block（`getRecentBlocks(limit:10)`）
- 用户在其他课收藏的内容（`saves`表）、历史搜索过的词（`searches`表）从未被注入任何Prompt
- 没有任何用户行为负反馈追踪（只知道用户保存了，不知道用户看了就关掉了）

---

## Phase 1 — Memory Agent + 隐式反馈基础设施
**目标时间：2周 | 无破坏性改动**

### 1.1 新建 `MemoryService.swift`

**职责：** 在每次Search/ColdCall调用前，从本地SQLite中为当前query组装富Context。

```
MemoryContext {
  relatedSaves:   [SavedCard]     // 跨课、关键词匹配的历史收藏
  relatedSearches:[SearchResult]  // 本课 + 其他课搜过的相关词及其结果
  courseKeywords: [String]        // 当前课SlideItem.keywords的合集
}
```

**关键词匹配逻辑（V1，无需向量库）：**
1. 把query分词（按空格+标点切分）
2. 在`saves.original`和`searches.query`里做LIKE匹配
3. 限制最多返回3条relatedSaves + 3条relatedSearches，避免context膨胀

**新增DatabaseService方法：**
```swift
func getRelatedSaves(keywords: [String], excludeLectureId: String?, limit: Int) -> [SavedCard]
func getRelatedSearches(keywords: [String], excludeLectureId: String?, limit: Int) -> [SearchResult]
```

查询示例（`getRelatedSaves`）：
```sql
SELECT s.*, l.name as ln, l.subject as ls, l.started_at as ld
FROM saves s LEFT JOIN lectures l ON l.id = s.lecture_id
WHERE (s.original LIKE ? OR s.original LIKE ?)   -- 每个keyword一个条件
  AND (s.lecture_id != ? OR ? IS NULL)
ORDER BY s.created_at DESC
LIMIT ?
```

---

### 1.2 修改 `DeepSeekService.streamSearch`

在Prompt里增加Memory Block：

```
[当前已有]
Course: {subject}
Recent transcript: {recent 10 blocks}
Term: "{query}"

[新增，由MemoryService提供]
Related concepts you've saved before:
- "{save.original}" (from {save.lectureName})
  → {save.resultPro}

Previously searched related terms:
- "{search.query}": {search.resultPro}
```

**Prompt新增规则：**
- 如果MemoryContext非空，在回答末尾（Sentence 3，可选）增加一句跨课关联提示
- 如果MemoryContext为空，行为与现在完全一致，不影响现有体验

---

### 1.3 隐式反馈埋点

**在`searches`表新增两列：**
```sql
ALTER TABLE searches ADD COLUMN engaged INTEGER DEFAULT 0;
-- 0 = 未交互（看了就关）
-- 1 = 有交互（展开追问 / 保存 / hover超过3秒）

ALTER TABLE searches ADD COLUMN dismissed_at INTEGER;
-- 用户关闭search card的时间戳
```

**触发规则（在AppViewModel中）：**

| 事件 | 操作 |
|---|---|
| 用户点击"Save"按钮 | `engaged = 1`（已有逻辑，补充DB写入） |
| 用户在Search Card上停留 > 3秒 | `engaged = 1` |
| 用户点击"X"关闭 / 切换tab | `dismissed_at = now()`，`engaged` 保持0 |
| 用户触发追问（Follow-up，未来功能） | `engaged = 1` |

**Cold Call同样追踪：**
```swift
// ColdCallPhase新增：
case dismissed  // 用户按X
case acted      // 用户看完（停留>5秒）
```

---

### Phase 1 交付物
- `MemoryService.swift`（新文件）
- `DeepSeekService.streamSearch` prompt升级
- `DatabaseService` 两个新查询方法 + schema migration
- Search Card 停留时间计时器（`AppViewModel`）
- 可测量：搜索结果的 `engaged` 率从 baseline 开始积累

---

## Phase 2 — Agent 架构重构
**目标时间：第3周 | 纯重构，行为不变**

### 2.1 拆分 `DeepSeekService`

将现有4个方法拆成4个独立文件，共享一个底层 `LLMClient.swift`。

```
Services/
  LLMClient.swift          ← 原来的call() + stream() + parseJSON()，提取为公共client
  Agents/
    NoteAgent.swift        ← generateNoteEntry()
    SearchAgent.swift      ← streamSearch()，注入MemoryContext
    ColdCallAgent.swift    ← generateColdCallAnswer() + detectCC()
    SlideAgent.swift       ← generateSlideStructure()
```

**`LLMClient.swift` 接口：**
```swift
final class LLMClient {
  func call(prompt: String, model: String, maxTokens: Int) async throws -> String
  func stream(prompt: String, model: String, maxTokens: Int, onToken: (String)->Void) async throws -> String
}
```

**拆分后的好处：**
- 每个Agent可以独立设置 `model`（NoteAgent用更快的模型，ColdCall用推理更强的）
- 每个Agent的Prompt改动不会误伤其他功能
- 单独对一个Agent做Eval时，只需改一个文件

### 2.2 `AppViewModel` 中的隐式Coordinator

`AppViewModel`已经是Coordinator，不需要新建类。只需把服务调用改为agent调用：

```swift
// 改前
private let ds = DeepSeekService.shared

// 改后
private let noteAgent    = NoteAgent()
private let searchAgent  = SearchAgent()
private let coldCallAgent = ColdCallAgent()
private let memory       = MemoryService.shared
```

`triggerSearch`里的调用顺序变为：
```
1. memory.buildContext(query, lectureId, subject)  → MemoryContext
2. searchAgent.stream(query, context, memory)      → 富结果
```

---

## Phase 3 — Evals Pipeline（外部工具）
**目标时间：第2个月 | Python脚本，在app之外运行**

### 3.1 Golden Dataset 格式

```json
{
  "id": "eval_001",
  "type": "notes",
  "input": {
    "subject": "Microeconomics",
    "slides": [...],
    "recent_transcript": "So the key insight here is that when price elasticity..."
  },
  "ideal_output": {
    "content": "Price elasticity: percentage change in demand per 1% price change",
    "level": 0,
    "slide_index": 2
  }
}
```

**构建方式：**
1. 真实用户使用前：手写10条代表性Transcript（覆盖Finance/CS/History三个subject）
2. 有真实用户后：从DB导出高engagement的搜索记录，人工标注理想输出

### 3.2 Notes Eval（`evals/notes_eval.py`）

```
输入：
  - transcript段落（来自Golden Dataset）
  - NoteAgent生成的note
  
评判模型（GPT-4o / Claude Opus）：
  Prompt: "判断下面这条笔记是否准确捕捉了Transcript的核心要点。
           评分维度：
           - Accuracy（0-100）：笔记内容是否与transcript一致，无幻觉
           - Coverage（0-100）：最重要的概念有没有被记录
           - Conciseness（0-100）：是否在20词以内表达完整"

输出：
  { "accuracy": 85, "coverage": 72, "conciseness": 90, "reasoning": "..." }
  
门控规则：
  平均分 < 75 → 该Prompt版本不得合并
```

### 3.3 Cold Call Groundedness Eval（`evals/coldcall_eval.py`）

```
上下文绑定度算法：
  1. 提取ColdCallAnswer.shortAnswer中的所有名词短语（NLP分词）
  2. 对每个名词短语，在transcript中做substring搜索
  3. groundedness = (能在transcript中找到依据的论点数) / (总论点数)

门控规则：
  groundedness < 0.6 → 判定为"幻觉风险高"，记录到Eval report
```

### 3.4 隐式Eval报告（从DB导出）

```sql
-- 每日运行，输出搜索满意度
SELECT
  DATE(created_at/1000, 'unixepoch') as date,
  COUNT(*) as total_searches,
  SUM(engaged) as engaged_count,
  ROUND(100.0 * SUM(engaged) / COUNT(*), 1) as engagement_rate,
  COUNT(CASE WHEN dismissed_at IS NOT NULL AND engaged = 0 THEN 1 END) as bounce_count
FROM searches
GROUP BY date
ORDER BY date DESC;
```

**Prompt升级门控：**
- `engagement_rate` 下降超过5% → 回滚
- `bounce_count` 上升超过10% → 人工review

---

## Phase 4 — MCP 架构
**目标时间：第3个月 | 分两步**

### 4.1 "内部MCP"（不需要MCP协议，2天）

这是Phase 1 Memory Agent的自然延伸。把Grasp内部资产（Notes、Saves、Searches）
的访问接口规范化，哪怕只是内部Swift Protocol，也按MCP的Tool-Call思路设计：

```swift
protocol MCPTool {
  var name: String { get }
  var description: String { get }
  func call(input: [String: Any]) async -> String  // 返回给LLM的字符串
}

// 实现1：SavedItems Tool
struct SavedItemsTool: MCPTool {
  func call(input: [String: Any]) async -> String {
    // input["keywords"] → 搜索saves表 → 返回格式化的相关收藏列表
  }
}

// 实现2：CourseNotes Tool  
struct CourseNotesTool: MCPTool {
  func call(input: [String: Any]) async -> String {
    // 返回当前课的笔记摘要，供ColdCallAgent参考
  }
}
```

SearchAgent在生成回答前先调用这两个Tool，把返回值注入Prompt。
这就是你描述的"AI自动查Saved Items然后做类比"场景，不需要真正的MCP服务器。

---

### 4.2 Canvas LMS 集成（真正的外部MCP）

**技术方案：**

Canvas提供标准OAuth2 + REST API。集成路径：

```
Step 1: OAuth授权
  用户在Settings页面点击"Connect Canvas"
  → 打开 {school}.instructure.com/login/oauth2/auth
  → 回调到 grasp://canvas-callback
  → 存储access_token到Keychain

Step 2: 数据拉取（一次性，课程开始前）
  GET /api/v1/courses/{course_id}/assignments
  GET /api/v1/courses/{course_id}/pages (Syllabus)
  → 存入本地SQLite新表 canvas_assignments, canvas_syllabus

Step 3: 注入Search Context
  CanvasTool.call(keywords) → 查找与query相关的作业截止日期和要求
  → SearchAgent Prompt增加：
    "Upcoming assignments related to this concept:
     - {assignment.name}, due {due_date}: {assignment.description}"
```

**Canvas集成的产品呈现：**

Search Card底部新增一行（仅当Canvas已连接且有相关作业时显示）：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅  与 Canvas 相关：Finance HW3 — 下周二截止
     "Evaluate NPV and IRR for the capital budgeting case"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**落地优先级判断：**
- 先问10个真实用户："如果Grasp知道你的Canvas作业，你会觉得有用吗？"
- 如果>7个人说有用 → 立项
- Canvas API文档：`{school}.instructure.com/doc/api/`（各校endpoint不同，需处理）

---

## 各阶段成功指标

| 阶段 | 核心指标 | 测量方式 |
|---|---|---|
| Phase 1 | Search Engagement Rate ≥ 40% | `engaged/total` from DB |
| Phase 1 | Memory命中率（有relatedSaves的search占比）| 日志统计 |
| Phase 2 | 无回归（行为与重构前一致）| 手工smoke test |
| Phase 3 | Notes Eval平均分 ≥ 80 | 每次Prompt改动前跑eval脚本 |
| Phase 3 | ColdCall Groundedness ≥ 0.65 | 自动化检测 |
| Phase 4 | Canvas连接率（有Canvas的用户占比）| 用户调研 |

---

## 文件变更清单

### Phase 1 新增/修改
```
新增：Grasp/Services/MemoryService.swift
修改：Grasp/Services/DeepSeekService.swift  (streamSearch prompt)
修改：Grasp/Services/DatabaseService.swift  (2个新查询方法 + schema migration)
修改：Grasp/ViewModels/AppViewModel.swift   (注入MemoryContext，engagement埋点)
修改：Grasp/Models/Models.swift             (MemoryContext struct，engagement字段)
```

### Phase 2 新增/修改
```
新增：Grasp/Services/LLMClient.swift
新增：Grasp/Services/Agents/NoteAgent.swift
新增：Grasp/Services/Agents/SearchAgent.swift
新增：Grasp/Services/Agents/ColdCallAgent.swift
新增：Grasp/Services/Agents/SlideAgent.swift
删除：Grasp/Services/DeepSeekService.swift  (功能迁移完成后)
修改：Grasp/ViewModels/AppViewModel.swift   (替换服务引用)
```

### Phase 3 新增（App外部）
```
新增：evals/golden_dataset/notes/*.json
新增：evals/golden_dataset/coldcall/*.json
新增：evals/notes_eval.py
新增：evals/coldcall_eval.py
新增：evals/engagement_report.sql
```

### Phase 4 新增/修改
```
新增：Grasp/Services/Agents/SavedItemsTool.swift
新增：Grasp/Services/Agents/CourseNotesTool.swift
新增：Grasp/Services/CanvasService.swift       (Phase 4.2)
修改：Grasp/Views/Pages/SettingsView.swift     (Canvas连接入口)
修改：Grasp/Models/Models.swift                (CanvasAssignment struct)
修改：Grasp/Services/DatabaseService.swift     (canvas_assignments表)
```
