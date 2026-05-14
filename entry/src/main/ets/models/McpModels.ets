import { ToolApprovalPolicy, ToolPermissionLevel, normalizeToolApprovalPolicy } from './ChatModels'

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

  constructor(
    id: string = '',
    name: string = '',
    baseUrl: string = '',
    enabled: boolean = true,
    authType: string = McpAuthType.NONE,
    authToken: string = '',
    customHeadersJson: string = '',
    toolApprovalPolicy: string = ToolApprovalPolicy.UNCONFIGURED,
    tools: McpToolEntry[] = []
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
