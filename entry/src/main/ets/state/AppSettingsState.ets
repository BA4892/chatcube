import { AppStorageV2, UIUtils } from '@kit.ArkUI'
import { ModelProvider } from '../models/ChatModels'

/**
 * 应用配置状态（跟 AppUiState 并列）
 *
 * 相较于 AppUiState：
 * - AppUiState 装 UI 临时态 / 主题 / 账号 / 系统状态等 primitive（string/number/boolean），通过 AppStorage 自动持久化
 * - AppSettingsState 装“应用配置”类对象（providers / assistants / favorites 等），由对应 Store 负责 SQLite 持久化
 *
 * 本轮只先落 providers 字段，后续会陆续把 assistants / defaultModels / favoriteModels 等迁过来
 */
const APP_SETTINGS_STATE_KEY = 'chatbox_app_settings_state'

@ObservedV2
export class AppSettingsState {
  @Trace providers: ModelProvider[] = []
  // 初始化完成标记：Store 首次拉完 DB + 合并预设后置 true，UI 层可据此区分 “空数组 = 未加载 / 已加载无数据”
  @Trace providersInitialized: boolean = false
  // 每次 providers 写操作自增；用作 UIUtils.addMonitor 的订阅锚点，保证非结构变更也能触发
  @Trace providersVersion: number = 0
}

function createAppSettingsState(): AppSettingsState {
  return new AppSettingsState()
}

/**
 * 取得 AppSettingsState 全局单例。内部通过 AppStorageV2.connect 绑定到固定 key，与 AppUiState 同源一致
 */
export function getAppSettingsState(): AppSettingsState {
  return AppStorageV2.connect(AppSettingsState, APP_SETTINGS_STATE_KEY, createAppSettingsState)
    ?? createAppSettingsState()
}

/**
 * path 解析器：入参支持字段名（providers / providersVersion / providersInitialized）
 * 未命中则原样返回，让 UIUtils.addMonitor 自己决定要不要监听
 */
function resolveAppSettingsStatePath(path: string): string {
  switch (path) {
    case 'providers':
      return 'providers'
    case 'providersInitialized':
      return 'providersInitialized'
    case 'providersVersion':
      return 'providersVersion'
    default:
      return path
  }
}

/**
 * 订阅 AppSettingsState 指定字段变化。与 observeAppUiState 保持同风格，返回“解绑函数”
 *
 * 典型用法：订阅 providersVersion 即可在任意 provider 写操作后收到通知
 */
export function observeAppSettingsState(paths: string | string[], callback: () => void): () => void {
  const monitorPaths = Array.isArray(paths)
    ? paths.map((path: string): string => resolveAppSettingsStatePath(path))
    : resolveAppSettingsStatePath(paths)
  const monitorCallback = (_monitorValue: Object): void => {
    callback()
  }
  UIUtils.addMonitor(getAppSettingsState(), monitorPaths, monitorCallback)
  return (): void => {
    UIUtils.clearMonitor(getAppSettingsState(), monitorPaths, monitorCallback)
  }
}
