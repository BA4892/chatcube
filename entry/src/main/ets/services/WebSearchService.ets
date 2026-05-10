import {
  getHttpService,
  HttpService,
  HttpRequestController,
  HttpRequestRuntimeOptions
} from './HttpService'
import { SearchReference, SearchServiceConfig, SearchEngine } from '../models/ChatModels'
import { getPreferencesService, PreferenceKeys } from './PreferencesService'
import { cleanSearchQuery as cleanSearchQueryShared } from '../utils/SearchQueryUtils'

// 搜索结果类（用于返回给业务层）
export class SearchResult {
  success: boolean
  query: string
  searchEngine: string
  references: SearchReference[]
  contentForAI: string
  errorMessage: string

  constructor(
    success: boolean,
    query: string,
    searchEngine: string,
    references: SearchReference[],
    contentForAI: string,
    errorMessage: string
  ) {
    this.success = success
    this.query = query
    this.searchEngine = searchEngine
    this.references = references
    this.contentForAI = contentForAI
    this.errorMessage = errorMessage
  }
}

// 单个搜索结果项
export class SearchResultItem {
  title: string = ''
  url: string = ''
  snippet: string = ''

  constructor(title: string, url: string, snippet: string) {
    this.title = title
    this.url = url
    this.snippet = snippet
  }
}

// 网页搜索结果类
export class WebSearchResult {
  success: boolean = false
  url: string = ''
  title: string = ''
  content: string = ''
  errorMessage: string = ''
  searchResults: SearchResultItem[] = []
  sourceName: string = ''

  constructor(success: boolean, url: string, title: string, content: string, errorMessage: string,
    searchResults?: SearchResultItem[], sourceName: string = '') {
    this.success = success
    this.url = url
    this.title = title
    this.content = content
    this.errorMessage = errorMessage
    this.sourceName = sourceName
    if (searchResults !== undefined) {
      this.searchResults = searchResults
    }
  }
}

// 运行时配置快照：单次搜索链路内复用，避免重复读取偏好设置
export class SearchRuntimeConfigSnapshot {
  enabled: boolean = true
  searchEngine: SearchEngine = SearchEngine.BING
  maxResults: number = 10
  timeout: number = 5000
  autoTestConnection: boolean = true
  braveApiKey: string = ''
  tavilyApiKey: string = ''
  tavilyBaseUrl: string = 'https://api.tavily.com'
  exaApiKey: string = ''
  exaBaseUrl: string = 'https://api.exa.ai'
}

// 搜索执行选项（可选）
export interface WebSearchExecutionOptions {
  requestId?: string
  runtimeConfig?: SearchRuntimeConfigSnapshot
  cancelCheck?: () => boolean
}

// HTML 解析结果类
class HtmlParseResult {
  title: string = ''
  content: string = ''

  constructor(title: string, content: string) {
    this.title = title
    this.content = content
  }
}

// Bing 搜索结果类（内部使用）
class BingSearchResponse {
  success: boolean = false
  query: string = ''
  results: SearchResultItem[] = []
  errorMessage: string = ''

  constructor(success: boolean, query: string, results: SearchResultItem[], errorMessage: string) {
    this.success = success
    this.query = query
    this.results = results
    this.errorMessage = errorMessage
  }
}

class ExaSearchTextConfig {
  maxCharacters: number = 2500
}

class ExaSearchContentsConfig {
  text: ExaSearchTextConfig = new ExaSearchTextConfig()
}

class ExaSearchRequest {
  query: string = ''
  type: string = 'auto'
  numResults: number = 10
  contents: ExaSearchContentsConfig = new ExaSearchContentsConfig()

  constructor(query: string, numResults: number) {
    this.query = query
    this.numResults = numResults
  }
}

class ExaContentsRequest {
  ids: string[] = []
  text: ExaSearchTextConfig = new ExaSearchTextConfig()

  constructor(url: string) {
    this.ids = [url]
    this.text.maxCharacters = 8000
  }
}

class TavilyExtractRequest {
  urls: string[] = []
  extract_depth: string = 'basic'
  format: string = 'markdown'
  include_images: boolean = false
  timeout: number = 10

  constructor(url: string, extractDepth: string, timeoutSeconds: number) {
    this.urls = [url]
    this.extract_depth = extractDepth
    this.timeout = timeoutSeconds
  }
}

class RequestControllerEntry {
  controller: HttpRequestController
  refCount: number = 1

  constructor(controller: HttpRequestController) {
    this.controller = controller
  }
}

export class WebSearchService {
  private static instance: WebSearchService | null = null
  private httpService: HttpService

  // 保留旧字段，兼容现有调用方
  private config: SearchServiceConfig = new SearchServiceConfig()
  private braveApiKey: string = ''
  private tavilyApiKey: string = ''
  private exaApiKey: string = ''
  private exaBaseUrl: string = 'https://api.exa.ai'

  private requestControllerMap: Map<string, RequestControllerEntry> = new Map()

  private constructor() {
    this.httpService = getHttpService()
  }

  static getInstance(): WebSearchService {
    if (WebSearchService.instance === null) {
      WebSearchService.instance = new WebSearchService()
    }
    return WebSearchService.instance
  }

  private normalizeBaseUrl(raw: string, fallback: string): string {
    const trimmed = raw.trim()
    if (trimmed === '') {
      return fallback
    }
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1)
    }
    return trimmed
  }

  private parseSearchEngine(raw: string): SearchEngine {
    if (raw === SearchEngine.BRAVE) {
      return SearchEngine.BRAVE
    }
    if (raw === SearchEngine.TAVILY) {
      return SearchEngine.TAVILY
    }
    if (raw === SearchEngine.EXA) {
      return SearchEngine.EXA
    }
    if (raw === SearchEngine.CUSTOM) {
      return SearchEngine.CUSTOM
    }
    return SearchEngine.BING
  }

  private normalizeTimeout(raw: number): number {
    if (raw <= 0) {
      return 5000
    }
    if (raw > 60000) {
      return 60000
    }
    return raw
  }

  private normalizeResultCount(raw: number): number {
    if (raw <= 0) {
      return 10
    }
    if (raw > 20) {
      return 20
    }
    return raw
  }

  private applyRuntimeConfig(snapshot: SearchRuntimeConfigSnapshot): void {
    this.config.enabled = snapshot.enabled
    this.config.searchEngine = snapshot.searchEngine
    this.config.maxResults = snapshot.maxResults
    this.config.timeout = snapshot.timeout
    this.config.autoTestConnection = snapshot.autoTestConnection
    this.braveApiKey = snapshot.braveApiKey
    this.tavilyApiKey = snapshot.tavilyApiKey
    this.exaApiKey = snapshot.exaApiKey
    this.exaBaseUrl = snapshot.exaBaseUrl
  }

  // 加载搜索服务配置（旧接口，保留）
  async loadConfig(): Promise<void> {
    const runtime = await this.getRuntimeConfigSnapshot()
    this.applyRuntimeConfig(runtime)
  }

  // 获取单次搜索链路可复用的配置快照
  async getRuntimeConfigSnapshot(): Promise<SearchRuntimeConfigSnapshot> {
    const prefsService = getPreferencesService()
    const snapshot = new SearchRuntimeConfigSnapshot()

    const enabled = await prefsService.getBoolean(PreferenceKeys.SEARCH_SERVICE_ENABLED, false)
    const engine = await prefsService.getString(PreferenceKeys.SEARCH_ENGINE, 'bing')
    const maxResults = await prefsService.getNumber(PreferenceKeys.SEARCH_MAX_RESULTS, 10)
    const timeout = await prefsService.getNumber(PreferenceKeys.SEARCH_TIMEOUT, 5000)
    const autoTest = await prefsService.getBoolean(PreferenceKeys.SEARCH_AUTO_TEST, true)
    const braveApiKey = await prefsService.getString(PreferenceKeys.SEARCH_BRAVE_API_KEY, '')
    const tavilyApiKey = await prefsService.getString(PreferenceKeys.SEARCH_TAVILY_API_KEY, '')
    const tavilyBaseUrl =
      await prefsService.getString(PreferenceKeys.SEARCH_TAVILY_BASE_URL, 'https://api.tavily.com')
    const exaApiKey = await prefsService.getString(PreferenceKeys.SEARCH_EXA_API_KEY, '')
    const exaBaseUrl = await prefsService.getString(PreferenceKeys.SEARCH_EXA_BASE_URL, 'https://api.exa.ai')

    snapshot.enabled = enabled
    snapshot.searchEngine = this.parseSearchEngine(engine)
    snapshot.maxResults = this.normalizeResultCount(maxResults)
    snapshot.timeout = this.normalizeTimeout(timeout)
    snapshot.autoTestConnection = autoTest
    snapshot.braveApiKey = braveApiKey.trim()
    snapshot.tavilyApiKey = tavilyApiKey.trim()
    snapshot.tavilyBaseUrl = this.normalizeBaseUrl(tavilyBaseUrl, 'https://api.tavily.com')
    snapshot.exaApiKey = exaApiKey.trim()
    snapshot.exaBaseUrl = this.normalizeBaseUrl(exaBaseUrl, 'https://api.exa.ai')

    // 同步到旧字段，兼容依赖 this.config 的现有逻辑
    this.applyRuntimeConfig(snapshot)
    return snapshot
  }

  private resolvePreferredEngineName(runtime: SearchRuntimeConfigSnapshot): string {
    if (runtime.searchEngine === SearchEngine.BRAVE) {
      return 'Brave Search'
    }
    if (runtime.searchEngine === SearchEngine.TAVILY) {
      return 'Tavily'
    }
    if (runtime.searchEngine === SearchEngine.EXA && runtime.exaApiKey !== '') {
      return 'Exa'
    }
    return 'Bing(local)'
  }

  async getPreferredEngineName(runtimeConfig?: SearchRuntimeConfigSnapshot): Promise<string> {
    const runtime = runtimeConfig !== undefined ? runtimeConfig : await this.getRuntimeConfigSnapshot()
    return this.resolvePreferredEngineName(runtime)
  }

  async canExposeScrapeWebToModel(runtimeConfig?: SearchRuntimeConfigSnapshot): Promise<boolean> {
    const runtime = runtimeConfig !== undefined ? runtimeConfig : await this.getRuntimeConfigSnapshot()
    if (!runtime.enabled) {
      return false
    }
    if (runtime.searchEngine === SearchEngine.TAVILY) {
      return runtime.tavilyApiKey !== ''
    }
    if (runtime.searchEngine === SearchEngine.EXA) {
      return runtime.exaApiKey !== ''
    }
    return false
  }

  private acquireRequestController(requestId: string): HttpRequestController | null {
    if (requestId === '') {
      return null
    }

    const existing = this.requestControllerMap.get(requestId)
    if (existing !== undefined) {
      existing.refCount += 1
      return existing.controller
    }

    const controller = new HttpRequestController()
    this.requestControllerMap.set(requestId, new RequestControllerEntry(controller))
    return controller
  }

  private releaseRequestController(requestId: string): void {
    if (requestId === '') {
      return
    }

    const existing = this.requestControllerMap.get(requestId)
    if (existing === undefined) {
      return
    }

    existing.refCount -= 1
    if (existing.refCount <= 0) {
      this.requestControllerMap.delete(requestId)
    }
  }

  cancelRequest(requestId: string): void {
    if (requestId === '') {
      return
    }
    const existing = this.requestControllerMap.get(requestId)
    if (existing === undefined) {
      return
    }
    existing.controller.cancelAll()
    this.requestControllerMap.delete(requestId)
  }

  cancelAllRequests(): void {
    this.requestControllerMap.forEach((entry: RequestControllerEntry) => {
      entry.controller.cancelAll()
    })
    this.requestControllerMap.clear()
  }

  private isCancelled(controller: HttpRequestController | null, cancelCheck?: () => boolean): boolean {
    if (controller !== null && controller.isCancelled()) {
      return true
    }
    if (cancelCheck !== undefined && cancelCheck()) {
      if (controller !== null) {
        controller.cancelAll()
      }
      return true
    }
    return false
  }

  private buildHttpOptions(timeout: number, controller: HttpRequestController | null): HttpRequestRuntimeOptions {
    const options: HttpRequestRuntimeOptions = { timeout: this.normalizeTimeout(timeout) }
    if (controller !== null) {
      options.controller = controller
    }
    return options
  }

  private buildCancelledSearchResult(query: string, engineName: string): SearchResult {
    return new SearchResult(
      false,
      query,
      engineName,
      [],
      '',
      '请求已取消'
    )
  }

  private buildCancelledWebResult(url: string): WebSearchResult {
    return new WebSearchResult(false, url, '', '', '请求已取消')
  }

  // 统一搜索接口
  async search(query: string, options?: WebSearchExecutionOptions): Promise<SearchResult> {
    const runtime = options?.runtimeConfig !== undefined ? options.runtimeConfig : await this.getRuntimeConfigSnapshot()
    const requestId = options?.requestId !== undefined ? options.requestId : ''
    const cancelCheck = options?.cancelCheck
    const controller = this.acquireRequestController(requestId)

    try {
      if (this.isCancelled(controller, cancelCheck)) {
        return this.buildCancelledSearchResult(query, this.resolvePreferredEngineName(runtime))
      }

      if (!runtime.enabled) {
        return new SearchResult(false, query, this.resolvePreferredEngineName(runtime), [], '', '搜索服务未启用')
      }

      const cleanedQuery = cleanSearchQueryShared(query)
      if (cleanedQuery !== query) {
        console.info('WebSearchService', `Search query cleaned: "${query}" -> "${cleanedQuery}"`)
      }

      // 天气类查询：强制使用更可解析/更权威站点，避免结果被“查/查重/天眼查”等噪声污染
      let finalQuery = cleanedQuery
      if (this.isWeatherIntent(cleanedQuery)) {
        finalQuery = this.buildWeatherSiteQuery(cleanedQuery)
        if (finalQuery !== cleanedQuery) {
          console.info('WebSearchService', `Weather query rewritten: "${cleanedQuery}" -> "${finalQuery}"`)
        }
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return this.buildCancelledSearchResult(finalQuery, this.resolvePreferredEngineName(runtime))
      }

      if (runtime.searchEngine === SearchEngine.EXA) {
        const exaResult = await this.exaSearchEnhanced(finalQuery, runtime, controller, cancelCheck)
        if (exaResult.success) {
          return exaResult
        }
        if (this.isCancelled(controller, cancelCheck)) {
          return this.buildCancelledSearchResult(finalQuery, 'Exa')
        }
        console.warn('WebSearchService', `[Exa] Failed, fallback to Bing: ${exaResult.errorMessage}`)
        const bingFallback = await this.bingSearchEnhanced(finalQuery, runtime, controller, cancelCheck)
        if (bingFallback.success) {
          return bingFallback
        }
        return exaResult
      }

      if (runtime.searchEngine === SearchEngine.BRAVE) {
        return await this.braveSearchEnhanced(finalQuery, runtime, controller, cancelCheck)
      }

      if (runtime.searchEngine === SearchEngine.TAVILY) {
        return await this.tavilySearchEnhanced(finalQuery, runtime, controller, cancelCheck)
      }

      return await this.bingSearchEnhanced(finalQuery, runtime, controller, cancelCheck)
    } finally {
      this.releaseRequestController(requestId)
    }
  }

  private async bingSearchEnhanced(
    query: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<SearchResult> {
    const response = await this.bingSearchInternal(query, runtime.maxResults, runtime, controller, cancelCheck)

    if (!response.success) {
      return new SearchResult(
        false,
        query,
        'Bing(local)',
        [],
        '',
        response.errorMessage
      )
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Bing(local)')
    }

    const weatherIntent = this.isWeatherIntent(query)

    // 天气类查询：如果强制站点仍然无结果，回退到备用站点再搜一次
    let effectiveResponse = response
    if (effectiveResponse.results.length === 0 && weatherIntent) {
      const fallbackQuery = this.buildWeatherFallbackQuery(query)
      if (fallbackQuery !== '' && fallbackQuery !== query) {
        const fallbackResp = await this.bingSearchInternal(fallbackQuery, runtime.maxResults, runtime, controller, cancelCheck)
        if (fallbackResp.success && fallbackResp.results.length > 0) {
          effectiveResponse = fallbackResp
        }
      }
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Bing(local)')
    }

    // 天气/实时数据类问题：抓取网页正文摘要供模型提取数值
    let enriched = ''
    if (weatherIntent && effectiveResponse.results.length > 0) {
      enriched = await this.enrichTopPagesForAI(effectiveResponse.results, 2, runtime, controller, cancelCheck)
      if (enriched === '') {
        const fallbackQuery = this.buildWeatherFallbackQuery(effectiveResponse.query)
        if (fallbackQuery !== '' && fallbackQuery !== effectiveResponse.query) {
          const fallbackResp = await this.bingSearchInternal(fallbackQuery, runtime.maxResults, runtime, controller, cancelCheck)
          if (fallbackResp.success && fallbackResp.results.length > 0) {
            effectiveResponse = fallbackResp
            enriched = await this.enrichTopPagesForAI(effectiveResponse.results, 2, runtime, controller, cancelCheck)
          }
        }
      }
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Bing(local)')
    }

    const references: SearchReference[] = []
    for (let i = 0; i < effectiveResponse.results.length; i++) {
      const item = effectiveResponse.results[i]
      references.push(new SearchReference(
        `ref_${Date.now()}_${i}`,
        item.title,
        item.url,
        item.snippet
      ))
    }

    let contentForAI = this.buildContentForAI(effectiveResponse.results)

    if (weatherIntent && enriched !== '') {
      contentForAI += '\n' + enriched
    }

    contentForAI = this.limitPromptContent(contentForAI, 6000)

    return new SearchResult(
      true,
      effectiveResponse.query,
      'Bing(local)',
      references,
      contentForAI,
      ''
    )
  }

  private async exaSearchEnhanced(
    query: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<SearchResult> {
    if (runtime.exaApiKey === '') {
      return new SearchResult(
        false,
        query,
        'Exa',
        [],
        '',
        'Exa API Key 未配置'
      )
    }

    const response = await this.exaSearch(query, runtime.maxResults, runtime, controller, cancelCheck)
    if (!response.success) {
      return new SearchResult(
        false,
        query,
        'Exa',
        [],
        '',
        response.errorMessage
      )
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Exa')
    }

    const references: SearchReference[] = []
    for (let i = 0; i < response.results.length; i++) {
      const item = response.results[i]
      references.push(new SearchReference(
        `ref_${Date.now()}_${i}`,
        item.title,
        item.url,
        item.snippet
      ))
    }

    const contentForAI = this.limitPromptContent(this.buildContentForAI(response.results), 6000)
    return new SearchResult(
      true,
      query,
      'Exa',
      references,
      contentForAI,
      ''
    )
  }

  private async braveSearchEnhanced(
    query: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<SearchResult> {
    if (runtime.braveApiKey === '') {
      return new SearchResult(
        false,
        query,
        'Brave Search',
        [],
        '',
        'Brave API Key 未配置'
      )
    }

    const response = await this.braveSearch(query, runtime.maxResults, runtime, controller, cancelCheck)
    if (!response.success) {
      return new SearchResult(
        false,
        query,
        'Brave Search',
        [],
        '',
        response.errorMessage
      )
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Brave Search')
    }

    const references: SearchReference[] = []
    for (let i = 0; i < response.results.length; i++) {
      const item = response.results[i]
      references.push(new SearchReference(
        `ref_${Date.now()}_${i}`,
        item.title,
        item.url,
        item.snippet
      ))
    }

    return new SearchResult(
      true,
      query,
      'Brave Search',
      references,
      this.limitPromptContent(this.buildContentForAI(response.results), 6000),
      ''
    )
  }

  private async tavilySearchEnhanced(
    query: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<SearchResult> {
    if (runtime.tavilyApiKey === '') {
      return new SearchResult(
        false,
        query,
        'Tavily',
        [],
        '',
        'Tavily API Key 未配置'
      )
    }

    const response = await this.tavilySearch(query, runtime.maxResults, runtime, controller, cancelCheck)
    if (!response.success) {
      return new SearchResult(
        false,
        query,
        'Tavily',
        [],
        '',
        response.errorMessage
      )
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledSearchResult(query, 'Tavily')
    }

    const references: SearchReference[] = []
    for (let i = 0; i < response.results.length; i++) {
      const item = response.results[i]
      references.push(new SearchReference(
        `ref_${Date.now()}_${i}`,
        item.title,
        item.url,
        item.snippet
      ))
    }

    return new SearchResult(
      true,
      query,
      'Tavily',
      references,
      this.limitPromptContent(this.buildContentForAI(response.results), 6000),
      ''
    )
  }

  private async braveSearch(
    query: string,
    resultCount: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<BingSearchResponse> {
    try {
      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const searchUrl =
        `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=${this.normalizeResultCount(resultCount)}`
      const response = await this.httpService.get(
        searchUrl,
        {
          'Accept': 'application/json',
          'X-Subscription-Token': runtime.braveApiKey
        },
        this.buildHttpOptions(runtime.timeout, controller)
      )

      if (!response.success) {
        return new BingSearchResponse(false, query, [], response.errorMessage)
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const errorMessage = this.extractBraveErrorMessage(response.data)
      if (errorMessage !== '') {
        return new BingSearchResponse(false, query, [], errorMessage)
      }

      return new BingSearchResponse(
        true,
        query,
        this.parseBraveSearchResults(response.data, this.normalizeResultCount(resultCount)),
        ''
      )
    } catch (error) {
      return new BingSearchResponse(false, query, [], `Brave 搜索失败: ${JSON.stringify(error)}`)
    }
  }

  private async tavilySearch(
    query: string,
    resultCount: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<BingSearchResponse> {
    try {
      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const response = await this.httpService.postWithTimeout(
        this.buildTavilyEndpointUrl(runtime.tavilyBaseUrl, 'search'),
        JSON.stringify({
          query: query,
          topic: 'general',
          search_depth: 'basic',
          max_results: this.normalizeResultCount(resultCount),
          include_answer: false,
          include_images: false,
          include_raw_content: false
        }),
        this.buildTavilyHeaders(runtime),
        runtime.timeout,
        this.buildHttpOptions(runtime.timeout, controller)
      )

      if (!response.success) {
        return new BingSearchResponse(false, query, [], response.errorMessage)
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const errorMessage = this.extractTavilyErrorMessage(response.data)
      if (errorMessage !== '') {
        return new BingSearchResponse(false, query, [], errorMessage)
      }

      return new BingSearchResponse(
        true,
        query,
        this.parseTavilySearchResults(response.data, this.normalizeResultCount(resultCount)),
        ''
      )
    } catch (error) {
      return new BingSearchResponse(false, query, [], `Tavily 搜索失败: ${JSON.stringify(error)}`)
    }
  }

  private buildTavilyHeaders(runtime: SearchRuntimeConfigSnapshot): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': `Bearer ${runtime.tavilyApiKey}`
    }
  }

  private buildExaHeaders(runtime: SearchRuntimeConfigSnapshot): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': runtime.exaApiKey
    }
  }

  private stripKnownTavilyEndpoint(url: string): string {
    const endpoints: string[] = ['/search', '/extract', '/map', '/crawl', '/research', '/usage']
    for (let i = 0; i < endpoints.length; i++) {
      if (url.endsWith(endpoints[i])) {
        return url.substring(0, url.length - endpoints[i].length)
      }
    }
    return url
  }

  private stripKnownExaEndpoint(url: string): string {
    const endpoints: string[] = ['/search', '/contents']
    for (let i = 0; i < endpoints.length; i++) {
      if (url.endsWith(endpoints[i])) {
        return url.substring(0, url.length - endpoints[i].length)
      }
    }
    return url
  }

  private buildTavilyEndpointUrl(baseUrl: string, endpoint: string): string {
    const normalized = this.normalizeBaseUrl(baseUrl, 'https://api.tavily.com')
    const base = this.stripKnownTavilyEndpoint(normalized)
    return `${base}/${endpoint}`
  }

  private buildExaEndpointUrl(baseUrl: string, endpoint: string): string {
    const normalized = this.normalizeBaseUrl(baseUrl, 'https://api.exa.ai')
    const base = this.stripKnownExaEndpoint(normalized)
    return `${base}/${endpoint}`
  }

  private getTavilyExtractApiTimeoutSeconds(depth: string): number {
    return depth === 'advanced' ? 30 : 10
  }

  private getTavilyExtractHttpTimeoutMs(runtimeTimeout: number, depth: string): number {
    const apiTimeoutMs = this.getTavilyExtractApiTimeoutSeconds(depth) * 1000
    return Math.max(this.normalizeTimeout(runtimeTimeout), apiTimeoutMs + 5000)
  }

  private async tavilyExtractUrlContent(
    url: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<WebSearchResult> {
    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledWebResult(url)
    }

    if (!this.isValidUrl(url)) {
      return new WebSearchResult(false, url, '', '', 'URL 格式无效')
    }

    const fullUrl = this.normalizeContentUrl(url)
    const basicResult = await this.tavilyExtractUrlContentByDepth(fullUrl, runtime, controller, cancelCheck, 'basic')
    if (basicResult.success || this.isCancelled(controller, cancelCheck) ||
      !this.shouldRetryTavilyExtractWithAdvanced(basicResult.errorMessage)) {
      return basicResult
    }

    console.warn('WebSearchService', `[Tavily Extract] Basic failed, retry advanced: ${basicResult.errorMessage}`)
    const advancedResult = await this.tavilyExtractUrlContentByDepth(
      fullUrl,
      runtime,
      controller,
      cancelCheck,
      'advanced'
    )
    if (advancedResult.success || this.isCancelled(controller, cancelCheck)) {
      return advancedResult
    }

    return new WebSearchResult(
      false,
      fullUrl,
      '',
      '',
      `Tavily Extract basic 失败: ${basicResult.errorMessage}; advanced 失败: ${advancedResult.errorMessage}`,
      undefined,
      'Tavily Extract'
    )
  }

  private async tavilyExtractUrlContentByDepth(
    fullUrl: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck: (() => boolean) | undefined,
    depth: string
  ): Promise<WebSearchResult> {
    try {
      const timeout = this.getTavilyExtractHttpTimeoutMs(runtime.timeout, depth)
      const request = new TavilyExtractRequest(
        fullUrl,
        depth,
        this.getTavilyExtractApiTimeoutSeconds(depth)
      )
      console.info(
        'WebSearchService',
        `[Tavily Extract] POST ${this.buildTavilyEndpointUrl(runtime.tavilyBaseUrl, 'extract')} depth=${depth}`
      )
      const response = await this.httpService.postWithTimeout(
        this.buildTavilyEndpointUrl(runtime.tavilyBaseUrl, 'extract'),
        JSON.stringify(request),
        this.buildTavilyHeaders(runtime),
        timeout,
        this.buildHttpOptions(timeout, controller)
      )

      if (!response.success) {
        return new WebSearchResult(false, fullUrl, '', '', response.errorMessage, undefined, 'Tavily Extract')
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return this.buildCancelledWebResult(fullUrl)
      }

      const errorMessage = this.extractTavilyErrorMessage(response.data)
      if (errorMessage !== '') {
        return new WebSearchResult(false, fullUrl, '', '', errorMessage, undefined, 'Tavily Extract')
      }

      return this.parseTavilyExtractResult(response.data, fullUrl)
    } catch (error) {
      return new WebSearchResult(
        false,
        fullUrl,
        '',
        '',
        `Tavily Extract 失败: ${JSON.stringify(error)}`,
        undefined,
        'Tavily Extract'
      )
    }
  }

  private shouldRetryTavilyExtractWithAdvanced(errorMessage: string): boolean {
    if (errorMessage === '') {
      return true
    }
    const lower = errorMessage.toLowerCase()
    if (lower.includes('401') || lower.includes('403') || lower.includes('api key') ||
      lower.includes('unauthorized') || lower.includes('forbidden') || lower.includes('quota') ||
      lower.includes('credit') || lower.includes('rate limit') || lower.includes('请求已取消')) {
      return false
    }
    return true
  }

  private async exaSearch(
    query: string,
    resultCount: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<BingSearchResponse> {
    try {
      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const request = new ExaSearchRequest(query, this.normalizeResultCount(resultCount))
      const body = JSON.stringify(request)
      const response = await this.httpService.postWithTimeout(
        this.buildExaEndpointUrl(runtime.exaBaseUrl, 'search'),
        body,
        this.buildExaHeaders(runtime),
        runtime.timeout,
        this.buildHttpOptions(runtime.timeout, controller)
      )

      if (!response.success) {
        return new BingSearchResponse(false, query, [], response.errorMessage)
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const errorMessage = this.extractExaErrorMessage(response.data)
      if (errorMessage !== '') {
        return new BingSearchResponse(false, query, [], errorMessage)
      }

      const results = this.parseExaSearchResults(response.data, this.normalizeResultCount(resultCount))
      return new BingSearchResponse(true, query, results, '')
    } catch (error) {
      return new BingSearchResponse(false, query, [], `Exa 搜索失败: ${JSON.stringify(error)}`)
    }
  }

  private async exaFetchUrlContent(
    url: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<WebSearchResult> {
    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledWebResult(url)
    }

    if (!this.isValidUrl(url)) {
      return new WebSearchResult(false, url, '', '', 'URL 格式无效', undefined, 'Exa Contents')
    }

    if (runtime.exaApiKey === '') {
      return new WebSearchResult(false, url, '', '', 'Exa API Key 未配置，无法调用 Contents', undefined, 'Exa Contents')
    }

    const fullUrl = this.normalizeContentUrl(url)
    try {
      const request = new ExaContentsRequest(fullUrl)
      console.info('WebSearchService', `[Exa Contents] POST ${this.buildExaEndpointUrl(runtime.exaBaseUrl, 'contents')}`)
      const response = await this.httpService.postWithTimeout(
        this.buildExaEndpointUrl(runtime.exaBaseUrl, 'contents'),
        JSON.stringify(request),
        this.buildExaHeaders(runtime),
        this.normalizeTimeout(runtime.timeout),
        this.buildHttpOptions(runtime.timeout, controller)
      )

      if (!response.success) {
        return new WebSearchResult(false, fullUrl, '', '', response.errorMessage, undefined, 'Exa Contents')
      }

      if (this.isCancelled(controller, cancelCheck)) {
        return this.buildCancelledWebResult(fullUrl)
      }

      const errorMessage = this.extractExaErrorMessage(response.data)
      if (errorMessage !== '') {
        return new WebSearchResult(false, fullUrl, '', '', errorMessage, undefined, 'Exa Contents')
      }

      return this.parseExaContentsResult(response.data, fullUrl)
    } catch (error) {
      return new WebSearchResult(
        false,
        fullUrl,
        '',
        '',
        `Exa Contents 失败: ${JSON.stringify(error)}`,
        undefined,
        'Exa Contents'
      )
    }
  }

  private extractBraveErrorMessage(json: string): string {
    if (json === '') {
      return ''
    }
    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const error = parsed['error']
      if (error === undefined || error === null) {
        return ''
      }
      if (typeof error === 'string') {
        return error
      }
      if (typeof error === 'object') {
        const errorObj = error as Record<string, Object>
        const message = this.readStringFromObject(errorObj, 'message')
        if (message !== '') {
          return message
        }
        return JSON.stringify(errorObj)
      }
      return JSON.stringify(error)
    } catch (_error) {
      return ''
    }
  }

  private extractTavilyErrorMessage(json: string): string {
    if (json === '') {
      return ''
    }
    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const detail = parsed['detail']
      if (detail !== undefined && detail !== null) {
        if (typeof detail === 'string') {
          return detail
        }
        return JSON.stringify(detail)
      }
      const message = this.readStringFromObject(parsed, 'message')
      if (message !== '') {
        return message
      }
      const error = parsed['error']
      if (error === undefined || error === null) {
        return ''
      }
      if (typeof error === 'string') {
        return error
      }
      if (typeof error === 'object') {
        const errorObj = error as Record<string, Object>
        const message = this.readStringFromObject(errorObj, 'message')
        if (message !== '') {
          return message
        }
        return JSON.stringify(errorObj)
      }
      return JSON.stringify(error)
    } catch (_error) {
      return ''
    }
  }

  private parseBraveSearchResults(json: string, maxCount: number): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (json === '') {
      return results
    }

    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const web = parsed['web']
      if (web === undefined || web === null || typeof web !== 'object' || Array.isArray(web)) {
        return results
      }
      const webObj = web as Record<string, Object>
      const resultsValue = webObj['results']
      if (resultsValue === undefined || resultsValue === null || !Array.isArray(resultsValue)) {
        return results
      }

      const list = resultsValue as Object[]
      for (let i = 0; i < list.length && results.length < maxCount; i++) {
        const item = list[i]
        if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
          continue
        }
        const itemObj = item as Record<string, Object>
        const title = this.readStringFromObject(itemObj, 'title').trim()
        const url = this.readStringFromObject(itemObj, 'url').trim()
        const snippet = this.normalizeSnippet(this.readStringFromObject(itemObj, 'description'))
        if (title === '' || url === '') {
          continue
        }
        results.push(new SearchResultItem(title, url, snippet))
      }
    } catch (error) {
      console.error('WebSearchService', `Parse Brave results failed: ${JSON.stringify(error)}`)
    }

    return results
  }

  private parseTavilySearchResults(json: string, maxCount: number): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (json === '') {
      return results
    }

    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const resultsValue = parsed['results']
      if (resultsValue === undefined || resultsValue === null || !Array.isArray(resultsValue)) {
        return results
      }

      const list = resultsValue as Object[]
      for (let i = 0; i < list.length && results.length < maxCount; i++) {
        const item = list[i]
        if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
          continue
        }
        const itemObj = item as Record<string, Object>
        const title = this.readStringFromObject(itemObj, 'title').trim()
        const url = this.readStringFromObject(itemObj, 'url').trim()
        const snippet = this.normalizeSnippet(this.readStringFromObject(itemObj, 'content'))
        if (title === '' || url === '') {
          continue
        }
        results.push(new SearchResultItem(title, url, snippet))
      }
    } catch (error) {
      console.error('WebSearchService', `Parse Tavily results failed: ${JSON.stringify(error)}`)
    }

    return results
  }

  private parseTavilyExtractResult(json: string, fallbackUrl: string): WebSearchResult {
    if (json === '') {
      return new WebSearchResult(false, fallbackUrl, '', '', 'Tavily Extract 未返回内容')
    }

    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const resultsValue = parsed['results']
      if (resultsValue !== undefined && resultsValue !== null && Array.isArray(resultsValue)) {
        const list = resultsValue as Object[]
        for (let i = 0; i < list.length; i++) {
          const item = list[i]
          if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
            continue
          }
          const itemObj = item as Record<string, Object>
          const content = this.extractTavilyExtractContent(itemObj)
          if (content === '') {
            continue
          }
          const resultUrl = this.readStringFromObject(itemObj, 'url')
          const resolvedUrl = resultUrl !== '' ? resultUrl : fallbackUrl
          let title = this.readStringFromObject(itemObj, 'title').trim()
          if (title === '') {
            title = this.extractTitleFromTextContent(content, resolvedUrl)
          }
          return new WebSearchResult(
            true,
            resolvedUrl,
            title,
            this.limitExtractedContent(content),
            '',
            undefined,
            'Tavily Extract'
          )
        }
      }

      const failedMessage = this.extractTavilyFailedResultMessage(parsed)
      if (failedMessage !== '') {
        return new WebSearchResult(false, fallbackUrl, '', '', failedMessage)
      }
    } catch (error) {
      console.error('WebSearchService', `Parse Tavily extract failed: ${JSON.stringify(error)}`)
      return new WebSearchResult(false, fallbackUrl, '', '', `Tavily Extract 解析失败: ${JSON.stringify(error)}`)
    }

    return new WebSearchResult(false, fallbackUrl, '', '', 'Tavily Extract 未返回正文')
  }

  private extractTavilyExtractContent(itemObj: Record<string, Object>): string {
    const rawContent = this.readStringFromObject(itemObj, 'raw_content').trim()
    if (rawContent !== '') {
      return rawContent
    }

    const content = this.readStringFromObject(itemObj, 'content').trim()
    if (content !== '') {
      return content
    }

    return this.readStringFromObject(itemObj, 'text').trim()
  }

  private extractTavilyFailedResultMessage(parsed: Record<string, Object>): string {
    const failedResults = parsed['failed_results']
    if (failedResults === undefined || failedResults === null || !Array.isArray(failedResults)) {
      return ''
    }

    const list = failedResults as Object[]
    for (let i = 0; i < list.length; i++) {
      const item = list[i]
      if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
        continue
      }
      const itemObj = item as Record<string, Object>
      const error = this.readStringFromObject(itemObj, 'error')
      if (error !== '') {
        return error
      }
    }
    return ''
  }

  private extractTitleFromTextContent(content: string, fallbackUrl: string): string {
    const headingMatch = /^#{1,6}\s+(.+)$/m.exec(content)
    if (headingMatch !== null && headingMatch[1] !== undefined) {
      const title = headingMatch[1].trim()
      if (title !== '') {
        return title
      }
    }
    return fallbackUrl
  }

  private limitExtractedContent(content: string): string {
    const maxContentLength = 8000
    if (content.length <= maxContentLength) {
      return content
    }
    return content.substring(0, maxContentLength) + '...'
  }

  private extractExaErrorMessage(json: string): string {
    if (json === '') {
      return ''
    }
    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const error = parsed['error']
      if (error === undefined || error === null) {
        return ''
      }
      if (typeof error === 'string') {
        return error
      }
      if (typeof error === 'object') {
        const errorObj = error as Record<string, Object>
        const message = this.readStringFromObject(errorObj, 'message')
        if (message !== '') {
          return message
        }
        return JSON.stringify(errorObj)
      }
      return JSON.stringify(error)
    } catch (_error) {
      return ''
    }
  }

  private parseExaSearchResults(json: string, maxCount: number): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (json === '') {
      return results
    }

    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const resultsValue = parsed['results']
      if (resultsValue === undefined || resultsValue === null || !Array.isArray(resultsValue)) {
        return results
      }

      const list = resultsValue as Object[]
      for (let i = 0; i < list.length && results.length < maxCount; i++) {
        const item = list[i]
        if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
          continue
        }
        const itemObj = item as Record<string, Object>
        const title = this.readStringFromObject(itemObj, 'title')
        const url = this.readStringFromObject(itemObj, 'url')
        const snippet = this.extractExaSnippet(itemObj)

        if (title === '' || url === '') {
          continue
        }
        results.push(new SearchResultItem(title, url, snippet))
      }
    } catch (error) {
      console.error('WebSearchService', `Parse Exa results failed: ${JSON.stringify(error)}`)
    }

    return results
  }

  private parseExaContentsResult(json: string, fallbackUrl: string): WebSearchResult {
    if (json === '') {
      return new WebSearchResult(false, fallbackUrl, '', '', 'Exa Contents 未返回内容', undefined, 'Exa Contents')
    }

    try {
      const parsed = JSON.parse(json) as Record<string, Object>
      const resultsValue = parsed['results']
      if (resultsValue !== undefined && resultsValue !== null && Array.isArray(resultsValue)) {
        const list = resultsValue as Object[]
        for (let i = 0; i < list.length; i++) {
          const item = list[i]
          if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
            continue
          }
          const itemObj = item as Record<string, Object>
          const content = this.extractExaContentsContent(itemObj)
          if (content === '') {
            continue
          }
          const resultUrl = this.readStringFromObject(itemObj, 'url')
          const resolvedUrl = resultUrl !== '' ? resultUrl : fallbackUrl
          let title = this.readStringFromObject(itemObj, 'title').trim()
          if (title === '') {
            title = this.extractTitleFromTextContent(content, resolvedUrl)
          }
          return new WebSearchResult(
            true,
            resolvedUrl,
            title,
            this.limitExtractedContent(content),
            '',
            undefined,
            'Exa Contents'
          )
        }
      }
    } catch (error) {
      console.error('WebSearchService', `Parse Exa contents failed: ${JSON.stringify(error)}`)
      return new WebSearchResult(false, fallbackUrl, '', '', `Exa Contents 解析失败: ${JSON.stringify(error)}`,
        undefined, 'Exa Contents')
    }

    return new WebSearchResult(false, fallbackUrl, '', '', 'Exa Contents 未返回正文', undefined, 'Exa Contents')
  }

  private extractExaContentsContent(itemObj: Record<string, Object>): string {
    const text = this.readStringFromObject(itemObj, 'text').trim()
    if (text !== '') {
      return text
    }

    const summary = this.readStringFromObject(itemObj, 'summary').trim()
    if (summary !== '') {
      return summary
    }

    const highlights = itemObj['highlights']
    if (highlights !== undefined && highlights !== null && Array.isArray(highlights)) {
      const parts: string[] = []
      const list = highlights as Object[]
      for (let i = 0; i < list.length; i++) {
        if (typeof list[i] === 'string') {
          const value = (list[i] as string).trim()
          if (value !== '') {
            parts.push(value)
          }
        }
      }
      if (parts.length > 0) {
        return parts.join('\n\n')
      }
    }

    return ''
  }

  private extractExaSnippet(itemObj: Record<string, Object>): string {
    const summary = this.readStringFromObject(itemObj, 'summary')
    if (summary !== '') {
      return this.normalizeSnippet(summary)
    }

    const text = this.readStringFromObject(itemObj, 'text')
    if (text !== '') {
      return this.normalizeSnippet(text)
    }

    const highlights = itemObj['highlights']
    if (highlights !== undefined && highlights !== null && Array.isArray(highlights)) {
      const list = highlights as Object[]
      for (let i = 0; i < list.length; i++) {
        if (typeof list[i] === 'string') {
          return this.normalizeSnippet(list[i] as string)
        }
      }
    }

    return ''
  }

  private normalizeSnippet(raw: string): string {
    const trimmed = raw.replace(/\s+/g, ' ').trim()
    if (trimmed.length <= 220) {
      return trimmed
    }
    return trimmed.substring(0, 220) + '...'
  }

  private readStringFromObject(obj: Record<string, Object>, key: string): string {
    const value = obj[key]
    if (value === undefined || value === null) {
      return ''
    }
    if (typeof value === 'string') {
      return value
    }
    return ''
  }

  private buildWeatherSiteQuery(query: string): string {
    if (query.includes('site:')) {
      return query
    }
    const city = this.extractCityFromWeatherQuery(query)
    const base = city !== '' ? `${city} 天气预报` : '天气预报'
    return `${base} site:weather.com.cn`
  }

  private buildWeatherFallbackQuery(query: string): string {
    if (query.includes('site:')) {
      const withoutSite = query.replace(/site:[^\s]+/g, '').trim()
      const city = this.extractCityFromWeatherQuery(withoutSite)
      const base = city !== '' ? `${city} 天气预报` : '天气预报'
      return `${base} site:nmc.cn`
    }
    const city = this.extractCityFromWeatherQuery(query)
    const base = city !== '' ? `${city} 天气预报` : '天气预报'
    return `${base} site:nmc.cn`
  }

  private extractCityFromWeatherQuery(query: string): string {
    let q = query.trim().replace(/\s+/g, ' ')
    q = q.replace(/site:[^\s]+/g, '').trim()
    q = q.replace(/(今天|今日|现在|当前|明天|后天)/g, '').trim()

    const match = /^(.*?)(?:的)?(?:天气预报|天气|气温|温度)/.exec(q)
    if (match && match[1] !== undefined) {
      const city = match[1].trim()
      if (city !== '') {
        return city
      }
    }

    const parts = q.split(' ')
    return parts.length > 0 ? parts[0].trim() : ''
  }

  private isWeatherIntent(text: string): boolean {
    const t = text.replace(/\s+/g, '')
    if (t.includes('weather.com.cn') || t.includes('nmc.cn')) {
      return true
    }
    const keywords: string[] = [
      '天气', '天气预报', '气温', '温度', '降雨', '降水', '湿度', '风速', '风力', '空气质量', 'AQI', 'PM2.5'
    ]
    for (let i = 0; i < keywords.length; i++) {
      if (t.includes(keywords[i])) {
        return true
      }
    }
    return false
  }

  private async enrichTopPagesForAI(
    results: SearchResultItem[],
    maxFetch: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<string> {
    const candidates: SearchResultItem[] = []
    for (let i = 0; i < results.length; i++) {
      if (candidates.length >= maxFetch) {
        break
      }
      const item = results[i]
      if (item.url === '' || this.isBingInternalUrl(item.url)) {
        continue
      }
      candidates.push(item)
    }

    if (candidates.length === 0) {
      return ''
    }

    const tasks: Promise<string>[] = []
    for (let i = 0; i < candidates.length; i++) {
      tasks.push(this.fetchSinglePageSummary(candidates[i].url, runtime, controller, cancelCheck))
    }

    const summaries = await Promise.all(tasks)
    const validSummaries: string[] = []
    for (let i = 0; i < summaries.length; i++) {
      if (summaries[i] !== '') {
        validSummaries.push(summaries[i])
      }
    }

    return validSummaries.join('\n').trim()
  }

  private async fetchSinglePageSummary(
    url: string,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<string> {
    if (this.isCancelled(controller, cancelCheck)) {
      return ''
    }

    try {
      const webResult = await this.fetchUrlContentInternal(url, runtime.timeout, controller, cancelCheck)
      if (!webResult.success) {
        return ''
      }
      if (webResult.content.trim() === '' || webResult.content.includes('无法提取正文内容')) {
        return ''
      }

      let text = webResult.content
      const maxLen = 1200
      if (text.length > maxLen) {
        text = text.substring(0, maxLen) + '...'
      }

      return `抓取到的网页正文摘要（用于提取具体数据）:\n标题: ${webResult.title}\n来源: ${webResult.url}\n${text}`
    } catch (_error) {
      return ''
    }
  }

  private limitPromptContent(content: string, maxChars: number): string {
    if (content.length <= maxChars) {
      return content
    }
    return content.substring(0, maxChars) + '\n\n[搜索上下文已截断]'
  }

  // 构建给 AI 的内容（限制总长度，避免上下文过大）
  private buildContentForAI(results: SearchResultItem[]): string {
    let content = '以下是搜索结果:\n\n'
    const maxChars = 3800

    for (let i = 0; i < results.length; i++) {
      const item = results[i]
      const block = `${i + 1}. ${item.title}\n   ${item.snippet}\n   来源: ${item.url}\n\n`
      if ((content + block).length > maxChars) {
        content += '[更多结果已省略]\n'
        break
      }
      content += block
    }
    return content
  }

  // ========== Bing 搜索功能 ==========
  // 执行 Bing 搜索（公开接口，兼容旧调用）
  async bingSearch(
    query: string,
    resultCount: number = 5,
    runtimeConfig?: SearchRuntimeConfigSnapshot,
    options?: WebSearchExecutionOptions
  ): Promise<BingSearchResponse> {
    const runtime = runtimeConfig !== undefined ? runtimeConfig : await this.getRuntimeConfigSnapshot()
    const requestId = options?.requestId !== undefined ? options.requestId : ''
    const controller = this.acquireRequestController(requestId)

    try {
      return await this.bingSearchInternal(query, resultCount, runtime, controller, options?.cancelCheck)
    } finally {
      this.releaseRequestController(requestId)
    }
  }

  private async bingSearchInternal(
    query: string,
    resultCount: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<BingSearchResponse> {
    try {
      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      const encodedQuery = encodeURIComponent(query)
      const primaryUrl = `https://www.bing.com/search?q=${encodedQuery}&setlang=zh-hans`
      const primaryResponse = await this.bingSearchByUrl(primaryUrl, query, resultCount, runtime, controller, cancelCheck)

      if (this.isCancelled(controller, cancelCheck)) {
        return new BingSearchResponse(false, query, [], '请求已取消')
      }

      // 若主域解析失败或结果为空，至少重试一次备用入口
      const needRetry = !primaryResponse.success || primaryResponse.results.length === 0
      if (!needRetry) {
        return primaryResponse
      }

      const fallbackUrl = `https://cn.bing.com/search?q=${encodedQuery}`
      const fallbackResponse = await this.bingSearchByUrl(fallbackUrl, query, resultCount, runtime, controller, cancelCheck)
      if (fallbackResponse.success && fallbackResponse.results.length > 0) {
        return fallbackResponse
      }

      if (!primaryResponse.success && fallbackResponse.success) {
        return fallbackResponse
      }

      return primaryResponse.success ? primaryResponse : fallbackResponse
    } catch (error) {
      return new BingSearchResponse(false, query, [], `Bing 搜索失败: ${JSON.stringify(error)}`)
    }
  }

  private async bingSearchByUrl(
    searchUrl: string,
    query: string,
    resultCount: number,
    runtime: SearchRuntimeConfigSnapshot,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<BingSearchResponse> {
    if (this.isCancelled(controller, cancelCheck)) {
      return new BingSearchResponse(false, query, [], '请求已取消')
    }

    const response = await this.httpService.get(
      searchUrl,
      {},
      this.buildHttpOptions(runtime.timeout, controller)
    )

    if (!response.success) {
      return new BingSearchResponse(false, query, [], response.errorMessage)
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return new BingSearchResponse(false, query, [], '请求已取消')
    }

    const results = this.parseBingSearchResults(response.data, this.normalizeResultCount(resultCount))
    return new BingSearchResponse(true, query, results, '')
  }

  // 解析 Bing 搜索结果页 HTML（多策略，增强鲁棒性）
  private parseBingSearchResults(html: string, maxCount: number): SearchResultItem[] {
    const results: SearchResultItem[] = []
    const seenUrls: Map<string, boolean> = new Map()

    this.collectResultsFromBAlgoBlocks(html, maxCount, results, seenUrls)
    if (results.length < maxCount) {
      this.collectResultsFromHeadingLinks(html, maxCount, results, seenUrls)
    }

    return results
  }

  private collectResultsFromBAlgoBlocks(
    html: string,
    maxCount: number,
    output: SearchResultItem[],
    seenUrls: Map<string, boolean>
  ): void {
    const algoRegex = /<li[^>]*class=["'][^"']*b_algo[^"']*["'][^>]*>([\s\S]*?)<\/li>/gi
    let match = algoRegex.exec(html)

    while (match !== null && output.length < maxCount) {
      const block = match[1]
      const parsed = this.parseResultFromBlock(block)
      if (parsed !== null) {
        const normalizedUrl = parsed.url.trim()
        if (!seenUrls.has(normalizedUrl)) {
          seenUrls.set(normalizedUrl, true)
          output.push(parsed)
        }
      }
      match = algoRegex.exec(html)
    }
  }

  private collectResultsFromHeadingLinks(
    html: string,
    maxCount: number,
    output: SearchResultItem[],
    seenUrls: Map<string, boolean>
  ): void {
    const headingRegex = /<h2[^>]*>[\s\S]*?<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>[\s\S]*?<\/h2>/gi
    let match = headingRegex.exec(html)

    while (match !== null && output.length < maxCount) {
      const url = match[1]
      const title = this.stripHtmlTags(match[2]).trim()

      if (title !== '' && !this.isBingInternalUrl(url)) {
        const normalizedUrl = url.trim()
        if (!seenUrls.has(normalizedUrl)) {
          seenUrls.set(normalizedUrl, true)
          const snippet = this.extractSnippetNearMatch(html, match.index)
          output.push(new SearchResultItem(title, normalizedUrl, snippet))
        }
      }

      match = headingRegex.exec(html)
    }
  }

  private parseResultFromBlock(block: string): SearchResultItem | null {
    const titleMatch = /<h2[^>]*>([\s\S]*?)<\/h2>/i.exec(block)
    if (!titleMatch) {
      return null
    }

    const titleBlock = titleMatch[1]
    const linkMatch = /<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i.exec(titleBlock)
    if (!linkMatch) {
      return null
    }

    const url = linkMatch[1]
    const title = this.stripHtmlTags(linkMatch[2]).trim()
    if (title === '' || this.isBingInternalUrl(url)) {
      return null
    }

    let snippetMatch = /<div[^>]*class=["'][^"']*b_caption[^"']*["'][^>]*>[\s\S]*?<p[^>]*>([\s\S]*?)<\/p>/i.exec(block)
    if (!snippetMatch) {
      snippetMatch = /<p[^>]*>([\s\S]*?)<\/p>/i.exec(block)
    }

    const snippet = snippetMatch ? this.stripHtmlTags(snippetMatch[1]).trim() : ''
    return new SearchResultItem(title, url.trim(), snippet)
  }

  private extractSnippetNearMatch(html: string, startIndex: number): string {
    const safeStart = startIndex >= 0 ? startIndex : 0
    const safeEnd = Math.min(html.length, safeStart + 1000)
    const segment = html.substring(safeStart, safeEnd)
    const snippetMatch = /<p[^>]*>([\s\S]*?)<\/p>/i.exec(segment)
    if (!snippetMatch) {
      return ''
    }
    return this.normalizeSnippet(this.stripHtmlTags(snippetMatch[1]).trim())
  }

  private isBingInternalUrl(url: string): boolean {
    const lower = url.toLowerCase()
    return lower.includes('bing.com') || lower.startsWith('/search') || lower.startsWith('/?')
  }

  // 移除 HTML 标签
  private stripHtmlTags(text: string): string {
    return text
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ')
      .trim()
  }

  // ========== URL 抓取功能 ==========
  // 抓取网页内容
  async fetchUrlContent(url: string, options?: WebSearchExecutionOptions): Promise<WebSearchResult> {
    const runtime = options?.runtimeConfig !== undefined ? options.runtimeConfig : await this.getRuntimeConfigSnapshot()
    const requestId = options?.requestId !== undefined ? options.requestId : ''
    const controller = this.acquireRequestController(requestId)

    try {
      if (runtime.searchEngine === SearchEngine.TAVILY && runtime.tavilyApiKey !== '') {
        const tavilyResult = await this.tavilyExtractUrlContent(url, runtime, controller, options?.cancelCheck)
        if (tavilyResult.success || this.isCancelled(controller, options?.cancelCheck)) {
          return tavilyResult
        }
        console.warn('WebSearchService', `[Tavily Extract] Failed, fallback to local fetch: ${tavilyResult.errorMessage}`)
        const localResult = await this.fetchUrlContentInternal(url, runtime.timeout, controller, options?.cancelCheck)
        if (localResult.success) {
          localResult.sourceName = 'Tavily Extract失败后 URL抓取'
          return localResult
        }
        return new WebSearchResult(
          false,
          this.normalizeContentUrl(url),
          '',
          '',
          `Tavily Extract 失败: ${tavilyResult.errorMessage}; 本地 URL 抓取失败: ${localResult.errorMessage}`,
          undefined,
          'Tavily Extract'
        )
      }

      if (runtime.searchEngine === SearchEngine.EXA && runtime.exaApiKey !== '') {
        const exaResult = await this.exaFetchUrlContent(url, runtime, controller, options?.cancelCheck)
        if (exaResult.success || this.isCancelled(controller, options?.cancelCheck)) {
          return exaResult
        }
        console.warn('WebSearchService', `[Exa Contents] Failed, fallback to local fetch: ${exaResult.errorMessage}`)
        const localResult = await this.fetchUrlContentInternal(url, runtime.timeout, controller, options?.cancelCheck)
        if (localResult.success) {
          localResult.sourceName = 'Exa Contents失败后 URL抓取'
          return localResult
        }
        return new WebSearchResult(
          false,
          this.normalizeContentUrl(url),
          '',
          '',
          `Exa Contents 失败: ${exaResult.errorMessage}; 本地 URL 抓取失败: ${localResult.errorMessage}`,
          undefined,
          'Exa Contents'
        )
      }

      return await this.fetchUrlContentInternal(url, runtime.timeout, controller, options?.cancelCheck)
    } finally {
      this.releaseRequestController(requestId)
    }
  }

  private async fetchUrlContentInternal(
    url: string,
    timeout: number,
    controller: HttpRequestController | null,
    cancelCheck?: () => boolean
  ): Promise<WebSearchResult> {
    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledWebResult(url)
    }

    if (!this.isValidUrl(url)) {
      return new WebSearchResult(false, url, '', '', 'URL 格式无效')
    }

    const fullUrl = this.normalizeContentUrl(url)

    const response = await this.httpService.get(
      fullUrl,
      {},
      this.buildHttpOptions(timeout, controller)
    )

    if (!response.success) {
      if (this.isCancelled(controller, cancelCheck)) {
        return this.buildCancelledWebResult(fullUrl)
      }
      return new WebSearchResult(false, fullUrl, '', '', response.errorMessage)
    }

    if (this.isCancelled(controller, cancelCheck)) {
      return this.buildCancelledWebResult(fullUrl)
    }

    const parsed = this.parseHtmlContent(response.data)
    if (parsed.content.trim() === '') {
      return new WebSearchResult(false, fullUrl, parsed.title, '', '本地 URL 抓取未提取到网页正文', undefined, 'URL抓取')
    }
    return new WebSearchResult(true, fullUrl, parsed.title, parsed.content, '', undefined, 'URL抓取')
  }

  private normalizeContentUrl(url: string): string {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://' + url
    }
    return url
  }

  // 解析 HTML 提取正文
  private parseHtmlContent(html: string): HtmlParseResult {
    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i)
    const title = titleMatch ? titleMatch[1].trim() : '未知标题'

    const cleanHtml = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '')
      .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '')
      .replace(/<header[^>]*>[\s\S]*?<\/header>/gi, '')
      .replace(/<br\s*\/?>/gi, '\n')

    const contentMatches = cleanHtml.match(/<(p|h[1-6]|li|td|th|span)[^>]*>([\s\S]*?)<\/\1>/gi)

    let content = ''
    if (contentMatches) {
      content = contentMatches
        .map((match: string): string => match
          .replace(/<[^>]+>/g, '')
          .replace(/&nbsp;/g, ' ')
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'")
          .replace(/\n+/g, '\n')
          .trim())
        .filter((text: string): boolean => {
          if (text.length > 10) {
            return true
          }
          if (/(℃|°|AQI|PM2\.5|\d+\s*-\s*\d+)/i.test(text)) {
            return true
          }
          return false
        })
        .join('\n')
    }

    const maxContentLength = 8000
    if (content.length > maxContentLength) {
      content = content.substring(0, maxContentLength) + '...'
    }

    return new HtmlParseResult(title, content)
  }

  // 验证 URL 格式
  isValidUrl(text: string): boolean {
    const urlPattern = /^https?:\/\/[\w\-.]+(:\d+)?(\/[\w\-._~:/?#[\]@!$&'()*+,;=]*)?$|^[\w\-.]+(:\d+)?(\/[\w\-._~:/?#[\]@!$&'()*+,;=]*)?$/
    return urlPattern.test(text.trim())
  }

  // 从文本中提取 URL
  extractUrl(text: string): string | null {
    const trimmed = text.trim()

    const httpPattern = /^https?:\/\/[^\s]+/
    const httpMatch = trimmed.match(httpPattern)
    if (httpMatch) {
      return httpMatch[0]
    }

    const domainPattern = /^[\w\-]+\.[\w\-]+(:\d+)?(\/[\w\-._~:/?#[\]@!$&'()*+,;=]*)?/
    const domainMatch = trimmed.match(domainPattern)
    if (domainMatch) {
      return domainMatch[0]
    }

    return null
  }
}

export function getWebSearchService(): WebSearchService {
  return WebSearchService.getInstance()
}
