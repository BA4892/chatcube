import { ToolCall, ToolResult, ToolSourceType, ToolPermissionLevel } from '../models/ChatModels'
import { getToolRegistry, RegisteredTool, ToolRegistry } from './ToolRegistry'
import {
  ASK_USER_TOOL_ID,
  LEGACY_WEB_SEARCH_TOOL_ID,
  SCRAPE_WEB_TOOL_ID,
  SEARCH_WEB_TOOL_ID,
  isAskUserFunctionName,
  isScrapeWebFunctionName,
  isSearchWebFunctionName
} from '../utils/SearchToolIdentityUtils'

// 取消检查回调类型
type CancelCheckCallback = () => boolean
type ToolApprovalCallback = (toolCall: ToolCall, tool: RegisteredTool) => Promise<boolean>
// ask_user 答复回调: UI 层(ChatPage)等用户在 AskUserCard 里填完并提交后 resolve(answerJson),
// 用户放弃/页面销毁时 resolve(null) 代表取消。
type ToolAnswerCallback = (toolCall: ToolCall) => Promise<string | null>

// 工具执行服务 - 负责执行工具调用
export class ToolExecutionService {
  private static instance: ToolExecutionService | null = null
  private registry: ToolRegistry
  // 当前取消检查回调
  private cancelCheckCallback: CancelCheckCallback | null = null
  private approvalCallback: ToolApprovalCallback | null = null
  private answerCallback: ToolAnswerCallback | null = null

  private constructor() {
    this.registry = getToolRegistry()
  }

  static getInstance(): ToolExecutionService {
    if (ToolExecutionService.instance === null) {
      ToolExecutionService.instance = new ToolExecutionService()
    }
    return ToolExecutionService.instance
  }

  // 设置取消检查回调
  setCancelCheckCallback(callback: CancelCheckCallback | null): void {
    this.cancelCheckCallback = callback
  }

  // 清除取消检查回调
  clearCancelCheckCallback(): void {
    this.cancelCheckCallback = null
  }

  setApprovalCallback(callback: ToolApprovalCallback | null): void {
    this.approvalCallback = callback
  }

  // ask_user 专用答复回调: UI 层 (ChatPage) 在这里管理 pending toolCall 的 resolver,
  // 用户点击 AskUserCard 的 "提交" 后把 answer JSON 喂回来。
  setAnswerCallback(callback: ToolAnswerCallback | null): void {
    this.answerCallback = callback
  }

  // 检查是否已取消
  private isCancelled(): boolean {
    if (this.cancelCheckCallback !== null) {
      return this.cancelCheckCallback()
    }
    return false
  }

  private normalizeFunctionName(functionName: string): string {
    const rawName = functionName as string | null | undefined
    if (rawName === undefined || rawName === null) {
      return ''
    }
    return rawName.trim()
  }

  private resolveToolId(functionName: string): string | undefined {
    if (functionName !== '') {
      const direct = this.registry.getToolIdByFunctionName(functionName)
      if (direct !== undefined) {
        return direct
      }
    }

    if (isScrapeWebFunctionName(functionName) && this.registry.isToolRegistered(SCRAPE_WEB_TOOL_ID)) {
      return SCRAPE_WEB_TOOL_ID
    }

    if (isSearchWebFunctionName(functionName)) {
      if (this.registry.isToolRegistered(SEARCH_WEB_TOOL_ID)) {
        return SEARCH_WEB_TOOL_ID
      }
      if (this.registry.isToolRegistered(LEGACY_WEB_SEARCH_TOOL_ID)) {
        return LEGACY_WEB_SEARCH_TOOL_ID
      }
    }
    return undefined
  }

  private buildCancelledResult(toolCall: ToolCall, displayName: string, sourceLabel: string): ToolResult {
    return new ToolResult(
      toolCall.id,
      JSON.stringify({ error: '工具执行已取消', cancelled: true }),
      true,
      displayName,
      sourceLabel
    )
  }

  private async requestApprovalIfNeeded(toolCall: ToolCall, tool: RegisteredTool): Promise<boolean> {
    if (tool.config.permissionLevel !== 'write') {
      toolCall.approvalState = 'auto'
      return true
    }
    if (this.approvalCallback === null) {
      toolCall.approvalState = 'denied'
      return false
    }
    toolCall.approvalState = 'pending'
    try {
      const approved = await this.approvalCallback(toolCall, tool)
      toolCall.approvalState = approved ? 'approved' : 'denied'
      return approved
    } catch (error) {
      console.error('ToolExecutionService', `Approval callback failed: ${JSON.stringify(error)}`)
      toolCall.approvalState = 'denied'
      return false
    }
  }

  // ask_user 特殊路径: 不走通用 executor, 挂起等待 UI 层 (AskUserCard) 的回答,
  // 拿到 answerJson 后直接作为 ToolResult 返回; 用户取消/页面销毁则按 denied 处理。
  private async handleAskUser(toolCall: ToolCall): Promise<ToolResult> {
    // 用 ASK_USER_TOOL_ID 回填, 保证工具卡片/消息事件按统一 id 识别
    toolCall.toolId = ASK_USER_TOOL_ID
    if (toolCall.displayName.trim() === '') {
      toolCall.displayName = '向用户提问'
    }
    toolCall.sourceType = ToolSourceType.BUILTIN
    if (toolCall.sourceLabel.trim() === '') {
      toolCall.sourceLabel = '内置工具'
    }
    toolCall.permissionLevel = ToolPermissionLevel.READ

    if (this.answerCallback === null) {
      console.error('ToolExecutionService', 'ask_user answer callback not registered')
      toolCall.approvalState = 'denied'
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: 'ask_user 未启用: 当前界面不支持人机交互工具' }),
        true,
        toolCall.displayName,
        toolCall.sourceLabel
      )
    }

    // 标记为 pending, UI (AskUserCard) 据此判断是否可交互
    toolCall.approvalState = 'pending'

    let answerJson: string | null = null
    try {
      answerJson = await this.answerCallback(toolCall)
    } catch (error) {
      console.error('ToolExecutionService', `ask_user answer callback failed: ${JSON.stringify(error)}`)
      toolCall.approvalState = 'denied'
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: `ask_user 失败: ${JSON.stringify(error)}`, cancelled: true }),
        true,
        toolCall.displayName,
        toolCall.sourceLabel
      )
    }

    // 执行期间被取消 (例如用户在 AskUserCard 外按了停止)
    if (this.isCancelled()) {
      console.info('ToolExecutionService', 'ask_user cancelled by external stop')
      toolCall.approvalState = 'denied'
      return this.buildCancelledResult(toolCall, toolCall.displayName, toolCall.sourceLabel)
    }

    if (answerJson === null) {
      toolCall.approvalState = 'denied'
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ cancelled: true, error: '用户未回答该问题' }),
        true,
        toolCall.displayName,
        toolCall.sourceLabel
      )
    }

    // 标记为已回答, 答案 JSON 既写入 approvalReason (UI 显示)也作为 tool_result 回传给模型
    toolCall.approvalState = 'answered'
    toolCall.approvalReason = answerJson
    console.info('ToolExecutionService', `ask_user answered: ${toolCall.id}`)
    return new ToolResult(
      toolCall.id,
      answerJson,
      false,
      toolCall.displayName,
      toolCall.sourceLabel
    )
  }

  // 执行单个工具调用
  async executeToolCall(toolCall: ToolCall): Promise<ToolResult> {
    console.info('ToolExecutionService', `Executing tool call: ${toolCall.functionName} (${toolCall.id})`)

    // 检查是否已取消
    if (this.isCancelled()) {
      console.info('ToolExecutionService', `Tool execution cancelled: ${toolCall.functionName}`)
      return this.buildCancelledResult(toolCall, toolCall.displayName, toolCall.sourceLabel)
    }

    const normalizedFunctionName = this.normalizeFunctionName(toolCall.functionName)

    // === ask_user 特殊路径 ===
    // 人机交互工具, 不走通用 executor 和 write 审批 sheet, 由 AskUserCard 直接收集答案。
    if (isAskUserFunctionName(normalizedFunctionName)) {
      return await this.handleAskUser(toolCall)
    }

    // 通过函数名获取工具 ID
    const toolId = this.resolveToolId(normalizedFunctionName)
    if (toolId === undefined) {
      const displayName = normalizedFunctionName !== '' ? normalizedFunctionName : 'null'
      console.error('ToolExecutionService', `Tool not found: ${displayName}`)
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: `未知工具: ${displayName}` }),
        true,
        displayName,
        toolCall.sourceLabel
      )
    }

    const registeredTool = this.registry.getTool(toolId)
    if (registeredTool === undefined) {
      console.error('ToolExecutionService', `Registered tool not found: ${toolId}`)
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: `工具未注册: ${toolId}` }),
        true,
        toolCall.displayName,
        toolCall.sourceLabel
      )
    }

    toolCall.toolId = registeredTool.id
    toolCall.displayName = registeredTool.config.name
    toolCall.sourceType = registeredTool.config.sourceType
    toolCall.sourceLabel = registeredTool.config.sourceLabel
    toolCall.permissionLevel = registeredTool.config.permissionLevel

    const approved = await this.requestApprovalIfNeeded(toolCall, registeredTool)
    if (!approved) {
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: '用户拒绝了工具调用', cancelled: true }),
        true,
        registeredTool.config.name,
        registeredTool.config.sourceLabel
      )
    }

    // 获取工具执行器
    const executor = this.registry.getToolExecutor(toolId)
    if (executor === undefined) {
      console.error('ToolExecutionService', `Executor not found for tool: ${toolId}`)
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: `工具执行器未找到: ${toolId}` }),
        true,
        registeredTool.config.name,
        registeredTool.config.sourceLabel
      )
    }

    try {
      // 执行工具
      const startTime = Date.now()
      const result = await executor.execute(toolCall.arguments)

      // 执行完成后再次检查是否取消（避免返回已取消的结果）
      if (this.isCancelled()) {
        console.info('ToolExecutionService', `Tool execution cancelled after completion: ${toolCall.functionName}`)
        return this.buildCancelledResult(toolCall, registeredTool.config.name, registeredTool.config.sourceLabel)
      }

      const duration = Date.now() - startTime
      console.info('ToolExecutionService', `Tool ${toolCall.functionName} completed in ${duration}ms`)

      let isError = false
      try {
        const parsed = JSON.parse(result) as Record<string, Object>
        isError = parsed.isError === true || parsed.error !== undefined
      } catch (_error) {}

      return new ToolResult(
        toolCall.id,
        result,
        isError,
        registeredTool.config.name,
        registeredTool.config.sourceLabel
      )
    } catch (error) {
      console.error('ToolExecutionService', `Tool execution error: ${JSON.stringify(error)}`)
      return new ToolResult(
        toolCall.id,
        JSON.stringify({ error: `工具执行失败: ${JSON.stringify(error)}` }),
        true,
        registeredTool.config.name,
        registeredTool.config.sourceLabel
      )
    }
  }

  // 批量执行工具调用（串行，避免多个确认框并发弹出）
  async executeToolCalls(toolCalls: ToolCall[]): Promise<ToolResult[]> {
    console.info('ToolExecutionService', `Executing ${toolCalls.length} tool calls`)

    // 检查是否已取消
    if (this.isCancelled()) {
      console.info('ToolExecutionService', 'Tool execution cancelled before batch execution')
      return toolCalls.map(tc => new ToolResult(
        tc.id,
        JSON.stringify({ error: '工具执行已取消', cancelled: true }),
        true,
        tc.displayName,
        tc.sourceLabel
      ))
    }

    const results: ToolResult[] = []
    for (let i = 0; i < toolCalls.length; i++) {
      results.push(await this.executeToolCall(toolCalls[i]))
    }
    return results
  }

  // 检查工具是否可用
  isToolAvailable(functionName: string): boolean {
    const normalizedFunctionName = this.normalizeFunctionName(functionName)
    const toolId = this.resolveToolId(normalizedFunctionName)
    return toolId !== undefined
  }
}

// 导出单例实例获取方法
export function getToolExecutionService(): ToolExecutionService {
  return ToolExecutionService.getInstance()
}
