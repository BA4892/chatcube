/**
 * 分享消息卡片组件
 * 用于渲染分享图片的卡片样式
 */
import { ChatMessage, MessageRole, MessageAttachment, AttachmentType } from '../models/ChatModels'
import { getAppUiState } from '../state/AppUiState'
import {
  ASSISTANT_BUBBLE_BORDER_WIDTH,
  ASSISTANT_BUBBLE_RADIUS,
  USER_BUBBLE_BORDER_WIDTH,
  USER_BUBBLE_MAX_WIDTH,
  getAssistantBubblePadding,
  getUserBubblePadding,
  getUserBubbleRadius,
  getUserBubbleTextLineHeight
} from '../utils/MessageBubbleStyleUtils'
import { AssistantAvatarView } from './AssistantAvatar'
import { ChatMarkdownHybridRenderer } from './ChatMarkdownHybridRenderer'

@ComponentV2
export struct ShareMessageCard {
  @Param messages: ChatMessage[] = []
  @Param appName: string = 'Cube Chat'
  @Param currentModelId: string = ''
  @Param iconRenderVersion: number = 0
  @Param assistantAvatarValue: string = 'AI'
  @Param assistantAvatarColor: string = '#4E6F9E'
  @Param assistantAvatarCacheKey: number = 0
  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }
  private get themeUserBubble(): string {
    return getAppUiState().themeUserBubble
  }
  private get themeUserBubbleText(): string {
    return getAppUiState().themeUserBubbleText
  }
  private get themeAiBubble(): string {
    return getAppUiState().themeAiBubble
  }
  private get chatFontSize(): number {
    return getAppUiState().chatFontSize
  }

  // 获取卡片背景色
  private getCardBackground(): ResourceColor {
    return $r('app.color.surface')
  }

  // 获取主文字颜色
  private getPrimaryTextColor(): ResourceColor {
    return $r('app.color.text_primary')
  }

  // 获取次要文字颜色
  private getSecondaryTextColor(): ResourceColor {
    return $r('app.color.text_secondary')
  }

  // 获取分割线颜色
  private getDividerColor(): ResourceColor {
    return $r('app.color.divider')
  }

  // 获取 AI 内容容器背景色
  private getAiContentBgColor(): ResourceColor {
    return this.themeAiBubble
  }

  // 获取用户消息气泡背景色（使用主题色）
  private getUserBubbleBgColor(): string {
    return this.themeUserBubble
  }

  // 获取用户消息文字颜色
  private getUserBubbleTextColor(): string {
    return this.themeUserBubbleText
  }

  build() {
    // 外层底板容器：带圆角和裁剪，确保截图时圆角生效
    Column() {
      // 内层卡片内容
      Column() {
        // 卡片头部：应用名称和时间
        Row() {
          // 应用图标
          Image($r('app.media.app_icon'))
            .width(24)
            .height(24)
            .borderRadius(6)
            .syncLoad(true)

          Text(this.appName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPrimaryTextColor())
            .margin({ left: 8 })

          Blank()

          Text(this.formatDateTime(Date.now()))
            .fontSize(12)
            .fontColor(this.getSecondaryTextColor())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 12 })

        Divider()
          .color(this.getDividerColor())
          .margin({ left: 16, right: 16 })

        // 消息列表
        Column() {
          ForEach(this.messages, (message: ChatMessage) => {
            this.MessageItem(message)
          }, (message: ChatMessage) => message.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })

        // AI 生成合规标识（分享图片底部）
        Divider()
          .color(this.getDividerColor())
          .margin({ left: 16, right: 16 })

        Row() {
          Text($r('app.string.ai_generated_label'))
            .fontSize(11)
            .fontColor(this.getSecondaryTextColor())
            .opacity(0.8)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16, top: 10, bottom: 14 })
      }
      .width('100%')
      .backgroundColor(this.getCardBackground())
    }
    .width('100%')
    // 底板背景色：使用轻微的灰色作为分享图片的背景
    .backgroundColor(this.isDarkMode ? '#1A1A1A' : '#F5F5F5')
    .borderRadius(16)
    .clip(true) // 关键：启用裁剪确保圆角生效
    .shadow({
      radius: 20,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.3)' : 'rgba(0, 0, 0, 0.1)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  MessageItem(message: ChatMessage) {
    Column() {
      if (message.role === MessageRole.USER) {
        // 用户消息
        Row() {
          Blank()

          Column() {
            // 附件展示
            if (message.hasAttachments()) {
              this.ShareAttachments(message, true)
            }

            // 文本内容
            if (message.content.length > 0) {
              Text(message.content)
                .fontSize(this.chatFontSize)
                .fontColor(this.getUserBubbleTextColor())
                .lineHeight(getUserBubbleTextLineHeight(this.chatFontSize))
                .padding(message.hasAttachments() ? { left: 8, right: 8 } : { left: 0, right: 0 })
            }
          }
          .padding(getUserBubblePadding(message.hasAttachments()))
          .backgroundColor(this.getUserBubbleBgColor())
          .borderRadius(getUserBubbleRadius())
          .clip(true)
          .border({ width: USER_BUBBLE_BORDER_WIDTH, color: 'rgba(255, 255, 255, 0.15)' })
          .constraintSize({ maxWidth: USER_BUBBLE_MAX_WIDTH })
        }
        .width('100%')
        .margin({ bottom: 12 })
      } else {
        // AI 消息
        Column() {
          Row() {
            AssistantAvatarView({
              value: this.assistantAvatarValue,
              color: this.assistantAvatarColor,
              avatarSize: 30,
              radius: 8,
              fontSize: 14,
              cacheKey: this.assistantAvatarCacheKey,
              modelId: message.modelId !== '' ? message.modelId : this.currentModelId,
              modelName: message.modelName,
              preferModelIconForMessage: true
            })

            Text(message.modelName || 'AI')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPrimaryTextColor())
              .margin({ left: 10 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column() {
            Column() {
              // 附件展示（AI 生成的图片等）
              if (message.hasAttachments()) {
                this.ShareAttachments(message, false)
              }

              // 消息内容 - 使用 Markdown 渲染
              if (message.content.length > 0) {
                ChatMarkdownHybridRenderer({
                  content: message.content,
                  isInputEnded: true,
                  incrementalAnalysis: false,
                  useCangjieComponent: true,
                  chatFontSize: this.chatFontSize,
                  themeRenderKey: message.id
                })
                  .width('100%')
                  .backgroundColor(Color.Transparent)
              }
            }
            .width('100%')
            .padding(getAssistantBubblePadding())
            .backgroundColor(this.getAiContentBgColor())
            .borderRadius(ASSISTANT_BUBBLE_RADIUS)
            .border({ width: ASSISTANT_BUBBLE_BORDER_WIDTH, color: $r('app.color.bubble_border') })
            .clip(true)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 12 })
      }
    }
    .width('100%')
  }


  // 分享卡片中的附件展示（无交互手势，纯静态展示）
  @Builder
  ShareAttachments(message: ChatMessage, isUserMessage: boolean) {
    Column() {
      ForEach(message.attachments, (attachment: MessageAttachment) => {
        if (attachment.type === AttachmentType.IMAGE) {
          // 图片附件：直接显示图片
          if (attachment.filePath !== '') {
            Image('file://' + attachment.filePath)
              .constraintSize({
                maxWidth: 180,
                maxHeight: 180
              })
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
              .margin({ bottom: 4 })
              .syncLoad(true)
          } else if (attachment.base64Data !== '') {
            Image(`data:${attachment.mimeType};base64,${attachment.base64Data}`)
              .constraintSize({
                maxWidth: 180,
                maxHeight: 180
              })
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
              .margin({ bottom: 4 })
              .syncLoad(true)
          }
        } else {
          // 文件附件：图标+文件名
          Row() {
            SymbolGlyph($r('sys.symbol.doc'))
              .fontSize(18)
              .fontColor([isUserMessage ? 'rgba(255,255,255,0.8)' : $r('app.color.text_tertiary')])

            Text(attachment.name)
              .fontSize(12)
              .fontColor(isUserMessage ? 'rgba(255,255,255,0.9)' : $r('app.color.text_secondary'))
              .margin({ left: 6 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .padding(8)
          .backgroundColor(isUserMessage ? 'rgba(255,255,255,0.15)' : $r('app.color.divider'))
          .borderRadius(8)
          .margin({ bottom: 4 })
        }
      }, (attachment: MessageAttachment) => attachment.id || attachment.filePath)
    }
    .alignItems(isUserMessage ? HorizontalAlign.End : HorizontalAlign.Start)
  }

  // 格式化日期时间
  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${year}/${month}/${day} ${hours}:${minutes}`
  }
}

// 用于截图的 Builder
@Builder
export function ShareMessageCardBuilder(messages: ChatMessage[], appName: string) {
  ShareMessageCard({
    messages: messages,
    appName: appName
  })
}
