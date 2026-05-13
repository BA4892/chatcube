import { SearchEngine } from '../../models/ChatModels'
import { SearchRuntimeConfigSnapshot } from '../WebSearchService'
import { HttpRequestController } from '../HttpService'

// 搜索引擎配置字段描述
export interface SearchEngineConfigField {
  key: string          // PreferenceKeys 中的 key
  placeholder: string  // UI 输入框 placeholder
  isPassword: boolean  // 是否密码输入
  defaultValue: string // 默认值
}

// 搜索引擎描述
export interface SearchEngineDescriptor {
  id: SearchEngine
  label: string
  configFields: SearchEngineConfigField[]  // 需要用户配置的字段（apiKey、baseUrl 等）
  supportsScrape: boolean                  // 是否支持网页抓取
  supportsQueryOptimization: boolean       // 是否支持 LLM 查询优化（本地 HTML 解析类引擎）
  isSelfOptimized: boolean                 // 引擎自身已优化查询（如 Exa）
}

// 搜索引擎注册表
class SearchEngineRegistryImpl {
  private engines: SearchEngineDescriptor[] = []

  register(descriptor: SearchEngineDescriptor): void {
    this.engines.push(descriptor)
  }

  getAll(): SearchEngineDescriptor[] {
    return this.engines
  }

  getById(id: SearchEngine): SearchEngineDescriptor | undefined {
    for (const engine of this.engines) {
      if (engine.id === id) {
        return engine
      }
    }
    return undefined
  }

  getByIndex(index: number): SearchEngineDescriptor | undefined {
    if (index >= 0 && index < this.engines.length) {
      return this.engines[index]
    }
    return undefined
  }

  indexOf(id: SearchEngine): number {
    for (let i = 0; i < this.engines.length; i++) {
      if (this.engines[i].id === id) {
        return i
      }
    }
    return 0
  }

  getLabel(id: SearchEngine): string {
    const desc = this.getById(id)
    return desc !== undefined ? desc.label : 'Bing(local)'
  }

  getSelectOptions(): Array<SelectOption> {
    return this.engines.map((d: SearchEngineDescriptor): SelectOption => ({ value: d.label }))
  }

  parseEngine(raw: string): SearchEngine {
    for (const engine of this.engines) {
      if (engine.id === raw) {
        return engine.id
      }
    }
    return SearchEngine.BING
  }

  // 获取需要 API Key 的引擎 ID 列表（用于敏感键过滤）
  getSensitiveKeys(): string[] {
    const keys: string[] = []
    for (const engine of this.engines) {
      for (const field of engine.configFields) {
        if (field.isPassword) {
          keys.push(field.key)
        }
      }
    }
    return keys
  }

  // 获取指定引擎的 API Key 字段的 preference key
  getApiKeyPrefKey(id: SearchEngine): string {
    const desc = this.getById(id)
    if (desc === undefined) {
      return ''
    }
    for (const field of desc.configFields) {
      if (field.isPassword) {
        return field.key
      }
    }
    return ''
  }

  // 获取指定引擎的 Base URL 字段的 preference key
  getBaseUrlPrefKey(id: SearchEngine): string {
    const desc = this.getById(id)
    if (desc === undefined) {
      return ''
    }
    for (const field of desc.configFields) {
      if (!field.isPassword && field.defaultValue !== '') {
        return field.key
      }
    }
    return ''
  }
}

// 全局单例
const registry = new SearchEngineRegistryImpl()

export function getSearchEngineRegistry(): SearchEngineRegistryImpl {
  return registry
}

export type { SearchEngineRegistryImpl }
