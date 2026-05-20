import { notificationManager } from '@kit.NotificationKit'
import { wantAgent, WantAgent } from '@kit.AbilityKit'
import { AppStorageKeys } from '../config/AppStorageKeys'
import { setAppUiStateValue } from '../state/AppUiState'
import { ChatTaskInfo, ChatTaskStatus, OpenSessionPayload } from '../models/ChatTaskModels'

const DEFAULT_BUNDLE_NAME = 'com.longlive.chatcube'
const DEFAULT_ABILITY_NAME = 'EntryAbility'

interface NotificationBusinessError {
  code?: number
  message?: string
}

export interface ImageGenerationNotificationOptions {
  taskId: string
  failed: boolean
  imageCount: number
  isEdit: boolean
}

export class ChatNotificationService {
  private static instance: ChatNotificationService | null = null
  private slotReady: boolean = false
  private slotPreparing: Promise<void> | null = null

  static getInstance(): ChatNotificationService {
    if (ChatNotificationService.instance === null) {
      ChatNotificationService.instance = new ChatNotificationService()
    }
    return ChatNotificationService.instance
  }

  async publishTaskResult(task: ChatTaskInfo): Promise<void> {
    try {
      await this.ensureNotificationSlot()
      const wantAgentObj = await this.createOpenSessionWantAgent(task)

      const request: notificationManager.NotificationRequest = {

        id: this.buildNotificationId(task.id),
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: task.status === ChatTaskStatus.FAILED ? '回复失败' : '回复完成',
            text: this.buildMessage(task),
            additionalText: 'ChatCube'
          }

        },
        wantAgent: wantAgentObj
      }
      await notificationManager.publish(request)
    } catch (error) {
      console.error('ChatNotificationService', `Failed to publish notification: ${JSON.stringify(error)}`)
    }
  }

  async publishImageGenerationResult(options: ImageGenerationNotificationOptions): Promise<void> {
    try {
      await this.ensureNotificationSlot()
      const notificationId = this.buildNotificationId(`image_${options.taskId}`)
      const wantAgentObj = await this.createOpenImageGenerationWantAgent(notificationId)
      const request: notificationManager.NotificationRequest = {
        id: notificationId,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: this.buildImageGenerationTitle(options),
            text: this.buildImageGenerationMessage(options),
            additionalText: 'ChatCube'
          }
        },
        wantAgent: wantAgentObj
      }
      await notificationManager.publish(request)
    } catch (error) {
      console.error('ChatNotificationService',
        `Failed to publish image generation notification: ${JSON.stringify(error)}`)
    }
  }

  private async ensureNotificationSlot(): Promise<void> {
    if (this.slotReady) {
      return
    }
    if (this.slotPreparing !== null) {
      await this.slotPreparing
      return
    }
    this.slotPreparing = this.ensureNotificationSlotInternal()
    try {
      await this.slotPreparing
    } finally {
      this.slotPreparing = null
    }
  }

  private async ensureNotificationSlotInternal(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION)
      this.slotReady = true
      console.info('ChatNotificationService', 'Service slot ensured')
    } catch (error) {
      if (this.isSlotAlreadyExistsError(error)) {
        this.slotReady = true
        return
      }
      this.slotReady = false
      console.warn('ChatNotificationService', `Failed to add service slot: ${JSON.stringify(error)}`)
    }
  }

  private isSlotAlreadyExistsError(error: Object): boolean {
    const err = error as NotificationBusinessError
    if (err.code !== undefined && err.code === 1600009) {
      return true
    }
    if (err.message !== undefined) {
      const lowerMessage = err.message.toLowerCase()
      if (lowerMessage.includes('already') && lowerMessage.includes('exist')) {
        return true
      }
    }
    return false
  }

  private async createOpenSessionWantAgent(task: ChatTaskInfo): Promise<WantAgent> {
    const payload = new OpenSessionPayload(task.sessionId, task.id, 'notification')
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: DEFAULT_BUNDLE_NAME,
          abilityName: DEFAULT_ABILITY_NAME,
          parameters: {
            action: 'openSession',
            payload: JSON.stringify(payload)
          }
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: this.buildNotificationId(task.id),
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }
    return await wantAgent.getWantAgent(info)
  }

  private async createOpenImageGenerationWantAgent(requestCode: number): Promise<WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: DEFAULT_BUNDLE_NAME,
          abilityName: DEFAULT_ABILITY_NAME,
          parameters: {
            action: 'openImageGeneration'
          }
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: requestCode,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }
    return await wantAgent.getWantAgent(info)
  }

  private buildNotificationId(taskId: string): number {
    let hash = 0
    for (let i = 0; i < taskId.length; i++) {
      hash = (hash * 31 + taskId.charCodeAt(i)) % 2000000000
    }
    return hash + 1000
  }

  private buildMessage(task: ChatTaskInfo): string {
    if (task.status === ChatTaskStatus.FAILED) {
      return `会话「${task.sessionTitle}」回复失败，点击查看详情`
    }
    return `会话「${task.sessionTitle}」回复已完成，点击查看`
  }

  private buildImageGenerationTitle(options: ImageGenerationNotificationOptions): string {
    if (options.isEdit) {
      return options.failed ? '图片编辑失败' : '图片编辑完成'
    }
    return options.failed ? '图片生成失败' : '图片生成完成'
  }

  private buildImageGenerationMessage(options: ImageGenerationNotificationOptions): string {
    if (options.failed) {
      return options.isEdit ? '图片编辑失败，点击查看详情' : '图片生成失败，点击查看详情'
    }
    if (options.isEdit) {
      if (options.imageCount <= 1) {
        return '已编辑 1 张图片，点击查看'
      }
      return `已编辑 ${options.imageCount} 张图片，点击查看`
    }
    if (options.imageCount <= 1) {
      return '已生成 1 张图片，点击查看'
    }
    return `已生成 ${options.imageCount} 张图片，点击查看`
  }

  handleOpenSessionPayload(payloadText: string): void {
    if (payloadText === '') {
      return
    }
    setAppUiStateValue(AppStorageKeys.OPEN_SESSION_PAYLOAD, payloadText)
  }
}

export function getChatNotificationService(): ChatNotificationService {
  return ChatNotificationService.getInstance()
}
