import {
  ToolApprovalPolicy,
  ToolConfig,
  ToolPermissionLevel,
  ToolSourceType,
  normalizeToolApprovalPolicy
} from '../../models/ChatModels'
import { getAppUiState } from '../../state/AppUiState'
import { pickLocalizedText } from '../../utils/LocalizedTextUtils'
import { withColorAlpha } from '../../utils/ColorAlphaUtils'

class McpToolGroup {
  sourceId: string = ''
  displayName: string = ''
  toolIds: string[] = []
  hasWriteTool: boolean = false
  approvalPolicy: string = ToolApprovalPolicy.UNCONFIGURED

  constructor(sourceId: string, displayName: string) {
    this.sourceId = sourceId
    this.displayName = displayName
  }
}

@ComponentV2
export struct ChatToolPickerSheetContent {
  @Param availableChatTools: ToolConfig[] = []
  @Param selectedToolIds: string[] = []
  @Param isRefreshingMcpToolAvailability: boolean = false
  @Param themePrimary: ResourceColor = ''
  @Param isDarkMode: boolean = false
  @Event onClose: () => void = (): void => {}
  @Event onRefresh: () => void = (): void => {}
  @Event onToggleTool: (toolId: string, enabled: boolean) => void =
    (_toolId: string, _enabled: boolean): void => {}
  @Event onToggleMcpGroup: (toolIds: string[], enabled: boolean) => void =
    (_toolIds: string[], _enabled: boolean): void => {}

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private get themePrimarySubtleBackground(): string {
    return withColorAlpha(getAppUiState().themePrimary, this.isDarkMode ? '28' : '16')
  }

  private get neutralBadgeBackgroundColor(): string {
    return withColorAlpha(getAppUiState().themeTextSecondary, this.isDarkMode ? '24' : '12')
  }

  private get writeBadgeColor(): string {
    return '#D9485F'
  }

  private get writeBadgeBackgroundColor(): string {
    return withColorAlpha(this.writeBadgeColor, this.isDarkMode ? '28' : '12')
  }

  private isMcpChatTool(tool: ToolConfig): boolean {
    return tool.sourceType === ToolSourceType.MCP && tool.sourceId.trim() !== ''
  }

  private isToolSelected(toolId: string): boolean {
    return this.selectedToolIds.includes(toolId)
  }

  private getBuiltinChatTools(): ToolConfig[] {
    const builtinTools: ToolConfig[] = []
    for (let i = 0; i < this.availableChatTools.length; i++) {
      const tool = this.availableChatTools[i]
      if (!this.isMcpChatTool(tool)) {
        builtinTools.push(tool)
      }
    }
    return builtinTools
  }

  private getMcpToolGroups(): McpToolGroup[] {
    const groups: McpToolGroup[] = []
    const groupIndexes: Map<string, number> = new Map()
    for (let i = 0; i < this.availableChatTools.length; i++) {
      const tool = this.availableChatTools[i]
      if (!this.isMcpChatTool(tool)) {
        continue
      }
      const existingIndex = groupIndexes.get(tool.sourceId)
      if (existingIndex === undefined) {
        const displayName = tool.sourceLabel.trim() !== '' ? tool.sourceLabel : tool.sourceId
        const group = new McpToolGroup(tool.sourceId, displayName)
        group.toolIds.push(tool.id)
        group.hasWriteTool = tool.permissionLevel === ToolPermissionLevel.WRITE
        group.approvalPolicy = normalizeToolApprovalPolicy(tool.approvalPolicy)
        groups.push(group)
        groupIndexes.set(tool.sourceId, groups.length - 1)
        continue
      }
      groups[existingIndex].toolIds.push(tool.id)
      if (tool.permissionLevel === ToolPermissionLevel.WRITE) {
        groups[existingIndex].hasWriteTool = true
      }
      const normalizedPolicy = normalizeToolApprovalPolicy(tool.approvalPolicy)
      if (normalizedPolicy !== ToolApprovalPolicy.UNCONFIGURED) {
        groups[existingIndex].approvalPolicy = normalizedPolicy
      }
    }
    return groups
  }

  private isMcpToolGroupSelected(group: McpToolGroup): boolean {
    if (group.toolIds.length === 0) {
      return false
    }
    for (let i = 0; i < group.toolIds.length; i++) {
      if (!this.selectedToolIds.includes(group.toolIds[i])) {
        return false
      }
    }
    return true
  }

  private getCardBackground(selected: boolean): ResourceColor {
    return selected ? this.themePrimarySubtleBackground : this.themeSurface
  }

  private getCardBorderColor(selected: boolean): ResourceColor {
    return selected ? this.themePrimary : $r('app.color.divider')
  }

  private getCardShadowColor(selected: boolean): string {
    return selected ? 'rgba(0, 125, 255, 0.16)' : 'rgba(15, 23, 42, 0.06)'
  }

  private getBuiltinDescription(tool: ToolConfig): string {
    const description = tool.description.trim()
    return description !== '' ? description : pickLocalizedText(
      '应用内原生能力，可在当前聊天中按需调用。',
      'Built-in app capability that can be exposed to the model in this chat.'
    )
  }

  private getMcpToolGroupPolicyLabel(group: McpToolGroup): string {
    const normalized = normalizeToolApprovalPolicy(group.approvalPolicy)
    if (normalized === ToolApprovalPolicy.ALWAYS_ALLOW) {
      return pickLocalizedText('始终允许', 'Always allow')
    }
    return ''
  }

  private getMcpToolGroupPolicyColor(group: McpToolGroup): string {
    const normalized = normalizeToolApprovalPolicy(group.approvalPolicy)
    if (normalized === ToolApprovalPolicy.ALWAYS_ALLOW) {
      return getAppUiState().themePrimary
    }
    return getAppUiState().themeTextSecondary
  }

  private getMcpToolGroupPolicyBackground(group: McpToolGroup): string {
    const normalized = normalizeToolApprovalPolicy(group.approvalPolicy)
    if (normalized === ToolApprovalPolicy.ALWAYS_ALLOW) {
      return this.themePrimarySubtleBackground
    }
    return this.neutralBadgeBackgroundColor
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.divider'))
        .onClick(() => {
          this.onClose()
        })

        Text(pickLocalizedText('选择工具', 'Choose Tools'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(18)
            .fontColor([Color.White])
        }
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .backgroundColor(this.themePrimary)
        .onClick(() => {
          this.onRefresh()
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 18 }) {
          if (this.availableChatTools.length === 0) {
            Column({ space: 8 }) {
              Column() {
                SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
                  .fontSize(22)
                  .fontColor([this.themePrimary])
              }
              .width(48)
              .height(48)
              .borderRadius(14)
              .backgroundColor(this.themePrimarySubtleBackground)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)

              Text(pickLocalizedText('暂无可用工具', 'No tools available'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text(this.isRefreshingMcpToolAvailability
                ? pickLocalizedText('正在后台刷新工具，请稍候再试。', 'Refreshing tools in the background. Try again shortly.')
                : pickLocalizedText(
                  '先到工具服务添加并启用 MCP Server，再回这里选择。',
                  'Add and enable an MCP server in Tool Services first, then come back here.'
                ))
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 28, bottom: 28 })
            .borderRadius(20)
            .backgroundColor(this.themeSurface)
            .border({
              width: 0.5,
              color: $r('app.color.divider')
            })
            .shadow({ radius: 12, color: 'rgba(15, 23, 42, 0.06)', offsetX: 0, offsetY: 4 })
            .alignItems(HorizontalAlign.Center)
          } else {
            if (this.getBuiltinChatTools().length > 0) {
              Column({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(pickLocalizedText('内置工具', 'Built-in Tools'))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))

                  Text(pickLocalizedText(
                    '单个能力单独开关，启用后才会暴露给模型。',
                    'Each capability is toggled separately and only exposed to the model after enabling.'
                  ))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                ForEach(this.getBuiltinChatTools(), (tool: ToolConfig) => {
                  Row({ space: 10 }) {
                    Column({ space: 2 }) {
                      Row({ space: 6 }) {
                        Text(tool.name)
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)

                        if (tool.permissionLevel === ToolPermissionLevel.WRITE) {
                          Text(pickLocalizedText('写', 'W'))
                            .fontSize(9)
                            .fontColor(this.writeBadgeColor)
                            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                            .borderRadius(4)
                            .backgroundColor(this.writeBadgeBackgroundColor)
                        }
                      }
                      .width('100%')

                      Text(this.getBuiltinDescription(tool))
                        .fontSize(11)
                        .fontColor($r('app.color.text_tertiary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Toggle({ type: ToggleType.Switch, isOn: this.isToolSelected(tool.id) })
                      .selectedColor(this.themePrimary)
                      .onChange((value: boolean) => {
                        this.onToggleTool(tool.id, value)
                      })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .borderRadius(12)
                  .backgroundColor(this.themeSurface)
                }, (tool: ToolConfig) => tool.id)
              }
              .width('100%')
            }

            if (this.getMcpToolGroups().length > 0) {
              Column({ space: 12 }) {
                Text(pickLocalizedText('MCP 服务', 'MCP Services'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                ForEach(this.getMcpToolGroups(), (group: McpToolGroup) => {
                  Row({ space: 10 }) {
                    Column({ space: 2 }) {
                      Row({ space: 6 }) {
                        Text(group.displayName)
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)

                        Text(`${group.toolIds.length}`)
                          .fontSize(10)
                          .fontColor($r('app.color.text_tertiary'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                          .backgroundColor(this.isDarkMode ? '#2A2D35' : '#F3F4F6')

                        if (this.getMcpToolGroupPolicyLabel(group) !== '') {
                          Text(this.getMcpToolGroupPolicyLabel(group))
                            .fontSize(9)
                            .fontColor(this.getMcpToolGroupPolicyColor(group))
                            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                            .borderRadius(4)
                            .backgroundColor(this.getMcpToolGroupPolicyBackground(group))
                        }
                      }
                      .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Toggle({ type: ToggleType.Switch, isOn: this.isMcpToolGroupSelected(group) })
                      .selectedColor(this.themePrimary)
                      .onChange((value: boolean) => {
                        this.onToggleMcpGroup(group.toolIds, value)
                      })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .borderRadius(12)
                  .backgroundColor(this.themeSurface)
                }, (group: McpToolGroup) => group.sourceId)
              }
              .width('100%')
            }
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .constraintSize({ maxHeight: 520 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .backgroundColor(this.themeBackground)
  }
}
