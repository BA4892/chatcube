# 附件能力扩展性改造计划

> 目标:让 chatbox 鸿蒙版能更可控、更便宜、更可扩展地处理图片、文档、音视频等多模态附件,对齐 kelivo / rikkahub 的能力,并在此基础上利用现有更解耦的接口架构做得更好。
>
> 编写日期:2026-05-17。落地节奏由实现者按 PR 拆分自定。

---

## 0. 背景与基线

### 0.1 友邻项目调研结果(三家发文档给 LLM 的策略一致)

无论 kelivo(Flutter)还是 rikkahub(Android),发文档给 LLM 的核心思路都是:

```
本地解析为纯文本 → 包成 "## user sent a file: {name}\n<content>\n...\n</content>" → 拼到 user message 文本里
```

差异只在:
- **解析器丰富度**:rikkahub 覆盖 PDF/DOCX/PPTX/EPUB,kelivo 覆盖 PDF/DOCX,我们目前**只有纯文本**。
- **抽象解耦度**:rikkahub 用 `when(mime)` 硬编码,kelivo 用 `if-else` 硬编码;**chatbox 目前的 `AttachmentTextExtractor` 接口 + 注册表反而是最解耦的**,但实现还很薄。
- **图片预处理**:rikkahub 有完整 pipeline(EXIF 旋转、长边 2048、JPEG q85),kelivo 和我们都没有。

### 0.2 chatbox 当前架构盘点

| 关注点 | 位置 | 现状 |
|---|---|---|
| 选择入口 | `entry/src/main/ets/components/AttachmentPicker.ets` | 相机/相册/文件三路;DocumentViewPicker 限定扩展名 |
| 附件 IR | `entry/src/main/ets/models/ChatModels.ets:424-455` | `MessageAttachment` + `enum AttachmentType { IMAGE, FILE }` |
| 部件 IR | `entry/src/main/ets/models/MessageParts.ets:22-30` | `MessagePart` 已预留 IMAGE/VIDEO/AUDIO/DOCUMENT |
| 沙箱存储 | `entry/src/main/ets/services/AttachmentStorageService.ets` (186 行) | `filesDir/attachments/{images,files}/` |
| 文本提取 | `entry/src/main/ets/services/AttachmentContentService.ets` (324 行) | **已有 `AttachmentTextExtractor` 接口 + 注册表**,但只有一个 `PlainTextAttachmentExtractor` |
| Provider 映射 | `entry/src/main/ets/services/AIApiService.ets` (3338 行) | Gemini(L1485)、Anthropic(L1553)、OpenAI(L1806)三套分支堆在一个文件 |
| 图片预处理 | — | **无**,base64 原图直接送 |
| 上传策略 | — | **全部 base64 inline**,无 Files API / 远端 URL 通道 |

### 0.3 三类核心缺口

1. **解析覆盖不足**:PDF / Office 全靠 provider 自己消化,本地不能转文本。
2. **图片无预处理**:手机原图 4000×3000 直接 base64,token 成本高、OpenAI 单图 20MB 限制易触发。
3. **抽象未跟进具体能力**:注册表已存在但只装了一个 plain text extractor;provider 映射仍硬编码。

---

## 1. 总体设计:三层抽象 + 一条流水线

### 1.1 三层抽象

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer A: AttachmentTextExtractor   (本地把附件转文本)           │
│   - PlainText / Pdf / Docx / Xlsx / Pptx / Epub ...             │
│   - supports(mime, ext): boolean  自路由                        │
│   - extract(att, maxChars, opts): Promise<Result | null>        │
├─────────────────────────────────────────────────────────────────┤
│ Layer B: AttachmentContentBlockMapper  (把附件映射为 provider   │
│         需要的内容块)                                            │
│   - OpenAIMapper / AnthropicMapper / GeminiMapper /             │
│     ResponsesMapper                                             │
│   - toBlocks(att, modelCaps): ContentBlock[]                    │
├─────────────────────────────────────────────────────────────────┤
│ Layer C: AttachmentUploadStrategy  (大附件远端化)               │
│   - InlineBase64Strategy (默认)                                 │
│   - AnthropicFilesApiStrategy (>20MB PDF 等)                    │
│   - (未来) OpenAIFilesStrategy / OssDirectUploadStrategy        │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 一条流水线

```
用户选附件 (AttachmentPicker)
    ↓
本地落盘 (AttachmentStorageService)
    + 若 IMAGE → ImagePreprocessor 预处理一次(EXIF/缩放/JPEG q85)
    ↓
发送时拼装 (ChatViewModel.sendMessage / AIApiService.buildMessages*)
    ├── 文本类附件:Layer A 提取 → 拼进 user 文本 (现有 appendInlineTextAttachments)
    ├── 图片附件:Layer C 决定本地 base64 还是远端 file_id → Layer B 映射为 image block
    └── 二进制文档(PDF 等):同上,Layer C + Layer B,或回退 Layer A 转文本
```

---

## 2. 分阶段任务详解

> 顺序原则:**先打地基(接口异步化、图片预处理),再补具体能力**。每个 Task 给出"目标 / 涉及文件 / 关键改动 / 验证 / 风险"四块。

---

### Task #3 — 抽 `AttachmentTextExtractor` 接口异步化 + `supports()` 自路由【地基,P0】

#### 目标
- `extract` 改为 `Promise` 返回,放开未来 PDF/DOCX 的 IO 阻塞需求。
- extractor 自己声明 `supports(mime, ext)`,不再靠 `AttachmentFileTypeDefinition.textExtractorId` 字符串路由。
- 文件类型表 `DOCUMENT_FILE_TYPES` 只承担"哪些扩展名能选择"和"展示给 picker 的 mime 列表",不再耦合 extractor 选择。

#### 涉及文件
- `entry/src/main/ets/services/AttachmentContentService.ets`(主战场)
- 所有调用方:
  - `entry/src/main/ets/services/AIApiService.ets`(`appendInlineTextAttachments` 等)
  - `entry/src/main/ets/services/ChatTaskOrchestratorService.ets` 也可能间接调用,需 grep 确认

#### 关键改动

**Step 3.1** — 接口签名升级:

```ts
// AttachmentContentService.ets

export interface AttachmentTextExtractor {
  /**
   * 声明能力。registry 按注册顺序,第一个返回 true 的 extractor 处理。
   * mime 优先,ext 兜底(part of 鸿蒙 DocumentViewPicker 返回的 uri 不一定带可靠 mime)。
   */
  supports(mime: string, ext: string): boolean

  /**
   * 异步抽取文本。返回 null 表示"识别但抽取失败",由上层决定是否走 fallback(直接 base64 送 provider)。
   * opts 预留:页数上限、超时、是否仅抽 OCR、preferredEncoding 等。
   */
  extract(
    attachment: MessageAttachment,
    maxChars: number,
    opts?: AttachmentExtractOptions
  ): Promise<AttachmentTextExtractionResult | null>
}

export class AttachmentExtractOptions {
  maxPages?: number       // PDF/PPT 用
  timeoutMs?: number      // 默认 10s,超时返回 null
  preferredEncoding?: string  // 默认 utf-8
}
```

**Step 3.2** — 注册表改造:

```ts
// 旧:用 textExtractorId 字符串关联
// 新:遍历 ATTACHMENT_TEXT_EXTRACTORS 找第一个 supports 的

export class AttachmentContentService {
  private static resolveExtractor(attachment: MessageAttachment): AttachmentTextExtractor | null {
    const ext = AttachmentContentService.extractExtension(attachment.name)
    for (const def of ATTACHMENT_TEXT_EXTRACTORS) {
      if (def.extractor.supports(attachment.mimeType, ext)) {
        return def.extractor
      }
    }
    return null
  }
}
```

**Step 3.3** — `AttachmentFileTypeDefinition` 去掉 `textExtractorId`,简化为:

```ts
export class AttachmentFileTypeDefinition {
  extensions: string[]
  mimeType: string
  selectableAsDocument: boolean
  // textExtractorId 移除
}
```

如果担心兼容外部注册的调用方,保留字段但忽略。建议直接移除,grep 项目内并无其他 `registerFileType` 调用方(确认)。

**Step 3.4** — `PlainTextAttachmentExtractor` 适配:

```ts
class PlainTextAttachmentExtractor implements AttachmentTextExtractor {
  supports(mime: string, ext: string): boolean {
    const PLAIN_PREFIXES = ['text/', 'application/json', 'application/xml',
      'application/javascript', 'application/x-yaml', 'application/toml',
      'application/sql', 'application/x-sh', 'application/x-bat',
      'application/x-powershell']
    if (PLAIN_PREFIXES.some(p => mime.startsWith(p))) return true
    // ext 兜底,对照 ChatModels 里已有 DOCUMENT_FILE_TYPES 的纯文本扩展集合
    const PLAIN_EXTS = ['.txt', '.md', '.markdown', '.mdx', '.csv', '.json',
      '.js', '.mjs', '.cjs', '.ts', '.tsx', '.html', '.htm', '.xml',
      '.yaml', '.yml', '.log', '.py', '.java', '.kt', '.kts', '.dart',
      '.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hxx', '.cs', '.go',
      '.rs', '.sql', '.sh', '.bat', '.cmd', '.ps1', '.toml', '.ini', '.properties']
    return PLAIN_EXTS.includes(ext.toLowerCase())
  }

  async extract(att: MessageAttachment, maxChars: number): Promise<AttachmentTextExtractionResult | null> {
    // 原有 base64Data → utf-8 解码逻辑,包成 Promise
    // 注意:这里同步即可,但为了接口一致写成 async
  }
}
```

**Step 3.5** — `AttachmentContentService.appendInlineTextAttachments` 改 async:

- 当前签名同步返回拼接好的字符串。
- 改为 `async appendInlineTextAttachments(...): Promise<string>`。
- 所有调用点(`AIApiService.ets:1514, 1597, 1734, 1876`)改成 `await`。这些函数本身就在 async 调用链里,影响可控。

**Step 3.6** — `canExtractInlineText` 也走 `resolveExtractor` 判断:

```ts
static canExtractInlineText(att: MessageAttachment): boolean {
  return AttachmentContentService.resolveExtractor(att) !== null
}
```

#### 验证

- `check_ets_files` 跑 `AttachmentContentService.ets` + `AIApiService.ets` 必须无 ArkTS 报错。
- 单元测试(无现成框架的话手测):
  - 发一条带 `.ts` 文件的消息,确认 user 文本最后含 `<content>...</content>`。
  - 发一条带 `.png` 的消息,确认 `canExtractInlineText` 返回 false、走图片通路。
- 回归:发普通无附件消息走通。

#### 风险
- `appendInlineTextAttachments` 异步化是侵入性的,调用链上下游所有 `buildMessagesXxx` 都得 audit 一遍。提交前 `grep -rn "appendInlineTextAttachments\|canExtractInlineText\|buildNonInlineFileAttachmentText" entry/src/main/ets/` 全量确认。
- ArkTS V2 的 `@Trace` 不影响这块(纯 service 层)。

---

### Task #4 — 新增 `ImagePreprocessor`:EXIF 校正 + 长边 2048 缩放 + JPEG q85【P0,与 #3 并行】

#### 目标
- 用户拍照/选图时,首次落盘前对图片做一次预处理,存到沙箱时已是处理过的版本。
- 收益:
  - token 成本 ↓ 60%+(原图 4000×3000 → 2048 长边)。
  - 绕开 OpenAI 单图 20MB 上限。
  - 修正 iPhone/部分安卓机 EXIF Orientation 不正导致的横躺图。
- 设计原则:**预处理只做一次,在落盘前**。base64Data 加载阶段不再做任何变换(纯读文件 → 编码)。

#### 涉及文件
- 新建 `entry/src/main/ets/services/ImagePreprocessor.ets`
- `entry/src/main/ets/services/AttachmentStorageService.ets`:在保存图片落盘前先 invoke preprocessor
- 可选:`entry/src/main/ets/components/AttachmentPicker.ets` 不动(picker 只产生 fileUri,落盘统一在 storage 层)

#### 关键改动

**Step 4.1** — `ImagePreprocessor` 模块结构:

```ts
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs'

export class ImagePreprocessOptions {
  maxLongEdge: number = 2048
  jpegQuality: number = 85
  preserveGif: boolean = true     // 动图不重编码
  preservePng: boolean = false    // 默认仍重编码为 JPEG;若需保留透明度可置 true
}

export class ImagePreprocessor {
  /**
   * 输入: 源 fileUri 或文件路径
   * 输出: 写入沙箱后的最终路径 + 实际宽高 + 实际大小
   * 失败时返回原图路径,不阻塞流程(打日志即可)。
   */
  static async preprocess(
    srcPath: string,
    destPath: string,
    opts?: ImagePreprocessOptions
  ): Promise<ImagePreprocessResult> {
    // 1. createImageSource(fd) → 读取 EXIF Orientation
    // 2. createPixelMap({ desiredSize, rotate }):
    //    - 计算目标尺寸:若 max(w,h) <= maxLongEdge,不缩放;否则等比缩放
    //    - 根据 EXIF orientation 映射 rotate 角度(0/90/180/270)+ 必要的 flip
    // 3. ImagePacker.packing(pixelMap, { format: 'image/jpeg', quality: 85 })
    // 4. 写入 destPath,返回 result
  }
}

export class ImagePreprocessResult {
  outputPath: string
  width: number
  height: number
  bytes: number
  mimeType: string  // 处理后,可能从 image/heic 变成 image/jpeg
  skipped: boolean  // true = 没动(GIF / 已经够小 / 失败回退)
}
```

**Step 4.2** — EXIF Orientation 映射表:

| Orientation | rotate | flipHorizontal |
|---|---|---|
| 1 | 0 | false |
| 2 | 0 | true |
| 3 | 180 | false |
| 4 | 180 | true |
| 5 | 90 | true |
| 6 | 90 | false |
| 7 | 270 | true |
| 8 | 270 | false |

读取走 `imageSource.getImageProperty(image.PropertyKey.ORIENTATION)`。HarmonyOS API 12+ 支持。

**Step 4.3** — `AttachmentStorageService` 接入点:

```ts
// 当前 saveImageAttachment(原始 uri) → 直接 fs.copyFile 到 attachments/images/
// 改成:
async saveImageAttachment(srcUri: string, originalName: string): Promise<MessageAttachment> {
  const tempPath = ...  // 先 copy 到临时位置
  const finalPath = `${this.imagesDir}/${id}.jpg`
  const result = await ImagePreprocessor.preprocess(tempPath, finalPath)
  // 清理 tempPath
  // size/mimeType 用 result 里的实际值
}
```

注意:**只对相机拍照 / 相册选图调用 preprocessor**。如果未来支持"用户直接拖一张 1024×1024 头像图作为非压缩资源",可在 picker 上加 "原图" 开关绕过。

**Step 4.4** — 不动 `AIApiService` 的 base64 编码部分。预处理后的 JPEG 直接编码送出即可,size 自然小。

#### 验证

- 拍一张竖向手持照(应该有 Orientation=6),发出去后在另一台设备/PC 收到的图正向。
- 选一张 4000×3000 的原图,发送后 base64 体积应 < 500KB(原本 2-3MB)。
- 选一张 GIF,确认仍为动图(`preserveGif=true` 跳过 packing)。
- 失败回退:删掉 packing 必备 API 权限模拟失败,确认原图也能发出去。

#### 风险
- HarmonyOS `image.createImageSource` 对 HEIC 支持需要 API 12+,部分老设备可能不支持。落地前用 `ask_ai` 确认 `compatibleSdkVersion` 与 HEIC 解码可用性。
- packing 失败时务必兜底(返回原图路径 + `skipped=true`),不要让用户卡住发不出消息。
- 持久化:**预处理后的图作为 source of truth 落盘**,意味着用户后续无法找回原图。这是预期行为(与 rikkahub 一致),但应在设置项里加 "保留原始图片质量" 开关供专业用户关闭。

#### 参考实现
- rikkahub `FileEncoder.kt:52-191`(EXIF + 缩放 + 压缩组合)
- 鸿蒙 ImageKit 官方文档:`https://developer.huawei.com/consumer/cn/doc/harmonyos-references/_image` 系列

---

### Task #2 — 扩 `AttachmentType` 枚举对齐 `MessagePart`【P1】

#### 目标
- 当前 `AttachmentType` 只有 `IMAGE | FILE`,但 `MessagePart` 已预留 IMAGE/VIDEO/AUDIO/DOCUMENT。
- 扩到 `IMAGE | DOCUMENT | AUDIO | VIDEO`,后续接 Gemini/Qwen-Omni 多模态不用再改 IR。

#### 涉及文件
- `entry/src/main/ets/models/ChatModels.ets:424`(枚举定义)
- 全项目 grep `AttachmentType.IMAGE` / `AttachmentType.FILE` 替换
  - 已知点:`AIApiService.ets:92, 102, 1570, 1725, 1861`
  - 多处 components 也在用,见 `grep -rn AttachmentType entry/src/main/ets/`
- `AttachmentStorageService` 的目录分流:`attachments/{images, documents, audios, videos}/`

#### 关键改动

**Step 2.1** — 枚举升级:

```ts
export enum AttachmentType {
  IMAGE = 'image',
  DOCUMENT = 'document',   // 原 FILE
  AUDIO = 'audio',
  VIDEO = 'video'
}
```

**Step 2.2** — 持久化兼容:数据库已存数据里 `type = 'file'` 的记录需迁移。

方案 A(推荐):**在 `MessageAttachment` 反序列化时映射** `'file' → 'document'`,不动数据库 schema。代价是代码里要有一处显式映射。

```ts
// MessageAttachment.fromJson 或 DatabaseService 里反序列化处
const legacyType = raw.type
const type = (legacyType === 'file') ? AttachmentType.DOCUMENT : (legacyType as AttachmentType)
```

方案 B:写 migration 直接 update,代价是迁移失败用户数据风险。**不推荐**,鸿蒙单机本地数据库直接改不可逆。

**Step 2.3** — 选择路径时分流:

```ts
// AttachmentPicker:用户从 picker 拿到 fileUri 后,根据 mimeType 决定 AttachmentType
function inferAttachmentType(mime: string): AttachmentType {
  if (mime.startsWith('image/')) return AttachmentType.IMAGE
  if (mime.startsWith('audio/')) return AttachmentType.AUDIO
  if (mime.startsWith('video/')) return AttachmentType.VIDEO
  return AttachmentType.DOCUMENT
}
```

**Step 2.4** — 旧 `FILE` 别名(过渡期):

```ts
// @deprecated 保留 1-2 个版本供外部代码迁移
export const ATTACHMENT_TYPE_FILE_LEGACY = AttachmentType.DOCUMENT
```

视项目惯例决定是否保留;若全项目内一次性改完,可以不保留。

#### 验证
- 老版本升级:DB 里残留 `type='file'` 的消息打开后,UI 仍显示文档图标、能重新发送、内联文本拼接正常。
- 选择音视频(若 picker 已支持)时类型正确;暂未支持的话,这步只是把路打通,不影响功能。

#### 风险
- `MessageAttachment` 在 ImportExportService / WebDAVSyncService 里可能也被序列化,需要 grep 确认导入导出兼容。
- 鸿蒙 V2 状态管理对 enum 变化敏感度低,影响有限。

---

### Task #5 — 拆 `AIApiService` 内三套附件映射成 `AttachmentBlockMapper`【P1,在 #3 之后】

#### 目标
- 把 `AIApiService.ets` 里 Gemini(L1485)、Anthropic(L1553)、OpenAI(L1806)三套附件→content block 的硬编码分支抽出去,变成各 provider 一个 mapper 类。
- 风格对齐现有 `services/registry/` 目录(`ProviderProfileRegistry`、`ModelAbilityRegistry`)。

#### 涉及文件
- 新建 `entry/src/main/ets/services/registry/AttachmentBlockMappers/`:
  - `AttachmentBlockMapper.ets`(接口)
  - `OpenAIChatMapper.ets`
  - `OpenAIResponsesMapper.ets`
  - `AnthropicMapper.ets`
  - `GeminiMapper.ets`
- `AIApiService.ets`:在 buildMessages* 各路里调用 mapper,删掉原分支
- `services/registry/index` 或 `ServiceRegistry.ets`:注册 mapper

#### 关键改动

**Step 5.1** — 接口设计:

```ts
// AttachmentBlockMapper.ets
import { MessageAttachment } from '../../../models/ChatModels'

export type ProviderKind = 'openai-chat' | 'openai-responses' | 'anthropic' | 'gemini' | 'qwen' | ...

/**
 * 输出 ContentBlock 用 ESObject(各 provider 结构不同),由 mapper 自己保证结构合法。
 * 不强行抽中间 IR,中间 IR 等多模态需求稳定后再做(YAGNI)。
 */
export interface AttachmentBlockMapper {
  readonly provider: ProviderKind
  /**
   * 一个附件可能映射为 0 个(不支持)、1 个(image inline)或多个(text + image_url)block。
   * canHandle 返回 false 时,由上层 fallback 到文本拼接(Layer A)。
   */
  canHandle(att: MessageAttachment, modelCaps: ModelCapabilities): boolean
  toBlocks(att: MessageAttachment, modelCaps: ModelCapabilities): ESObject[]
}
```

**Step 5.2** — 各 provider 实现示例(OpenAI Chat):

```ts
// OpenAIChatMapper.ets
export class OpenAIChatMapper implements AttachmentBlockMapper {
  readonly provider: ProviderKind = 'openai-chat'

  canHandle(att: MessageAttachment, caps: ModelCapabilities): boolean {
    return att.type === AttachmentType.IMAGE && caps.supportsVision
  }

  toBlocks(att: MessageAttachment, caps: ModelCapabilities): ESObject[] {
    return [{
      type: 'image_url',
      image_url: { url: `data:${att.mimeType};base64,${att.base64Data}` }
    } as ESObject]
  }
}
```

Anthropic mapper 类似,只是结构换成 `{ type: 'image', source: { type: 'base64', media_type, data } }`,且后续 Document 类型走 `{ type: 'document', source: ... }`。

Gemini mapper:`{ inline_data: { mime_type, data } }`。

**Step 5.3** — `AIApiService` 调用方式:

```ts
const mapper = AttachmentBlockMapperRegistry.get(providerKind)
for (const att of msg.attachments) {
  if (mapper.canHandle(att, caps)) {
    contentBlocks.push(...mapper.toBlocks(att, caps))
  } else {
    // fallback:Layer A 已经把它转成文本拼进 msg.content 了,这里跳过
  }
}
```

**Step 5.4** — Registry 单例:

```ts
// AttachmentBlockMapperRegistry.ets
export class AttachmentBlockMapperRegistry {
  private static map = new Map<ProviderKind, AttachmentBlockMapper>()
  static register(m: AttachmentBlockMapper) { this.map.set(m.provider, m) }
  static get(p: ProviderKind): AttachmentBlockMapper { /* throw or noop fallback */ }
}
// 初始化:在 ServiceRegistry.init 里 register 所有 builtin mapper
```

#### 验证
- 按 provider 类型分别发图,确认 OpenAI / Anthropic / Gemini 都能识别(回归现有用例)。
- 行数对比:`AIApiService.ets` 应至少能瘦 200-300 行。
- 加一个新 provider 时只需写一个 mapper 文件 + register 一行,不动主流程。

#### 风险
- Anthropic 已经支持 `document` block(传 PDF base64),这里要顺带把 `AttachmentType.DOCUMENT` 也接入 Anthropic mapper,优先级排在 Task #6 之前还是之后视实现进度决定。建议在 Task #5 完成后单独提一个小 PR 把 Anthropic document 通路打通。

---

### Task #6 — 新增 `AttachmentUploadStrategy` + Anthropic Files API【P2】

#### 目标
- 大附件(>20MB PDF,或后续 >100MB 视频)不能 inline,需要走 provider 的 Files API 拿 `file_id`。
- 抽 `AttachmentUploadStrategy` 接口,默认 `InlineBase64Strategy`,Anthropic 大文件走 `AnthropicFilesApiStrategy`。
- OpenAI Files / 阿里云 OSS 后续按需补。

#### 涉及文件
- 新建 `entry/src/main/ets/services/registry/AttachmentUploadStrategies/`
  - `AttachmentUploadStrategy.ets`
  - `InlineBase64Strategy.ets`
  - `AnthropicFilesApiStrategy.ets`
- `AIApiService.ets` 在调用 mapper 前先过一遍 strategy,把 `att.base64Data` 替换为 `att.remoteFileId`(或新增字段)
- `MessageAttachment`:加 `remoteUploadHandle?: UploadHandle`(包 provider + id + expiresAt)

#### 关键改动

**Step 6.1** — 接口:

```ts
export class UploadHandle {
  provider: ProviderKind
  id: string         // file_id 或 URL
  expiresAt: number  // ms timestamp;0 = 永久
}

export interface AttachmentUploadStrategy {
  /**
   * 由 strategy 自己判断是否要远端化。
   * 例如:size > 20MB && provider === 'anthropic' && mime === 'application/pdf'
   */
  needsRemoteUpload(att: MessageAttachment, providerKind: ProviderKind, modelId: string): boolean

  /**
   * 上传到 provider,返回 handle。失败抛异常,由上层决定是否回退到 inline(可能会失败)或提示用户。
   */
  upload(att: MessageAttachment, providerKind: ProviderKind): Promise<UploadHandle>
}
```

**Step 6.2** — Anthropic 实现:
- 端点:`POST https://api.anthropic.com/v1/files`(multipart/form-data)
- 文档:确认 beta header `anthropic-beta: files-api-2025-04-14`(需 `ask_ai_docs` 取最新)
- 鸿蒙 `@ohos.net.http` 可发 multipart;若 SDK 不便,用 base64 chunk + manual boundary。
- 缓存:UploadHandle 持久化到数据库(`message_attachments` 表加 `remote_handle_json` 列),避免每次重发都重传。

**Step 6.3** — 流水线接入:

```ts
// AIApiService 拼装 messages 前
for (const att of attachments) {
  if (strategy.needsRemoteUpload(att, providerKind, modelId)) {
    if (!att.remoteUploadHandle || att.remoteUploadHandle.expiresAt < Date.now()) {
      att.remoteUploadHandle = await strategy.upload(att, providerKind)
    }
  }
}
// 然后 mapper.toBlocks 里优先使用 remoteUploadHandle.id,fallback 到 base64Data
```

Anthropic mapper 里:
```ts
if (att.remoteUploadHandle && att.remoteUploadHandle.provider === 'anthropic') {
  return [{
    type: 'document',
    source: { type: 'file', file_id: att.remoteUploadHandle.id }
  }]
}
```

#### 验证
- 选一份 50MB PDF 发给 Claude,确认请求体不再 OOM,且 Claude 能引用 PDF 内容。
- 同一份 PDF 重发(在同一对话内的第二轮 user 消息),不再重传,直接复用 file_id。
- 小 PDF(<20MB)仍走 inline base64,行为不变(对照测试)。

#### 风险
- Anthropic Files API 还在 beta,有失效/格式变更可能。读取实现前用 `ask_ai_docs({ query: "Anthropic Files API 上传 PDF 文档" })` 拿最新规范。
- 上传过程要进度反馈,鸿蒙端在 UI 上需有进度条/可取消 UX,建议在 ChatViewModel 加一个 `attachmentUploadProgress` 状态。
- 隐私:用户可能不希望文件上传到 Anthropic;在设置项里加开关 "允许将大文件上传到 LLM 服务商"。

---

### Task #1 — PDF 文本 extractor【P2,依赖 #3 完成】

#### 目标
- 本地把 PDF 转成纯文本,通过 Layer A 拼到 user 消息里。
- 优先解决 Claude 之外的 provider(OpenAI / Gemini / 国内模型)对 PDF 的支持空缺。
- Claude 自身可走 Task #6 的 Files API,但用 Layer A 转文本作为兜底也是好事(便宜、可控)。

#### 调研需求(先做)
鸿蒙是否有官方 PDF 文本提取 API?用 `ask_ai_docs_batch`:
- `"HarmonyOS PdfService 提取 PDF 文本 API 用法"`
- `"HarmonyOS 解析 PDF 内容 ArkTS 第三方库"`
- `"@kit.PDFKit PdfDocument getText"`

若官方提供:用官方 API。若不提供:在 ohpm 找(`pdf-parse`、`pdfjs-dist` 等),无 ArkTS 适配的话考虑:
- C/C++ NAPI 集成 PDFium(成本高,但效果稳定,对照 rikkahub 用 MuPDF 的思路)
- JS 版 PDF.js 端侧跑(性能差,但小 PDF 可用)

#### 涉及文件
- 新建 `entry/src/main/ets/services/attachment-extractors/PdfTextExtractor.ets`
- `AttachmentContentService.ets`:`register` 时把它加入注册表
- `oh-package.json5`:若引入第三方库

#### 关键改动

**Step 1.1** — Extractor 骨架:

```ts
export class PdfTextExtractor implements AttachmentTextExtractor {
  supports(mime: string, ext: string): boolean {
    return mime === 'application/pdf' || ext.toLowerCase() === '.pdf'
  }

  async extract(
    att: MessageAttachment,
    maxChars: number,
    opts?: AttachmentExtractOptions
  ): Promise<AttachmentTextExtractionResult | null> {
    const maxPages = opts?.maxPages ?? 200
    const timeoutMs = opts?.timeoutMs ?? 15000
    try {
      // 1. 打开 PDF
      // 2. 逐页 getText(),累加到 buffer,达到 maxChars 或 maxPages 就停
      // 3. 返回 result(truncated 字段标识是否截断)
    } catch (e) {
      console.error('PdfTextExtractor', e)
      return null
    }
  }
}
```

**Step 1.2** — 注册:

```ts
// AttachmentContentService.ets 顶层
const ATTACHMENT_TEXT_EXTRACTORS = [
  ...,
  new AttachmentTextExtractorDefinition('pdf', new PdfTextExtractor())
]
```

或者在 `ServiceRegistry.init()` 里 `registerTextExtractor`。

#### 验证
- 选一份 50 页中文 PDF 发送,确认 user 文本里 `<content>` 内有合理文本(允许排版乱、空格异常)。
- 选扫描版 PDF(纯图):应返回 null(无 OCR 是预期),fallback 到 base64 送给 Anthropic 或提示用户。
- 性能:50 页 PDF < 3s 完成提取;超时 fallback 走 null。

#### 风险
- PDF 解析永远有边缘情况(嵌入字体、扫描图、加密 PDF)。先做"能跑就行",不追求 100% 完美。
- 内存:整本 PDF 解析占内存 = 页数 × 平均文本量;`maxPages=200` 是个安全界。
- 性能开销大,**必须**在异步线程跑,不要阻塞 UI 线程(extract 已是 async,内部用 `taskpool` 还是 worker 视库决定)。

---

### Task #7 — DOCX/XLSX/PPTX 文本 extractor【P2,依赖 #3 完成】

#### 目标
- Office 三件套都是 zip + XML,纯前端可解。鸿蒙有 `@ohos.zlib`,够用。

#### 涉及文件
- 新建:
  - `entry/src/main/ets/services/attachment-extractors/OfficeXmlUnzipUtil.ets`(公共解压工具)
  - `entry/src/main/ets/services/attachment-extractors/DocxTextExtractor.ets`
  - `entry/src/main/ets/services/attachment-extractors/XlsxTextExtractor.ets`
  - `entry/src/main/ets/services/attachment-extractors/PptxTextExtractor.ets`

#### 各格式抽取策略

**DOCX**(对照 kelivo 实现):
- 解压后读 `word/document.xml`
- XPath: `//w:t` 所有节点文本(`w:t` 是 word 文本节点),按 `w:p`(段落)分行
- 注意:`w:tab` → `\t`,`w:br` → `\n`,`w:tbl` 表格保持 cell 间用 `\t`、行间用 `\n`

**XLSX**(对照 rikkahub 思路,但简化):
- 读 `xl/sharedStrings.xml` 得 inline strings 表(`<si><t>...</t></si>` 索引数组)
- 读 `xl/worksheets/sheet1.xml`、`sheet2.xml` ...
- 每个 `<c>` cell 看 `t="s"` 时引用 sharedStrings,否则直接读 `<v>` 数值
- 输出格式:每个 sheet 一段,行用 `\n`,cell 用 `\t`,sheet 间用 `\n\n# Sheet: ...\n\n`

**PPTX**:
- 解压后枚举 `ppt/slides/slide*.xml`
- 抽 `<a:t>` 文本节点
- 每页 slide 前加 `## Slide N` 分隔

#### 注册
```ts
new AttachmentTextExtractorDefinition('docx', new DocxTextExtractor()),
new AttachmentTextExtractorDefinition('xlsx', new XlsxTextExtractor()),
new AttachmentTextExtractorDefinition('pptx', new PptxTextExtractor()),
```

每个 extractor 的 `supports()`:
```ts
supports(mime: string, ext: string): boolean {
  return mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      || ext.toLowerCase() === '.docx'
}
```

#### 验证
- 选一份带表格的 DOCX,确认表格结构在 user 消息文本里能看出来(LLM 能理解)。
- XLSX 选一份多 sheet 的,确认每个 sheet 都出现。
- PPTX 选一份 20 页的,确认每页文本都抽出。

#### 风险
- 旧版 `.doc`(二进制 OLE,不是 OOXML)**不支持**。Picker 阶段移除 `.doc` 或保留但 extractor 返回 null,由用户感知。
- 嵌入图片/图表内的文字抽不出来(LLM 拿不到,可接受)。

---

## 3. 推荐落地节奏

```
里程碑 1(P0,2-3 天)
  Task #3  接口异步化 + supports() 自路由
  Task #4  ImagePreprocessor
  里程碑产出:接口地基 + 图片成本立即下降,用户感知最强

里程碑 2(P1,2-3 天)
  Task #5  拆 mapper
  Task #2  扩 AttachmentType 枚举
  里程碑产出:代码结构更干净,可读性 + 加 provider 难度下降

里程碑 3(P2,5-7 天,内部可乱序)
  Task #6  AttachmentUploadStrategy + Anthropic Files API
  Task #1  PdfTextExtractor
  Task #7  Office extractors
  里程碑产出:文件能力对齐 rikkahub,且因为 Layer A/B/C 解耦,后续加新格式/新 provider 成本极低
```

每个里程碑结束后:
- `check_ets_files` 全量过
- `build_project` 全量过
- `start_app` + 手测:发文本附件、发图、发 PDF(若已实现 Task #1)
- 提一个独立 PR,描述结构 + 测试用例 + 风险点

---

## 4. 全局风险与回滚策略

| 风险 | 触发条件 | 回滚 |
|---|---|---|
| ArkTS V2 `@Trace` 在 `MessageAttachment` 上失效 | 改了字段后 UI 不刷新 | 字段加 `@Trace`,或保持引用替换 |
| 图片预处理在低端机超时 / OOM | 用户拍超大图(>50MP) | 预处理超时 5s 后回退原图,日志告警 |
| Anthropic Files API beta 变更 | 上传返回 4xx | 回退到 inline base64 + 提示用户文件过大 |
| Office extractor 解压失败 | 损坏的 docx/xlsx | extract 返回 null,fallback 到"附件无法解析"提示 |
| DB schema 变更引入升级失败 | 升级用户老库读不出 | **不动 schema**,反序列化层做兼容映射 |

---

## 5. 参考实现对照

| 友邻项目 | 关键文件 | 参考意义 |
|---|---|---|
| kelivo (Flutter) | `lib/core/services/chat/document_text_extractor.dart` | DOCX zip+xml 解析思路 |
| kelivo (Flutter) | `lib/core/services/api/chat_api_service.dart:495-650, 1399-1445` | OpenAI / Claude image block 结构 |
| rikkahub (Android) | `ai/src/main/java/me/rerere/ai/util/FileEncoder.kt:52-191` | EXIF + 缩放 + 压缩 pipeline,Task #4 直接对照 |
| rikkahub (Android) | `app/src/main/java/me/rerere/rikkahub/data/ai/transformers/DocumentAsPromptTransformer.kt:61-78` | 按 mime 路由 extractor 的简化版,Task #3 灵感来源 |
| rikkahub (Android) | `ai/src/main/java/me/rerere/ai/provider/providers/ClaudeProvider.kt:467-489` | Anthropic content block 映射,Task #5 模板 |
| rikkahub (Android) | `app/src/main/java/me/rerere/rikkahub/data/files/FilesManager.kt:105-145` | 沙箱文件管理 + 元数据表 |

---

## 6. 验证用例汇总(完工后回归)

- [ ] 发空消息只带一张相机拍的竖向照片 → Claude/OpenAI/Gemini 都能识别为图、方向正确、体积 < 500KB
- [ ] 发一份带表格的 DOCX → 模型能引用其中表格数据
- [ ] 发一份扫描版 PDF → 自动提示"无法本地解析",由 Claude Files API 兜底
- [ ] 发一份 30MB 文字 PDF → 走 Anthropic Files API,二次发送时复用 file_id
- [ ] 发一份代码文件(.kt / .ts / .py)→ 内容内联到 user 文本,模型能逐行引用
- [ ] 切换 provider(同一对话切到不同模型)→ 附件块正确按目标 provider 重新映射
- [ ] 升级路径:从旧版本(只有 IMAGE/FILE)升级,历史消息能正常打开、显示、转发

---

## 附录 A:文件路径速查

| 关注点 | 路径 |
|---|---|
| 附件 IR | `entry/src/main/ets/models/ChatModels.ets:424-455` |
| Message Part IR | `entry/src/main/ets/models/MessageParts.ets:22-30` |
| 选择器 UI | `entry/src/main/ets/components/AttachmentPicker.ets` |
| 输入栏 | `entry/src/main/ets/components/ChatInputBar.ets` |
| 沙箱存储 | `entry/src/main/ets/services/AttachmentStorageService.ets` |
| 文本提取(主战场) | `entry/src/main/ets/services/AttachmentContentService.ets` |
| Provider 映射(待拆) | `entry/src/main/ets/services/AIApiService.ets:1485, 1553, 1806` |
| 注册表风格参考 | `entry/src/main/ets/services/registry/*` |
| 服务初始化入口 | `entry/src/main/ets/services/ServiceRegistry.ets` |

## 附录 B:必查 API(实现时用 ask-huawei-qa 确认)

- `@ohos.multimedia.image` createImageSource / createPixelMap / packing 接口
- `image.PropertyKey.ORIENTATION` 读取 EXIF
- `@ohos.file.fs` 读写沙箱文件
- `@ohos.zlib` 解压 zip(Office 格式必备)
- `@ohos.xml`(可选,DOMParser 或 XmlPullParser)解析 OOXML
- HarmonyOS 是否有 `@kit.PDFKit` / `pdfService` 等官方 PDF 文本 API
- `@ohos.net.http` 发 multipart/form-data(Anthropic Files API 上传)
- `@ohos.taskpool` 异步运行 CPU 密集解析任务
