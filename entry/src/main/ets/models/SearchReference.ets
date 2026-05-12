/**
 * 搜索引用项: 单独抽到此文件,避免 ChatModels ↔ MessageParts 之间产生循环依赖。
 * MessagePart 需要按 toolCall 维度持有一组 SearchReference 切片,故 MessageParts 必须能 import 此类型。
 * ChatModels 通过 re-export 保持向后兼容,调用方仍可从 ChatModels 引入。
 */

@ObservedV2
export class SearchReference {
  @Trace id: string
  @Trace title: string
  @Trace url: string
  @Trace snippet: string
  @Trace timestamp: number

  constructor(id: string, title: string, url: string, snippet: string) {
    this.id = id
    this.title = title
    this.url = url
    this.snippet = snippet
    this.timestamp = Date.now()
  }
}

// JSON 持久化结构 (用于 parts 序列化和导入导出)
export interface SearchReferenceJson {
  id: string
  title: string
  url: string
  snippet: string
}

export function searchReferenceToJson(ref: SearchReference): SearchReferenceJson {
  return {
    id: ref.id,
    title: ref.title,
    url: ref.url,
    snippet: ref.snippet
  }
}

export function searchReferenceFromJson(json: SearchReferenceJson): SearchReference {
  return new SearchReference(
    json.id ?? '',
    json.title ?? '',
    json.url ?? '',
    json.snippet ?? ''
  )
}
