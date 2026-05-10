import {
  ToolDefinition,
  ToolConfig,
  ToolParameters,
  ToolFunction,
  ToolParameterProperty,
  ToolPermissionLevel,
  ToolSourceType
} from '../models/ChatModels'
import { ToolExecutor, RegisteredTool, getToolRegistry } from '../services/ToolRegistry'
import { getWebSearchService, SearchResult, WebSearchResult } from '../services/WebSearchService'
import {
  LEGACY_WEB_SEARCH_TOOL_ID,
  SCRAPE_WEB_TOOL_ID,
  SEARCH_WEB_TOOL_ID
} from '../utils/SearchToolIdentityUtils'

// search_web 工具参数接口
interface SearchWebArgs {
  query: string
}

// scrape_web 工具参数接口
interface ScrapeWebArgs {
  url?: string
  query?: string
}

// 搜索结果项接口（用于格式化输出）
class SearchResultItem {
  index: number = 0
  id: string = ''
  title: string = ''
  url: string = ''
  snippet: string = ''

  constructor(index: number, id: string, title: string, url: string, snippet: string) {
    this.index = index
    this.id = id
    this.title = title
    this.url = url
    this.snippet = snippet
  }
}


// 搜索结果输出接口
class SearchResultOutput {
  query: string = ''
  searchEngine: string = ''
  results: SearchResultItem[] = []
  summary: string = ''

  constructor(query: string, searchEngine: string, results: SearchResultItem[], summary: string) {
    this.query = query
    this.searchEngine = searchEngine
    this.results = results
    this.summary = summary
  }
}

// 错误输出接口
class ErrorOutput {
  error: string = ''

  constructor(error: string) {
    this.error = error
  }
}

class WebSearchResultFormatter {
  buildSnippet(content: string): string {
    const trimmed = content.replace(/\s+/g, ' ').trim()
    if (trimmed.length <= 200) {
      return trimmed
    }
    return trimmed.substring(0, 200) + '...'
  }

  formatWebResult(result: WebSearchResult): string {
    if (!result.success) {
      return JSON.stringify(new ErrorOutput(result.errorMessage))
    }

    const output = new SearchResultOutput(
      result.url,
      result.sourceName !== '' ? result.sourceName : 'URL抓取',
      [new SearchResultItem(
        1,
        `ref_${Date.now()}`,
        result.title,
        result.url,
        this.buildSnippet(result.content)
      )],
      `标题: ${result.title}\n来源: ${result.url}\n\n${result.content}`
    )
    return JSON.stringify(output)
  }

  formatResult(result: SearchResult): string {
    if (!result.success) {
      return JSON.stringify(new ErrorOutput(result.errorMessage))
    }

    // 返回结构化的搜索结果（包含 index 和 id）
    const formattedResults: SearchResultItem[] = []
    for (let i = 0; i < result.references.length; i++) {
      const ref = result.references[i]
      formattedResults.push(new SearchResultItem(
        i + 1,  // index 从 1 开始
        ref.id,
        ref.title,
        ref.url,
        ref.snippet
      ))
    }

    const output = new SearchResultOutput(
      result.query,
      result.searchEngine,
      formattedResults,
      result.contentForAI
    )
    return JSON.stringify(output)
  }
}

// search_web 执行器
class SearchWebExecutor implements ToolExecutor {
  private formatter: WebSearchResultFormatter = new WebSearchResultFormatter()

  async execute(args: string): Promise<string> {
    try {
      const params = JSON.parse(args) as SearchWebArgs
      if (params.query === undefined || params.query.trim() === '') {
        return JSON.stringify(new ErrorOutput('搜索关键词不能为空'))
      }

      const query = params.query.trim()
      console.info('SearchWebExecutor', `Executing web search: ${query}`)
      const searchResult = await getWebSearchService().search(query)
      return this.formatter.formatResult(searchResult)
    } catch (error) {
      console.error('SearchWebExecutor', `Search error: ${JSON.stringify(error)}`)
      return JSON.stringify(new ErrorOutput(`搜索失败: ${JSON.stringify(error)}`))
    }
  }
}

// scrape_web 执行器
class ScrapeWebExecutor implements ToolExecutor {
  private formatter: WebSearchResultFormatter = new WebSearchResultFormatter()

  async execute(args: string): Promise<string> {
    try {
      const params = JSON.parse(args) as ScrapeWebArgs
      const rawUrl = params.url !== undefined ? params.url : (params.query !== undefined ? params.query : '')
      if (rawUrl === undefined || rawUrl.trim() === '') {
        return JSON.stringify(new ErrorOutput('网页 URL 不能为空'))
      }

      const url = rawUrl.trim()
      console.info('ScrapeWebExecutor', `Executing web scrape: ${url}`)
      const webResult = await getWebSearchService().fetchUrlContent(url)
      return this.formatter.formatWebResult(webResult)
    } catch (error) {
      console.error('ScrapeWebExecutor', `Scrape error: ${JSON.stringify(error)}`)
      return JSON.stringify(new ErrorOutput(`网页读取失败: ${JSON.stringify(error)}`))
    }
  }
}

// 兼容旧 web_search：历史调用和旧 provider 输出仍可执行，但新请求不再注入该工具。
class LegacyWebSearchExecutor implements ToolExecutor {
  private formatter: WebSearchResultFormatter = new WebSearchResultFormatter()

  async execute(args: string): Promise<string> {
    try {
      const params = JSON.parse(args) as SearchWebArgs
      if (params.query === undefined || params.query.trim() === '') {
        return JSON.stringify(new ErrorOutput('搜索关键词不能为空'))
      }

      const query = params.query.trim()
      const webSearchService = getWebSearchService()
      const extractedUrl = webSearchService.extractUrl(query)
      const isPureUrl = extractedUrl !== null && extractedUrl === query
      if (isPureUrl && extractedUrl !== null) {
        console.info('LegacyWebSearchExecutor', `Executing web scrape: ${extractedUrl}`)
        const webResult = await webSearchService.fetchUrlContent(extractedUrl)
        return this.formatter.formatWebResult(webResult)
      }

      console.info('LegacyWebSearchExecutor', `Executing web search: ${query}`)
      const searchResult = await webSearchService.search(query)
      return this.formatter.formatResult(searchResult)
    } catch (error) {
      console.error('LegacyWebSearchExecutor', `Search error: ${JSON.stringify(error)}`)
      return JSON.stringify(new ErrorOutput(`搜索失败: ${JSON.stringify(error)}`))
    }
  }
}

function createSearchWebToolDefinition(): ToolDefinition {
  const parameters = new ToolParameters()
  parameters.addProperty('query', new ToolParameterProperty(
    'string',
    '聚焦搜索关键词。用于搜索外部实时、特定或需要验证的信息，不要传入整段用户问题。'
  ))
  parameters.addRequired('query')

  const func = new ToolFunction(
    SEARCH_WEB_TOOL_ID,
    'Search the web for up-to-date, specific, or verifiable information. First decide whether web access is truly needed; use your own knowledge for common stable facts and pure generation tasks. Each search has real cost, so generate focused keywords and run multiple searches only when more evidence is needed. Cite results with [1], [2] style source numbers.',
    parameters
  )

  return new ToolDefinition(func)
}

function createScrapeWebToolDefinition(): ToolDefinition {
  const parameters = new ToolParameters()
  parameters.addProperty('url', new ToolParameterProperty(
    'string',
    '要读取的网页 URL。用户给出 URL 或要求总结、分析某个网页时，原样传入 URL。'
  ))
  parameters.addRequired('url')

  const func = new ToolFunction(
    SCRAPE_WEB_TOOL_ID,
    'Scrape a URL for detailed page content. Use this when the user provides a specific URL, asks to read or summarize a page, or search snippets are insufficient. Avoid using it for common questions unless the user asks.',
    parameters
  )

  return new ToolDefinition(func)
}

function createLegacyWebSearchToolDefinition(): ToolDefinition {
  const parameters = new ToolParameters()
  parameters.addProperty('query', new ToolParameterProperty(
    'string',
    '聚焦搜索关键词或网页 URL。'
  ))
  parameters.addRequired('query')

  const func = new ToolFunction(
    LEGACY_WEB_SEARCH_TOOL_ID,
    '兼容旧版联网搜索工具。新请求会使用 search_web 或 scrape_web。',
    parameters
  )

  return new ToolDefinition(func)
}

function createSearchToolConfig(id: string, name: string, description: string): ToolConfig {
  return new ToolConfig(
    id,
    name,
    description,
    null,
    false,
    false,
    ToolSourceType.BUILTIN,
    'builtin',
    id,
    '内置工具',
    ToolPermissionLevel.READ
  )
}

// 注册所有内置工具
export function registerBuiltinTools(): void {
  const registry = getToolRegistry()
  let registeredNow = 0

  if (!registry.isToolRegistered(LEGACY_WEB_SEARCH_TOOL_ID)) {
    const webSearchTool = new RegisteredTool(
      LEGACY_WEB_SEARCH_TOOL_ID,
      createSearchToolConfig(LEGACY_WEB_SEARCH_TOOL_ID, '联网搜索', '兼容旧版联网搜索调用'),
      createLegacyWebSearchToolDefinition(),
      new LegacyWebSearchExecutor()
    )
    registry.registerTool(webSearchTool)
    registeredNow += 1
  }

  if (!registry.isToolRegistered(SEARCH_WEB_TOOL_ID)) {
    const webSearchTool = new RegisteredTool(
      SEARCH_WEB_TOOL_ID,
      createSearchToolConfig(SEARCH_WEB_TOOL_ID, '联网搜索', '搜索互联网获取最新信息'),
      createSearchWebToolDefinition(),
      new SearchWebExecutor()
    )
    registry.registerTool(webSearchTool)
    registeredNow += 1
  }

  if (!registry.isToolRegistered(SCRAPE_WEB_TOOL_ID)) {
    const scrapeWebTool = new RegisteredTool(
      SCRAPE_WEB_TOOL_ID,
      createSearchToolConfig(SCRAPE_WEB_TOOL_ID, '网页读取', '读取指定网页 URL 内容'),
      createScrapeWebToolDefinition(),
      new ScrapeWebExecutor()
    )
    registry.registerTool(scrapeWebTool)
    registeredNow += 1
  }

  console.info(
    'BuiltinTools',
    `Builtin tools ready: total=${registry.getToolCount()}, newlyRegistered=${registeredNow}`
  )
}

// 获取所有内置工具 ID
export function getBuiltinToolIds(): string[] {
  return [LEGACY_WEB_SEARCH_TOOL_ID, SEARCH_WEB_TOOL_ID, SCRAPE_WEB_TOOL_ID]
}
