import {
  ToolCall,
  ToolDefinition,
  ToolPermissionLevel,
  ToolResult,
  ToolSourceType
} from '../../models/ChatModels'

export const MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE: number = 3

export class ToolCallBudgetDecision {
  executableToolCalls: ToolCall[] = []
  blockedToolCalls: ToolCall[] = []
  webSearchCallCount: number = 0
  searchLimitReached: boolean = false

  constructor(
    executableToolCalls: ToolCall[],
    blockedToolCalls: ToolCall[],
    webSearchCallCount: number,
    searchLimitReached: boolean
  ) {
    this.executableToolCalls = executableToolCalls
    this.blockedToolCalls = blockedToolCalls
    this.webSearchCallCount = webSearchCallCount
    this.searchLimitReached = searchLimitReached
  }
}

export function isWebSearchFunctionName(functionName: string): boolean {
  const raw = functionName as string | null | undefined
  if (raw === undefined || raw === null) {
    return false
  }
  const normalized = raw.trim().toLowerCase().replace(/[\s\-]+/g, '_')
  return normalized === 'web_search' ||
    normalized === 'exa_search' ||
    normalized === 'websearch' ||
    normalized === 'search_web' ||
    normalized === 'internet_search' ||
    normalized === 'web_search_exa'
}

export function filterToolsForWebSearchBudget(
  tools: ToolDefinition[],
  webSearchCallCount: number
): ToolDefinition[] {
  if (webSearchCallCount < MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE) {
    return tools
  }

  const filtered: ToolDefinition[] = []
  for (let i = 0; i < tools.length; i++) {
    if (!isWebSearchFunctionName(tools[i].function.name)) {
      filtered.push(tools[i])
    }
  }
  return filtered
}

export function applyToolCallBudget(
  toolCalls: ToolCall[],
  currentWebSearchCallCount: number
): ToolCallBudgetDecision {
  const executableToolCalls: ToolCall[] = []
  const blockedToolCalls: ToolCall[] = []
  let nextWebSearchCallCount = currentWebSearchCallCount > 0 ? currentWebSearchCallCount : 0
  let searchLimitReached = nextWebSearchCallCount >= MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE

  for (let i = 0; i < toolCalls.length; i++) {
    const toolCall = toolCalls[i]
    if (!isWebSearchFunctionName(toolCall.functionName)) {
      executableToolCalls.push(toolCall)
      continue
    }

    normalizeBlockedWebSearchToolCall(toolCall)
    if (nextWebSearchCallCount < MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE) {
      executableToolCalls.push(toolCall)
      nextWebSearchCallCount++
      if (nextWebSearchCallCount >= MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE) {
        searchLimitReached = true
      }
    } else {
      blockedToolCalls.push(toolCall)
      searchLimitReached = true
    }
  }

  return new ToolCallBudgetDecision(
    executableToolCalls,
    blockedToolCalls,
    nextWebSearchCallCount,
    searchLimitReached
  )
}

export function createWebSearchLimitToolResult(toolCall: ToolCall): ToolResult {
  normalizeBlockedWebSearchToolCall(toolCall)
  return new ToolResult(
    toolCall.id,
    JSON.stringify({
      error: `web_search 调用次数已达到上限（最多 ${MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE} 次）`,
      searchLimitReached: true,
      maxWebSearchCalls: MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE,
      instruction: '请基于已有搜索结果直接回答，不要继续调用 web_search，也不要输出任何工具调用、DSML、XML、JSON 格式。'
    }),
    true,
    toolCall.displayName,
    toolCall.sourceLabel
  )
}

export function buildWebSearchLimitFinalAnswerInstruction(): string {
  return `web_search 调用次数已达到本轮上限（最多 ${MAX_WEB_SEARCH_CALLS_PER_USER_MESSAGE} 次）。` +
    '现在必须基于已有搜索结果直接回答用户；不要继续调用 web_search，也不要输出任何 DSML、XML、JSON 或 function call 文本。'
}

export function stripLeakedToolInvocationText(content: string): string {
  if (content.trim() === '') {
    return content
  }

  const lines = content.split('\n')
  let cutoff = lines.length
  for (let i = 0; i < lines.length; i++) {
    if (looksLikeRawToolInvocationLine(lines[i])) {
      cutoff = i
      break
    }
  }
  if (cutoff === lines.length) {
    return content
  }
  return lines.slice(0, cutoff).join('\n').trim()
}

function normalizeBlockedWebSearchToolCall(toolCall: ToolCall): void {
  toolCall.functionName = 'web_search'
  toolCall.toolId = 'web_search'
  if (toolCall.displayName === '') {
    toolCall.displayName = '联网搜索'
  }
  if (toolCall.sourceType === '') {
    toolCall.sourceType = ToolSourceType.BUILTIN
  }
  if (toolCall.sourceLabel === '') {
    toolCall.sourceLabel = '内置工具'
  }
  if (toolCall.permissionLevel === '') {
    toolCall.permissionLevel = ToolPermissionLevel.READ
  }
}

function looksLikeRawToolInvocationLine(line: string): boolean {
  const compact = line.toLowerCase().replace(/[\s`]+/g, '')
  if (compact === '') {
    return false
  }
  if (compact.includes('dsml') &&
    (compact.includes('toolcall') || compact.includes('toolcalls') ||
      compact.includes('invoke') || compact.includes('parameter'))) {
    return true
  }
  if (compact.startsWith('<toolcall') ||
    compact.startsWith('</toolcall') ||
    compact.startsWith('<toolcalls') ||
    compact.startsWith('</toolcalls')) {
    return true
  }
  if (compact.includes('invoke') &&
    (compact.includes('websearch') || compact.includes('web_search'))) {
    return true
  }
  return false
}
