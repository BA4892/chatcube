import { ToolCall, ToolResult } from '../models/ChatModels'
import { getToolRegistry, RegisteredTool, ToolRegistry } from './ToolRegistry'
import {
  LEGACY_WEB_SEARCH_TOOL_ID,
  SCRAPE_WEB_TOOL_ID,
  SEARCH_WEB_TOOL_ID,
  isScrapeWebFunctionName,
  isSearchWebFunctionName
} from '../utils/SearchToolIdentityUtils'

// 取消检查回调类型
type CancelCheckCallback = () => boolean
type ToolApprovalCallback = (toolCall: ToolCall, tool: RegisteredTool) => Promise<boolean>

// 工具执行服务 - 负责执行工具调用
export class ToolExecutionService {
  private static instance: ToolExecutionService | null = null
  private registry: ToolRegistry
  // 当前取消检查回调
  private cancelCheckCallback: CancelCheckCallback | null = null
  private approvalCallback: ToolApprovalCallback | null = null

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
      return true
    }
    if (this.approvalCallback === null) {
      return false
    }
    try {
      return await this.approvalCallback(toolCall, tool)
    } catch (error) {
      console.error('ToolExecutionService', `Approval callback failed: ${JSON.stringify(error)}`)
      return false
    }
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
