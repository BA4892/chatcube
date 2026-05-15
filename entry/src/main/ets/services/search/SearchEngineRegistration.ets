import { SearchEngine } from '../../models/ChatModels'
import { PreferenceKeys } from '../PreferencesService'
import { getSearchEngineRegistry } from './SearchEngineRegistry'

// 注册所有搜索引擎（顺序即 UI Select 的顺序）
export function registerAllSearchEngines(): void {
  const registry = getSearchEngineRegistry()

  // 避免重复注册
  if (registry.getAll().length > 0) {
    return
  }

  registry.register({
    id: SearchEngine.BING,
    label: 'Bing(local)',
    configFields: [],
    supportsScrape: false
  })

  registry.register({
    id: SearchEngine.BRAVE,
    label: 'Brave Search',
    configFields: [
      {
        key: PreferenceKeys.SEARCH_BRAVE_API_KEY,
        placeholder: 'Brave Search API Key',
        isPassword: true,
        defaultValue: ''
      }
    ],
    supportsScrape: false
  })

  registry.register({
    id: SearchEngine.TAVILY,
    label: 'Tavily',
    configFields: [
      {
        key: PreferenceKeys.SEARCH_TAVILY_API_KEY,
        placeholder: 'Tavily API Key',
        isPassword: true,
        defaultValue: ''
      },
      {
        key: PreferenceKeys.SEARCH_TAVILY_BASE_URL,
        placeholder: 'Base URL（可选，默认 api.tavily.com）',
        isPassword: false,
        defaultValue: 'https://api.tavily.com'
      }
    ],
    supportsScrape: true
  })

  registry.register({
    id: SearchEngine.EXA,
    label: 'Exa',
    configFields: [
      {
        key: PreferenceKeys.SEARCH_EXA_API_KEY,
        placeholder: 'Exa API Key',
        isPassword: true,
        defaultValue: ''
      },
      {
        key: PreferenceKeys.SEARCH_EXA_BASE_URL,
        placeholder: 'Base URL（可选，默认 api.exa.ai）',
        isPassword: false,
        defaultValue: 'https://api.exa.ai'
      }
    ],
    supportsScrape: true
  })

  registry.register({
    id: SearchEngine.METASO,
    label: 'Metaso',
    configFields: [
      {
        key: PreferenceKeys.SEARCH_METASO_API_KEY,
        placeholder: 'Metaso API Key',
        isPassword: true,
        defaultValue: ''
      }
    ],
    supportsScrape: true
  })

  registry.register({
    id: SearchEngine.FIRECRAWL,
    label: 'Firecrawl',
    configFields: [
      {
        key: PreferenceKeys.SEARCH_FIRECRAWL_API_KEY,
        placeholder: 'Firecrawl API Key',
        isPassword: true,
        defaultValue: ''
      },
      {
        key: PreferenceKeys.SEARCH_FIRECRAWL_BASE_URL,
        placeholder: 'Base URL（可选，默认 api.firecrawl.dev）',
        isPassword: false,
        defaultValue: 'https://api.firecrawl.dev'
      }
    ],
    supportsScrape: true
  })
}
