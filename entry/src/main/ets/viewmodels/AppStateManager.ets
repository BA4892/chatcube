import { getPreferencesService, PreferencesService } from '../services/PreferencesService'
import { getDatabaseService, DatabaseService } from '../services/DatabaseService'

// 全局应用状态管理器 - 单例模式
export class AppStateManager {
  private static instance: AppStateManager | null = null
  private preferencesService: PreferencesService
  private databaseService: DatabaseService

  // 当前选中的模型和服务商
  private currentModelId: string = ''
  private currentProviderId: string = ''
  private currentModelName: string = ''

  private constructor() {
    this.preferencesService = getPreferencesService()
    this.databaseService = getDatabaseService()
  }

  static getInstance(): AppStateManager {
    if (AppStateManager.instance === null) {
      AppStateManager.instance = new AppStateManager()
    }
    return AppStateManager.instance
  }

  // 加载保存的状态
  async loadState(): Promise<void> {
    this.currentModelId = await this.preferencesService.getCurrentModelId()
    this.currentModelName = await this.preferencesService.getCurrentModelName()
    this.currentProviderId = await this.preferencesService.getCurrentProviderId()
  }

  // 获取当前模型ID
  getCurrentModelId(): string {
    return this.currentModelId
  }

  // 设置当前模型
  async setCurrentModel(modelId: string, modelName: string, providerId: string): Promise<void> {
    this.currentModelId = modelId
    this.currentModelName = modelName
    this.currentProviderId = providerId
    await this.preferencesService.setCurrentModelId(modelId)
    await this.preferencesService.setCurrentModelName(modelName)
    await this.preferencesService.setCurrentProviderId(providerId)
  }

  // 获取当前模型名称
  getCurrentModelName(): string {
    return this.currentModelName
  }

  // 获取当前服务商ID
  getCurrentProviderId(): string {
    return this.currentProviderId
  }
}

// 导出单例实例获取方法
export function getAppStateManager(): AppStateManager {
  return AppStateManager.getInstance()
}
