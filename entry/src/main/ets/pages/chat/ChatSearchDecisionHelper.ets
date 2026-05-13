import { getSearchEngineRegistry, registerAllSearchEngines } from '../../services/search/Index'

export function isSelfOptimizedSearchEngineForChat(engineName: string): boolean {
  registerAllSearchEngines()
  const normalizedName = engineName.trim().toLowerCase()
  const allEngines = getSearchEngineRegistry().getAll()
  for (const engine of allEngines) {
    if (engine.label.toLowerCase() === normalizedName && engine.isSelfOptimized) {
      return true
    }
  }
  return false
}

export function shouldApplyLlmQueryOptimizationForChat(engineName: string, globalEnabled: boolean): boolean {
  if (!globalEnabled) {
    return false
  }
  registerAllSearchEngines()
  const normalizedName = engineName.trim().toLowerCase()
  const allEngines = getSearchEngineRegistry().getAll()
  for (const engine of allEngines) {
    if (engine.label.toLowerCase() === normalizedName) {
      return engine.supportsQueryOptimization
    }
  }
  return false
}
