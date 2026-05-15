import { SearchEngine } from '../models/ChatModels'
import { getSearchEngineRegistry, registerAllSearchEngines } from '../services/search/Index'

export function isKnownSearchEngineId(engineId: string): boolean {
  registerAllSearchEngines()
  const descriptors = getSearchEngineRegistry().getAll()
  for (let i = 0; i < descriptors.length; i++) {
    if (descriptors[i].id === engineId) {
      return true
    }
  }
  return false
}

export function normalizeSearchEngineIdList(ids: string[]): string[] {
  const next: string[] = []
  for (let i = 0; i < ids.length; i++) {
    const engineId = ids[i].trim()
    if (engineId === '' || !isKnownSearchEngineId(engineId) || next.includes(engineId)) {
      continue
    }
    next.push(engineId)
  }
  return next
}

export function parseSearchEngineIdListJson(raw: string): string[] {
  const trimmed = raw.trim()
  if (trimmed === '') {
    return []
  }
  try {
    const parsed = JSON.parse(trimmed) as string[]
    if (!Array.isArray(parsed)) {
      return []
    }
    return normalizeSearchEngineIdList(parsed)
  } catch (_error) {
    return []
  }
}

export function stringifySearchEngineIdList(ids: string[]): string {
  return JSON.stringify(normalizeSearchEngineIdList(ids))
}

export function asSearchEngine(engineId: string): SearchEngine {
  registerAllSearchEngines()
  return getSearchEngineRegistry().parseEngine(engineId)
}
