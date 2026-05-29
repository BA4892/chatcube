import { ToolApprovalPolicy, ToolPermissionLevel, normalizeToolApprovalPolicy } from './ChatModels'

export const MCP_DEFAULT_CALL_TIMEOUT_MS: number = 30000
export const MCP_MIN_CALL_TIMEOUT_MS: number = 5000
export const MCP_MAX_CALL_TIMEOUT_MS: number = 1800000

export function normalizeMcpCallTimeoutMs(value: number): number {
  if (isNaN(value) || value <= 0) {
    return MCP_DEFAULT_CALL_TIMEOUT_MS
  }
  const rounded = Math.round(value)
  if (rounded < MCP_MIN_CALL_TIMEOUT_MS) {
    return MCP_MIN_CALL_TIMEOUT_MS
  }
  if (rounded > MCP_MAX_CALL_TIMEOUT_MS) {
    return MCP_MAX_CALL_TIMEOUT_MS
  }
  return rounded
}

export enum McpAuthType {
  NONE = 'none',
  BEARER = 'bearer'
}

@ObservedV2
export class McpToolEntry {
  @Trace name: string = ''
  @Trace description: string = ''
  @Trace enabled: boolean = true
  @Trace toolApprovalPolicy: string = ToolApprovalPolicy.UNCONFIGURED
  @Trace inputSchemaJson: string = ''
  @Trace permissionLevel: string = ToolPermissionLevel.READ

  constructor(
    name: string = '',
    description: string = '',
    enabled: boolean = true,
    toolApprovalPolicy: string = ToolApprovalPolicy.UNCONFIGURED,
    inputSchemaJson: string = '',
    permissionLevel: string = ToolPermissionLevel.READ
  ) {
    this.name = name
    this.description = description
    this.enabled = enabled
    this.toolApprovalPolicy = normalizeToolApprovalPolicy(toolApprovalPolicy)
    this.inputSchemaJson = inputSchemaJson
    this.permissionLevel = permissionLevel
  }
}

@ObservedV2
export class McpServerConfig {
  @Trace id: string = ''
  @Trace name: string = ''
  @Trace baseUrl: string = ''
  @Trace enabled: boolean = true
  @Trace authType: string = McpAuthType.NONE
  @Trace authToken: string = ''
  @Trace customHeadersJson: string = ''
  @Trace toolApprovalPolicy: string = ToolApprovalPolicy.UNCONFIGURED
  @Trace tools: McpToolEntry[] = []
  @Trace callTimeoutMs: number = MCP_DEFAULT_CALL_TIMEOUT_MS

  constructor(
    id: string = '',
    name: string = '',
    baseUrl: string = '',
    enabled: boolean = true,
    authType: string = McpAuthType.NONE,
    authToken: string = '',
    customHeadersJson: string = '',
    toolApprovalPolicy: string = ToolApprovalPolicy.UNCONFIGURED,
    tools: McpToolEntry[] = [],
    callTimeoutMs: number = MCP_DEFAULT_CALL_TIMEOUT_MS
  ) {
    this.id = id
    this.name = name
    this.baseUrl = baseUrl
    this.enabled = enabled
    this.authType = authType
    this.authToken = authToken
    this.customHeadersJson = customHeadersJson
    this.toolApprovalPolicy = normalizeToolApprovalPolicy(toolApprovalPolicy)
    this.tools = tools
    this.callTimeoutMs = normalizeMcpCallTimeoutMs(callTimeoutMs)
  }
}

export interface McpToolAnnotations {
  readOnlyHint?: boolean
  destructiveHint?: boolean
  title?: string
}

export interface McpToolDescriptor {
  name: string
  title?: string
  description?: string
  inputSchema?: object
  annotations?: McpToolAnnotations
}

export interface McpToolCallResponse {
  content?: Array<Record<string, Object>>
  structuredContent?: object
  isError?: boolean
}

export class McpDiscoveredTool {
  toolId: string = ''
  functionName: string = ''
  remoteName: string = ''
  displayName: string = ''
  description: string = ''
  inputSchema: object = JSON.parse('{}') as object
  permissionLevel: string = ToolPermissionLevel.READ

  constructor(
    toolId: string,
    functionName: string,
    remoteName: string,
    displayName: string,
    description: string,
    inputSchema: object,
    permissionLevel: string
  ) {
    this.toolId = toolId
    this.functionName = functionName
    this.remoteName = remoteName
    this.displayName = displayName
    this.description = description
    this.inputSchema = inputSchema
    this.permissionLevel = permissionLevel
  }
}
